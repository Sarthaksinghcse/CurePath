
import SwiftUI
private struct OnboardingPage {
    let symbol: String
    let symbolColor: Color
    let title: String
    let body: String
}

private let pages: [OnboardingPage] = [
    OnboardingPage(
        symbol: "cross.case.fill",
        symbolColor: .blue,
        title: "Welcome to CurePath",
        body: "Your personal first aid companion for scanning wounds, get guided treatment, and track healing. All offline, all private."
    ),
    OnboardingPage(
        symbol: "camera.viewfinder",
        symbolColor: .blue,
        title: "Scan Any Wound",
        body: "Point your camera at a cut, burn, or abrasion. The on-device AI identifies the injury and tells you what to do next."
    ),
    OnboardingPage(
        symbol: "list.bullet.clipboard.fill",
        symbolColor: .blue,
        title: "Guided First Aid",
        body: "Follow animated, voice-guided steps at your own pace. Each step is timed so there's no guessing."
    ),
    OnboardingPage(
        symbol: "chart.line.downtrend.xyaxis",
        symbolColor: .blue,
        title: "Track Your Recovery",
        body: "Add a daily photo and CurePath shows whether your wound is healing, stable, or needs a doctor."
    )
]

// MARK: - Main View

struct OnboardingView: View {
    @Binding var hasSeenOnboarding: Bool
    @State private var currentPage = 0

    private var isLastPage: Bool { currentPage == pages.count - 1 }

    var body: some View {
        ZStack(alignment: .top) {

            // Pages
            TabView(selection: $currentPage) {
                ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                    OnboardingPageView(page: page)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut, value: currentPage)

            // Skip — top right, hidden on last page
            if !isLastPage {
                HStack {
                    Spacer()
                    Button("Skip") {
                        HapticFeedback.light()
                        hasSeenOnboarding = true
                    }
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.top, 16)
                    .padding(.trailing, 24)
                }
            }

            // Bottom controls
            VStack {
                Spacer()
                VStack(spacing: 24) {
                    // Dots
                    HStack(spacing: 8) {
                        ForEach(0..<pages.count, id: \.self) { i in
                            Capsule()
                                .fill(i == currentPage
                                      ? Color.primary
                                      : Color.secondary.opacity(0.25))
                                .frame(width: i == currentPage ? 20 : 8, height: 8)
                                .animation(.spring(response: 0.3), value: currentPage)
                        }
                    }

                    // Primary button
                    Button {
                        HapticFeedback.medium()
                        if isLastPage {
                            hasSeenOnboarding = true
                        } else {
                            withAnimation { currentPage += 1 }
                        }
                    } label: {
                        Text(isLastPage ? "Get Started" : "Continue")
                            .font(.body)
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(14)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 52)
            }
        }
    }
}

// MARK: - Page View

private struct OnboardingPageView: View {
    let page: OnboardingPage

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Symbol
            Image(systemName: page.symbol)
                .font(.system(size: 72, weight: .regular))
                .foregroundStyle(page.symbolColor)
                .symbolRenderingMode(.hierarchical)

            Spacer().frame(height: 48)

            // Title
            Text(page.title)
                .font(.title2)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Spacer().frame(height: 16)

            // Body — short, single idea per screen
            Text(page.body)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(5)
                .padding(.horizontal, 44)

            Spacer()
            Spacer()
        }
    }
}

#Preview {
    OnboardingView(hasSeenOnboarding: .constant(false))
}
