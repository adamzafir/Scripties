import SwiftUI
import FoundationModels

struct Screen2: View {
    @Binding var title: String
    @Binding var script: String
    
    @State private var showScreen = false
    @State private var showScreent = false
    @FocusState private var isEditingScript: Bool
    
    @State private var rewriting = false
    @State private var rewritePrompt = """
    Rewrite this script. Reply with ONLY the rewritten version of this script...
    """
    @State var wordCount: Int = 0
    @State private var showPromptDialog = false
    @State private var rewriteError: String? = nil

    // Added to satisfy Screen3Teleprompter requirements
    @State private var WPM: Int = 120
    @State private var timer = TimerManager()
    @State private var isLoading = false
    
    var body: some View {
        NavigationStack {
            VStack {
                if isLoading {
                    Spacer()
                    ZStack {
                        VStack(spacing: 4) {
                            ProgressView("Loading...")
                                .progressViewStyle(CircularProgressViewStyle())
                                .padding()
                            Text("Powered By")
                                .fontWeight(.medium)
                                .font(.title3)
                            Text("Avyan Intelligence")
                                .font(.system(size: 35, weight: .semibold))
                                .appleIntelligenceGradient()
                        }
                        VStack {
                            Spacer()
                            GlowEffect()
                                .offset(y: 25)
                        }
                    }
                    Spacer()
                } else {
                    TextField("Untitled Script", text: $title)
                        .font(.title)
                        .fontWeight(.bold)
                        .padding()
                    
                    TextEditor(text: $script)
                        .focused($isEditingScript)
                        .padding(.horizontal)
                        .frame(maxHeight: .infinity)
                    
                    Spacer()
                }
            }
            .onAppear {
                wordCount =  script.split { $0.isWhitespace }.count
            }
            .alert("Rewrite Failed", isPresented: Binding(
                get: { rewriteError != nil },
                set: { if !$0 { rewriteError = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(rewriteError ?? "Unknown error")
            }
            .confirmationDialog("Rewrite with AI", isPresented: $showPromptDialog, titleVisibility: .visible) {
                TextField("Prompt for rewriting", text: $rewritePrompt)
                
                Button("Rewrite Now") {
                    rewriting = true
                    isLoading = true
                    Task {
                        do {
                            let session = LanguageModelSession()
                            let result = try await session.respond(to: """
                            Rewrite this text using these instructions: \(rewritePrompt)
                            
                            Original:
                            \(script)
                            """)
                            script = result.content
                        } catch {
                            rewriteError = error.localizedDescription
                        }
                        rewriting = false
                        isLoading = false
                    }
                }.disabled(rewriting)
                
                Button("Cancel", role: .cancel) {}
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            showScreent = true
                        } label: {
                            Text("Teleprompter")
                        }
                        Button {
                            showScreen = true
                        } label: {
                            Text("Keywords")
                        }
                    } label: {
                        Image(systemName: "music.microphone")
                    }
                }
                
                ToolbarItemGroup(placement: .keyboard) {
                    Button {
                        showPromptDialog = true
                    } label: {
                        Image(systemName: "wand.and.stars")
                    }
                    
                    Spacer()
                    
                    Button {
                        isEditingScript = false
                    } label: {
                        Image(systemName: "checkmark")
                    }
                }
            }
        }
        .overlay(alignment: .bottom) {
            HStack {
                Text("Word Count: \(wordCount)")
                    .font(.headline)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .glassEffect()
            }
            .shadow(color: Color.black.opacity(0.1), radius: 12, x: 0, y: 4)
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .fullScreenCover(isPresented: $showScreent) {
            Screen3Teleprompter(title: $title, script: $script, WPM: $WPM, timer: timer)
        }
        .fullScreenCover(isPresented: $showScreen) {
            Screen3Keywords(title: $title, script: $script)
        }
    }
}

#Preview {
    Screen2(
        title: .constant("untitled"),
        script: .constant("This is a test script.")
    )
}
