import SwiftUI

struct ContentView: View {
    @State private var progress: CGFloat = 0

    var body: some View {
        // Friend pings are browsed inside CreateActivityV2View itself now (same screen, same
        // NavigationStack, same card-open animation — just a different data source for the grid),
        // not a separate screen reached via a floating button. See CreateActivityV2View's
        // cardSource/toolbar menu.
        CreateActivityView(progress: $progress)
            .background(Color.secondarybg.ignoresSafeArea())
            .ignoresSafeArea(.keyboard)
    }
}
