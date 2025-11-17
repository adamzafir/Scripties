//
//  ExpandedScriptViewDuplicate.swift
//  yapLONGER
//
//  Created by T Krobot on 17/11/25.
//

import SwiftUI
import FoundationModels

struct Screen22: View {
    @Binding var title: String
    @Binding var script: String

    @State private var initialTitle: String = ""
    @State private var initialScript: String = ""
    @State private var hasInitializedPlaceholders: Bool = false
    
    @State private var myText: String = ""
    @State private var showScreent = false
    @FocusState private var isEditingScript: Bool
    @FocusState private var isEditingTitle: Bool
    
    @State private var rewriting = false
    @State private var rewritePrompt = """
    Rewrite this script. Reply with ONLY the rewritten version of this script...
    """
    @State var wordCount: Int = 0
    @State private var showPromptDialog = false
    @State private var rewriteError: String? = nil

    @State private var WPM: Int = 120
    @State private var timer = TimerManager()
    @State private var isLoading = false
    @State private var showEstimate = true
    
    @State private var isTyping = false
    @State private var typingResetTask: Task<Void, Never>? = nil
    
    private func wrdEstimateString(for wordCount: Int, wpm: Int = 120) -> String {
        guard wordCount > 0, wpm > 0 else { return "0 min 0 sec" }
        let totalSeconds = Double(wordCount) / Double(wpm) * 60.0
        let minutes = Int(totalSeconds) / 60
        let seconds = Int(totalSeconds) % 60
        if minutes == 0 {
            return "\(seconds) sec"
        } else if seconds == 0 {
            return "\(minutes) min"
        } else {
            return "\(minutes) min \(seconds) sec"
        }
    }
    
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
                    
                    TextField("", text: $title, prompt: Text(initialTitle.isEmpty ? "Untitled Script" : initialTitle).foregroundStyle(.secondary))
                        .focused($isEditingTitle)
                        .font(.title)
                        .fontWeight(.bold)
                        .padding()
                    
                    ZStack(alignment: .topLeading) {
                        TextEditor(text: $script)
                            .focused($isEditingScript)
                            .padding(.horizontal)
                    ZStack(alignment: .topLeading) {
                        TextEditor(text: $script)
                            .focused($isEditingScript)
                            .padding(.horizontal)
                            .frame(maxHeight: .infinity)
                            .background(Color.clear)
                            .onChange(of: script) { _, newValue in
                                wordCount = newValue.split { $0.isWhitespace }.count
                                // Mark as typing and debounce reset
                                isTyping = true
                                typingResetTask?.cancel()
                                typingResetTask = Task {
                                    try? await Task.sleep(nanoseconds: 700_000_000)
                                    await MainActor.run { isTyping = false }
                                }
                            }
                        
                        if script.isEmpty && !isEditingScript {
                            Text(initialScript.isEmpty ? "Start typing your script..." : initialScript)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 20)
                                .padding(.top, 8)
                                .allowsHitTesting(false)
                        }
                    }
                if !hasInitializedPlaceholders {
                    initialTitle = title
                    initialScript = script
                    title = ""
                    script = ""
                if !hasInitializedPlaceholders {
                    initialTitle = title
                    initialScript = script
                    title = ""
                    script = ""
                    hasInitializedPlaceholders = true
                set: { if !$0 { rewriteError = nil } }
                wordCount = script.split { $0.isWhitespace }.count
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
                    Button {
                        showScreent = true
                    } label: {
                        Image(systemName: "play.fill")
                    }
                    .padding()
                }
                
                        Image(systemName: "music.microphone")
                    Button {
                    } label: {
                        Image(systemName: "wand.and.stars")
                    }
                    
                    Spacer()
                    
                    Button {
                        isEditingScript = false
                        isEditingTitle = false
                    } label: {
                        Image(systemName: "checkmark")
                    }
                }
                        isEditingTitle = false
        }
        .overlay(alignment: .bottom) {
            if showEstimate && !isEditingScript && !isTyping {
                VStack {
                    Text("""
                               Word Count: \(wordCount)
                        Estimated Time: \(wrdEstimateString(for: wordCount, wpm: WPM))
                        
                        """)
                    .font(.headline)
                    .padding(.horizontal, 16)
                    .padding(.top)
                    .glassEffect()
                }
                .shadow(color: Color.black.opacity(0.1), radius: 12, x: 0, y: 4)
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
                .frame(maxWidth: .infinity, alignment: .center)
                .animation(.easeInOut(duration: 0.15), value: isTyping)
                .animation(.easeInOut(duration: 0.15), value: isEditingScript)
            }
        }
        .fullScreenCover(isPresented: $showScreent) {
            Screen3Teleprompter(title: $title, script: $script, WPM: $WPM, timer: timer, isPresented: $showScreent)
        }
        .onDisappear {
            typingResetTask?.cancel()
        }
            Screen3Teleprompter(title: $title, script: $script, WPM: $WPM, timer: timer)
}

#Preview {
    Screen22(
        title: .constant("untitled"),
        script: .constant("This is a test script.")
    )
}

