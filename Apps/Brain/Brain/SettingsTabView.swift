import SwiftUI
import BrainCore

struct SettingsTabView: View {
    @Environment(BrainAppStore.self) private var appStore
    @State private var downloadManager = ModelDownloadManager.shared
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        
                        BrainSurface {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Capture & privacy").font(.headline)
                                Text("Recordings are transcribed on device. Brain removes the audio after you save the note. Unfinished recordings stay available for retry.")
                                    .font(.subheadline).foregroundStyle(BrainTheme.mutedText)
                                Text("Action button and shortcuts").font(.headline)
                                Text("Use Write a note to open the editor with the keyboard ready, or Record a thought to start a voice note after microphone permission. Add either Brain shortcut to your Home Screen or Action button.")
                                    .font(.subheadline).foregroundStyle(BrainTheme.mutedText)
                            }
                        }

                        VStack(alignment: .leading, spacing: 12) {
                            Text("Optional AI")
                                .font(.headline)
                                .foregroundStyle(BrainTheme.accent)
                            
                            Text("Rewrite notes, generate flashcards, and ask questions with a model that runs on this device. Recording, transcription, and review work without it.")
                                .font(.subheadline)
                                .foregroundStyle(BrainTheme.mutedText)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Model:")
                                        .fontWeight(.semibold)
                                    Text("LFM2.5-2.6B MLX 4-bit")
                                }
                                HStack {
                                    Text("Size:")
                                        .fontWeight(.semibold)
                                    Text("~1.47 GB")
                                }
                                HStack {
                                    Text("Status:")
                                        .fontWeight(.semibold)
                                    Text(appStore.isLocalAIReady ? "Ready" : (downloadManager.isDownloaded ? "Loading…" : "Not downloaded"))
                                        .foregroundStyle(appStore.isLocalAIReady ? .green : .orange)
                                }
                            }
                            .font(.subheadline)
                            .padding(.top, 4)
                            
                            if downloadManager.isDownloading {
                                VStack(spacing: 8) {
                                    ProgressView(value: downloadManager.progress)
                                        .tint(BrainTheme.accent)
                                    
                                    HStack {
                                        Text("\(Int(downloadManager.progress * 100))%")
                                            .font(.caption.monospacedDigit())
                                            .foregroundStyle(BrainTheme.mutedText)
                                        Spacer()
                                        Button("Cancel") {
                                            downloadManager.cancelDownload()
                                        }
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.red)
                                    }
                                }
                                .padding(.top, 10)
                            } else if !downloadManager.isDownloaded && !appStore.isLocalAIReady {
                                Button(action: {
                                    downloadManager.startDownload()
                                }) {
                                    HStack {
                                        Image(systemName: "icloud.and.arrow.down")
                                        Text("Download Local Model")
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(BrainTheme.accent)
                                    .foregroundColor(.white)
                                    .clipShape(RoundedRectangle(cornerRadius: BrainTheme.cornerRadius))
                                }
                                .padding(.top, 10)
                            } else {
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                    Text(appStore.isLocalAIReady ? "AI is ready" : "Loading AI model…")
                                        .fontWeight(.medium)
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.green.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: BrainTheme.cornerRadius))
                                .padding(.top, 10)
                            }
                            
                            if let errorMessage = downloadManager.errorMessage {
                                Text(errorMessage)
                                    .font(.caption)
                                    .foregroundStyle(.red)
                                    .padding(.top, 4)
                            }
                        }
                        .padding(20)
                        .background(BrainTheme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: BrainTheme.cornerRadius))
                        .overlay(
                            RoundedRectangle(cornerRadius: BrainTheme.cornerRadius)
                                .stroke(BrainTheme.border)
                        )
                        
                        DisclosureGroup("Install a model manually") {
                            
                            Text("The MLX checkpoint contains several files, so Brain downloads and caches it directly instead of importing one model file.")
                                .font(.subheadline)
                                .foregroundStyle(BrainTheme.mutedText)
                            
                            Text("For Mac development, run `python3 scripts/download_model.py` to prefetch LiquidAI/LFM2.5-2.6B-MLX-4bit. The app still downloads its own on-device cache when needed.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.top, 4)
                        }
                        .padding(20)
                        .background(BrainTheme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: BrainTheme.cornerRadius))
                        .overlay(
                            RoundedRectangle(cornerRadius: BrainTheme.cornerRadius)
                                .stroke(BrainTheme.border)
                        )
                        
                    }
                    .padding(20)
                    .frame(maxWidth: BrainTheme.readableWidth).frame(maxWidth: .infinity)
                }
            }
            .brainScreen()
            .platformNavigationBarStyle()
            .navigationTitle("Settings")
            .onAppear {
                _ = downloadManager.checkModelExists()
            }
        }
    }
}
