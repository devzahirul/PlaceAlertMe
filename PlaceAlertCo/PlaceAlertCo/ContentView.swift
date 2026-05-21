import SwiftUI
import PlaceAlertMe

struct ContentView: View {
    @AppStorage("hasOnboarded") var hasOnboarded = false
    @State private var selectedTab = 0

    var body: some View {
        if !hasOnboarded {
            OnboardingView()
        } else {
            TabView(selection: $selectedTab) {
                NavigationStack {
                    HomeView()
                }
                .tabItem {
                    Label("Alerts", systemImage: "list.bullet")
                }
                .tag(0)

                NavigationStack {
                    MapTabView()
                        .toolbar(.hidden, for: .navigationBar)
                }
                .tabItem {
                    Label("Map", systemImage: "map")
                }
                .tag(1)

                NavigationStack {
                    TransitionsView()
                }
                .tabItem {
                    Label("Transitions", systemImage: "point.topleft.down.curvedto.point.bottomright.up")
                }
                .tag(2)

                NavigationStack {
                    SettingsView()
                }
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(3)
            }
        }
    }
}

#Preview {
    ContentView()
}
