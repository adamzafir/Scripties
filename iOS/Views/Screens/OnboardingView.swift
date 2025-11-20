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
            imageName: "light",
            title: "Welcome to Scripties",
            description: "Your personal speech coach. Write, practice, and perfect your presentations with feedback.",
            highlightColor: .blue
        ),
        OnboardingPage(
            imageName: "waveform.circle.fill",
            title: "Practice Your Speech",
            description: "Teleprompter in-app helps you to read naturally, using an autoscroll based on your voice.",
            highlightColor: .orange
        ),
        OnboardingPage(
            imageName: "chart.line.uptrend.xyaxis",
            title: "Get Detailed Feedback",
            description: "Track your words per minute and  speech consistency to improve your delivery.",
            highlightColor: .green
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
                HStack {
                    Spacer()
                    Button("Skip") {
                        completeOnboarding()
                    }
                    .foregroundColor(.blue)
                    .opacity(currentPage < pages.count - 1 ? 1 : 0)
                    .animation(.easeInOut(duration: 0.3), value: currentPage)
                    .padding()
                }
                .frame(height: 50)
                
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
                // Navigation buttons
                HStack(spacing: 20) {
                    if currentPage > 0 {
                        Button(action: {
                            withAnimation(.spring(response: 0.8)) {
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
                            .padding()
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
                        HStack(spacing: 8) {
                            ZStack {
                                Text("Next")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                    .opacity(currentPage == pages.count - 1 ? 0 : 1)
                                Text("Get Started")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                    .opacity(currentPage == pages.count - 1 ? 1 : 0)
                            }
                            if currentPage < pages.count - 1 {
                                Image(systemName: "chevron.right")
                                    .font(.headline)
                                    .transition(.opacity)
                            }
                        }
                        .animation(.spring(response: 0.3), value: currentPage)
                        .foregroundColor(.white)
                        .frame(width: 150, height: 50)
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
                    .padding()
                }
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
    @Environment(\.colorScheme) private var colorScheme
    private func resolvedImageName(from baseName: String) -> String {
        if baseName == "light" || baseName == "dark" {
            return colorScheme == .dark ? "dark" : "light"
        }
        return baseName
    }
    
    @ViewBuilder
    private func pageImage(named name: String, tint: Color) -> some View {
        let effectiveName = resolvedImageName(from: name)
        if let uiImage = UIImage(named: effectiveName) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFit()
                .frame(width: 100, height: 100)
        } else {
            Image(systemName: effectiveName)
                .resizable()
                .scaledToFit()
                .frame(width: 100, height: 100)
                .foregroundStyle(
                    LinearGradient(
                        colors: [tint, tint.opacity(0.6)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
    }
    
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
                
                pageImage(named: page.imageName, tint: page.highlightColor)
                    .padding()
            }
            .padding(.top, 20)
            
            VStack(spacing: 16) {
                Text(page.title)
                    .font(.system(size: 28, weight: .bold))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
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
