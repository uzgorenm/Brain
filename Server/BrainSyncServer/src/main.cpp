#include <arpa/inet.h>
#include <netinet/in.h>
#include <sys/socket.h>
#include <unistd.h>

#include <array>
#include <csignal>
#include <cstring>
#include <iostream>
#include <stdexcept>
#include <string>

namespace {
volatile std::sig_atomic_t should_stop = 0;

void handle_signal(int) {
    should_stop = 1;
}

std::string response_for(const std::string& request) {
    const bool is_health = request.starts_with("GET /health ");
    const bool is_push = request.starts_with("POST /sync/push ");
    const bool is_pull = request.starts_with("GET /sync/pull ");

    std::string status = "200 OK";
    std::string body;

    if (is_health) {
        body = R"({"status":"ok","service":"brain-sync-server"})";
    } else if (is_push) {
        body = R"({"accepted":true,"message":"push endpoint placeholder"})";
    } else if (is_pull) {
        body = R"({"changes":[],"cursor":"mvp-placeholder"})";
    } else {
        status = "404 Not Found";
        body = R"({"error":"not_found"})";
    }

    return "HTTP/1.1 " + status + "\r\n"
        "Content-Type: application/json\r\n"
        "Content-Length: " + std::to_string(body.size()) + "\r\n"
        "Connection: close\r\n"
        "\r\n" + body;
}

int make_server_socket(int port) {
    const int server_fd = ::socket(AF_INET, SOCK_STREAM, 0);
    if (server_fd < 0) {
        throw std::runtime_error("socket failed");
    }

    int reuse = 1;
    if (::setsockopt(server_fd, SOL_SOCKET, SO_REUSEADDR, &reuse, sizeof(reuse)) < 0) {
        ::close(server_fd);
        throw std::runtime_error("setsockopt failed");
    }

    sockaddr_in address {};
    address.sin_family = AF_INET;
    address.sin_addr.s_addr = htonl(INADDR_ANY);
    address.sin_port = htons(static_cast<uint16_t>(port));

    if (::bind(server_fd, reinterpret_cast<sockaddr*>(&address), sizeof(address)) < 0) {
        ::close(server_fd);
        throw std::runtime_error("bind failed");
    }

    if (::listen(server_fd, 16) < 0) {
        ::close(server_fd);
        throw std::runtime_error("listen failed");
    }

    return server_fd;
}
}

int main(int argc, char* argv[]) {
    const int port = argc > 1 ? std::stoi(argv[1]) : 8080;
    std::signal(SIGINT, handle_signal);
    std::signal(SIGTERM, handle_signal);

    try {
        const int server_fd = make_server_socket(port);
        std::cout << "Brain sync server listening on http://localhost:" << port << '\n';

        while (!should_stop) {
            sockaddr_in client_address {};
            socklen_t client_length = sizeof(client_address);
            const int client_fd = ::accept(server_fd, reinterpret_cast<sockaddr*>(&client_address), &client_length);
            if (client_fd < 0) {
                if (should_stop) {
                    break;
                }
                std::cerr << "accept failed: " << std::strerror(errno) << '\n';
                continue;
            }

            std::array<char, 4096> buffer {};
            const ssize_t bytes_read = ::read(client_fd, buffer.data(), buffer.size() - 1);
            if (bytes_read > 0) {
                const std::string request(buffer.data(), static_cast<size_t>(bytes_read));
                const std::string response = response_for(request);
                ::send(client_fd, response.data(), response.size(), 0);
            }
            ::close(client_fd);
        }

        ::close(server_fd);
    } catch (const std::exception& error) {
        std::cerr << "server error: " << error.what() << '\n';
        return 1;
    }

    return 0;
}
