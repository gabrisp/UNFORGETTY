import SwiftUI

struct ContentView: View {
    @State private var progress: CGFloat = 0

    var body: some View {
        CreateActivityView(progress: $progress)
        .background(Color.secondarybg.ignoresSafeArea())
        .ignoresSafeArea(.keyboard)
    }
}
