import SwiftUI
struct ContentView: View {
    @State private var selectedTab = 0
    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem {
                    Image(systemName: "house.fill")
                    Text("Home")
                }
                .tag(0)

            HistoryView()
                .tabItem {
                    Image(systemName: "clock.fill")
                    Text("History")
                }
                .tag(1)
        }
        .accentColor(.blue)
        .onReceive(NotificationCenter.default.publisher(for: .switchToHomeTab)) { _ in
            withAnimation { selectedTab = 0 }
        }
        .onReceive(NotificationCenter.default.publisher(for: .switchToHistoryTab)) { _ in
            withAnimation { selectedTab = 1 }
        }
    }
}

#Preview {
    ContentView()
}
