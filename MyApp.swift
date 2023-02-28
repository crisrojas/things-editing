import SwiftUI



fileprivate var ramStore = createRamStore()
fileprivate var viewState = ViewState(store: ramStore)
fileprivate var appCore = createAppCore(store: ramStore)

@main
struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            Tabbar(viewState: viewState, appCore: appCore)
        }
    }
}

struct Tabbar: View {
    
    @StateObject var viewState: ViewState
    @State private var navbarHeight = CGFloat.zero
    let appCore: AppCore
    
    var body: some View {
        NavigationView {
            ContentView(viewState: viewState, appCore: appCore)
        }
        .onAppear { UINavigationBar.clearBackground()}
    }
}
