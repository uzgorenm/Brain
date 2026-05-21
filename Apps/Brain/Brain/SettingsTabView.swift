import SwiftUI
import BrainCore

struct SettingsTabView: View {
    @State private var downloadManager = ModelDownloadManager.shared
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack {
                    Text("Settings")
                        .font(.largeTitle.bold())
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(BrainTheme.surface)
                
                Divider()
                    .overlay(Color.white.opacity(0.08))
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        
                        VStack(alignment: .leading, spacing: 12) {
                            Text("AI Features & Model Download")
                                .font(.headline)
                                .foregroundStyle(BrainTheme.accent)
                            
                            Text("To enable AI Flashcard Generation and AI Question features, Brain requires a local Language Model to be downloaded to your device.")
                                .font(.subheadline)
                                .foregroundStyle(BrainTheme.mutedText)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Model:")
                                        .fontWeight(.semibold)
                                    Text("Gemma 2B (LiteRT-LM)")
                                }
                                HStack {
                                    Text("Size:")
                                        .fontWeight(.semibold)
                                    Text("~2.5 GB")
                                }
                                HStack {
                                    Text("Status:")
                                        .fontWeight(.semibold)
                                    Text(BrainCore.LLMManager.shared.isInitialized ? "Initialized & Ready" : (downloadManager.isDownloaded ? "Downloaded (Restart App)" : "Not Downloaded"))
                                        .foregroundStyle(BrainCore.LLMManager.shared.isInitialized ? .green : .orange)
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
                            } else if !downloadManager.isDownloaded && !BrainCore.LLMManager.shared.isInitialized {
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
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                                .padding(.top, 10)
                            } else {
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                    Text("Local Model Ready")
                                        .fontWeight(.medium)
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.green.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
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
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(0.10))
                        )
                        
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Manual Installation (Simulator & Device)")
                                .font(.headline)
                                .foregroundStyle(BrainTheme.accent)
                            
                            Text("If you prefer to download the model manually, you can use the `scripts/download_model.py` provided in the codebase.")
                                .font(.subheadline)
                                .foregroundStyle(BrainTheme.mutedText)
                            
                            Text("1. Run `python3 scripts/download_model.py`.\n2. Locate the `gemma-4-E2B-it.litertlm` file.\n3. **iOS Simulator**: Drag the file into the simulator window, which opens the Files app. Select \"On My iPhone\" -> \"Brain\" folder and click Save.\n4. **Physical iPhone**: Use Finder or AirDrop to drop the file into the Brain app's Documents folder.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.top, 4)
                        }
                        .padding(20)
                        .background(BrainTheme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(0.10))
                        )
                        
                    }
                    .padding(20)
                }
            }
            .brainDarkScreen()
            .platformNavigationBarStyle()
            .platformHiddenNavigationBar()
            .onAppear {
                _ = downloadManager.checkModelExists()
            }
        }
    }
}
