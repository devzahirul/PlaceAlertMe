import SwiftUI

struct ContentView: View {
    @EnvironmentObject var viewModel: AppViewModel

    var body: some View {
        TabView(selection: $viewModel.selectedTab) {
            HomeScreen()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
                .tag(AppViewModel.Tab.home)

            MapScreen()
                .tabItem {
                    Label("Map", systemImage: "map.fill")
                }
                .tag(AppViewModel.Tab.map)

            SettingsScreen()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(AppViewModel.Tab.settings)
        }
        .accentColor(.purple)
    }
}

#Preview {
    ContentView()
        .environmentObject(AppViewModel())
}
