//
//  OnboardingView.swift
//  yapLONGER
//
//  Created by Chan Yap Long on 17/11/25.
//
import SwiftUI

// MARK: - Onboarding Page Model
struct OnboardingPage: Identifiable {
    let id = UUID()
    let imageName: String
    let title: String
    let description: String
    let highlightColor: Color
}

// MARK: - Main Onboarding View
struct OnboardingView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false
    @State private var currentPage = 0
    
    let pages = [
        OnboardingPage(
            imageName: "text.book.closed.fill",
            title: "Welcome to Script Practice",
            description: "Your personal speech coach. Write, practice, and perfect your presentations with AI-powered feedback.",
            highlightColor: .blue
        ),
        OnboardingPage(
            imageName: "square.and.pencil",
            title: "Create & Edit Scripts",
            description: "Write your scripts or let AI help. Use the magic wand ✨ to rewrite sections with AI assistance.",
            highlightColor: .purple
        ),
        OnboardingPage(
            imageName: "waveform.circle.fill",
            title: "Practice Your Speech",
            description: "Choose Teleprompter mode for guided reading or Keywords mode to practice naturally with key points.",
            highlightColor: .orange
        ),
        OnboardingPage(
            imageName: "chart.line.uptrend.xyaxis",
            title: "Get Detailed Feedback",
            description: "Track your words per minute (ideal: 120 WPM), speech consistency, and silence patterns to improve your delivery.",
            highlightColor: .green
        ),
        OnboardingPage(
            imageName: "sparkles",
            title: "Beta Features Available",
            description: "Enable beta mode in settings to access experimental features and enhanced capabilities.",
            highlightColor: .pink
        ),
        OnboardingPage(
            imageName: "checkmark.seal.fill",
            title: "Ready to Practice!",
            description: "Start by creating your first script. Record yourself, get instant feedback, and become a confident speaker.",
            highlightColor: .cyan
        )
    ]
    
    var body: some View {
        ZStack {
            // Dynamic background gradient based on current page
            LinearGradient(
                colors: [
                    pages[currentPage].highlightColor.opacity(0.3),
                    pages[currentPage].highlightColor.opacity(0.1)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 0.5), value: currentPage)
            
            VStack(spacing: 20) {
                // Skip button
                HStack {
                    Spacer()
                    if currentPage < pages.count - 1 {
                        Button("Skip") {
                            completeOnboarding()
                        }
                        .foregroundColor(.primary)
                        .padding()
                    }
                }
                
                Spacer()
                
                // TabView for pages
                TabView(selection: $currentPage) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        OnboardingPageView(page: pages[index])
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .indexViewStyle(.page(backgroundDisplayMode: .always))
                
                Spacer()
                
                // Page indicators with custom styling
                HStack(spacing: 8) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        Circle()
                            .fill(index == currentPage ? pages[currentPage].highlightColor : Color.gray.opacity(0.3))
                            .frame(width: index == currentPage ? 10 : 8, height: index == currentPage ? 10 : 8)
                            .animation(.spring(response: 0.3), value: currentPage)
                    }
                }
                .padding(.bottom, 8)
                
                // Navigation buttons
                HStack(spacing: 20) {
                    if currentPage > 0 {
                        Button(action: {
                            withAnimation(.spring(response: 0.3)) {
                                currentPage -= 1
                            }
                        }) {
                            HStack {
                                Image(systemName: "chevron.left")
                                    .font(.headline)
                                Text("Back")
                                    .font(.headline)
                            }
                            .foregroundColor(.primary)
                            .frame(width: 100, height: 50)
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(12)
                        }
                    } else {
                        Spacer()
                            .frame(width: 100)
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        if currentPage < pages.count - 1 {
                            withAnimation(.spring(response: 0.3)) {
                                currentPage += 1
                            }
                        } else {
                            completeOnboarding()
                        }
                    }) {
                        HStack {
                            Text(currentPage == pages.count - 1 ? "Get Started" : "Next")
                                .font(.headline)
                                .fontWeight(.semibold)
                            if currentPage < pages.count - 1 {
                                Image(systemName: "chevron.right")
                                    .font(.headline)
                            }
                        }
                        .foregroundColor(.white)
                        .frame(width: currentPage == pages.count - 1 ? 150 : 100, height: 50)
                        .background(
                            LinearGradient(
                                colors: [
                                    pages[currentPage].highlightColor,
                                    pages[currentPage].highlightColor.opacity(0.7)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(12)
                        .shadow(color: pages[currentPage].highlightColor.opacity(0.4), radius: 8, x: 0, y: 4)
                    }
                }
                .padding(.horizontal, 30)
                .padding(.bottom, 30)
            }
        }
    }
    
    private func completeOnboarding() {
        withAnimation {
            hasCompletedOnboarding = true
        }
    }
}

// MARK: - Individual Onboarding Page
struct OnboardingPageView: View {
    let page: OnboardingPage
    @State private var isAnimating = false
    
    var body: some View {
        VStack(spacing: 30) {
            // Icon with animation
            ZStack {
                Circle()
                    .fill(page.highlightColor.opacity(0.2))
                    .frame(width: 180, height: 180)
                    .scaleEffect(isAnimating ? 1.1 : 1.0)
                    .animation(
                        Animation.easeInOut(duration: 2.0)
                            .repeatForever(autoreverses: true),
                        value: isAnimating
                    )
                
                Image(systemName: page.imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 100, height: 100)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [page.highlightColor, page.highlightColor.opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .padding()
            }
            .padding(.top, 20)
            
            VStack(spacing: 16) {
                Text(page.title)
                    .font(.system(size: 28, weight: .bold))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.primary, page.highlightColor],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                
                Text(page.description)
                    .font(.system(size: 17))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .lineSpacing(6)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding()
        .onAppear {
            isAnimating = true
        }
    }
}
#Preview("Onboarding") {
    OnboardingView()
}
