import SwiftUI

struct ContentView: View {
    @State private var progress: CGFloat = 0
    @EnvironmentObject private var flow: AppFlowViewModel

    var body: some View {
        TabView(selection: $flow.selectedTab) {
            Tab(value: RootTab.main) {
                CreateActivityView(progress: $progress)
            } label: {
                Label("Unforgetty", systemImage: "square.stack")
            }

            // `role: .search` pins this tab to the trailing edge of iOS 26's tab bar, visually
            // separated from the rest — used here purely for that position/styling, not for text
            // search (no `.searchable` attached): selecting it just shows the received-pings browser.
            Tab(value: RootTab.receivedFromFriends, role: .search) {
                ReceivedFromFriendsView()
            } label: {
                Label("From Friends", systemImage: "person.2")
            }
        }
        .background(Color.secondarybg.ignoresSafeArea())
        .ignoresSafeArea(.keyboard)
    }
}
