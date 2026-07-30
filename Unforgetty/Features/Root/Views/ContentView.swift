import SwiftUI

struct ContentView: View {
    @State private var activeTab: AppTab = .create
    @State private var progress: CGFloat = 0

    var body: some View {
        TabView(selection: $activeTab) {
            Tab.init(value: AppTab.create) {
                CreateActivityView(progress: $progress)
            }

            Tab.init(value: AppTab.created) {
                CreatedActivitiesView(progress: $progress)
            }
        }
        .background(Color.secondarybg.ignoresSafeArea())
        .ignoresSafeArea(.keyboard)
//        .overlay(alignment: .bottom) {
//            IGStyleTabBar(selection: $activeTab) { tab in
//                let image = UIImage(systemName: tab.systemImage)?
//                    .withConfiguration(UIImage.SymbolConfiguration(font: .systemFont(ofSize: 20)))
//                return image!
//            } onInteraction: {
//                if progress != 0 {
//                    withAnimation(.interpolatingSpring(duration: 0.25, bounce: 0, initialVelocity: 0)) {
//                        progress = 0
//                    }
//                }
//            }
//            .padding(4)
//            /// Adding Liquid Glass Background with interaction
//            .glassEffect(.regular.interactive(), in: .capsule)
//            .scaleEffect(1 - (progress * 0.15), anchor: .bottom)
//            .padding(.horizontal, 20)
//            .ignoresSafeArea(.keyboard)
//
//        }
    }
}
