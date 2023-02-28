import SwiftUI

struct Item: Identifiable, Equatable, Hashable {
    let id: UUID
    let name: String
    
    static func ==(lhs: Self, rhs: Self) -> Bool {lhs.id == rhs.id}
}

extension Item {
    init(name: String) {id = UUID() ; self.name = name}
    init(_ id: UUID, _ name: String) {
        self.id = id ; self.name = name
    }
}

extension Item {
    enum Change {case editName(String)}
    func change(_ change: Change) -> Self {
        switch change {
        case .editName(let name): return .init(id, name)
        }
    }
}

extension Animation {
    static let standard = Animation.linear(duration:  0.15)
    static let  dismiss = Animation.linear(duration: 0.075)
}

enum Message { case edit(Item) ; case addOverlay(Overlay) }
typealias   Input = (Message) -> Void
typealias  Output = (Message) -> Void
typealias AppCore = (Message) -> Void

enum Overlay {case editingItem(Item, position: CGPoint)}
struct AppState {let items: [Item] ; let overlay: Overlay?}
extension AppState {enum Change {case edit(Item); case addOverlay(Overlay)}}
extension AppState {
    func change(_ change: Change) -> Self {
        switch change {
        case .edit(let item):
            let items = items.filter({$0.id != item.id}) + [item]
            return AppState(items: items, overlay: overlay)
        case .addOverlay(let overlay):
            return AppState(items: items, overlay: overlay)
        }
    }
}


typealias Sink   = (@escaping()->()) -> Void
typealias Change = (AppState.Change) -> Void
typealias Access = (               ) -> AppState
typealias StateStore = (state: Access, change: Change, sink: Sink)

extension Array where Element == ()->() { func call() { self.forEach{$0()}} }


final class ViewState: ObservableObject {
    @Published var items = [Item]()
    @Published var overlay: Overlay?
    
    init(store: StateStore) {
        store.sink {self.process(store.state())}
        process(store.state())
    }
    func process(_ state: AppState) {
        items = state.items.sorted(by: { $0.name < $1.name})
        overlay = state.overlay
        
    }
}

func createRamStore() -> StateStore {
    let initModel = Array(0...70).map {Item(name: "Item " + $0.description)}
    var state = AppState(items: initModel, overlay: nil) {didSet{sinks.call()}}
    var sinks = [()->()]()
    return (
        state: {state},
        change: {state = state.change($0)},
        sink: {sinks.append($0)}
    )
}

func createAppCore(store: StateStore) -> AppCore {{
    if case .edit(let item) = $0 {store.change(.edit(item))}
    if case .addOverlay(let overlay) = $0 {store.change(.addOverlay(overlay))}
}}


extension UINavigationBar {
    static func clearBackground() {
        UINavigationBar.appearance().barTintColor = .clear
        UINavigationBar.appearance().setBackgroundImage(UIImage(), for: .default)
        UINavigationBar.appearance().shadowImage = UIImage()
    }
}

struct ContentView: View {
    
    @State private var editingItem: Item?
    @State private var editingName: String = ""
    
    let viewState: ViewState
    let appCore: AppCore
    
    private func selectedItem(_ item: Item) -> Bool {editingItem==item}
    private var isEditing: Bool {editingItem != nil}
    private let editTextOpacity = 0.8
    
    var body: some View {
        scrollView
            .onTapGesture {dismissAction()}
            .animation(.spring(), value: viewState.items)
            .background(
                Group {
                    isEditing ? Color.black.opacity(0.3) : Color.clear
                }
                .edgesIgnoringSafeArea(.all)
            )
            .navigationTitle("Hello")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(
                    placement: .principal,
                    content: {
                        HStack {
                            Spacer()
                            Text("Hello")
                            Spacer()
                        }.contentShape(Rectangle())
                            .opacity(0)
//                            .opacity(isEditing ? editTextOpacity : 1)
                            .onTapGesture {dismissAction()}
                    }
                )
            }
            .onChange(of: editingItem) {
                if let name = $0?.name { editingName = name }
            }
        
    }
    var editingBackground: some View {
        Color.black.opacity(0.5).onTapGesture {
            dismissAction()
        }
    }
    
    @State private var navbarHeight = CGFloat.zero
    @State private var queue = [ItemQueue]()
    @State private var currentlyShowing = [ItemQueue]()
    struct ItemQueue: Equatable {
        let index: Int
        let item: Item
    }
    
    var scrollView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Image(systemName: "archivebox.fill")
                            .resizable()
                            .frame(width: 22)
                            .frame(height: 22)
                            .foregroundColor(.yellow)
                            
                        Text("Entrada")
                            .font(.title)
                            .fontWeight(.black)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 24)
                    .padding(.bottom, 32)
                    .opacity(isEditing ? editTextOpacity : 1)
                    
                    ForEach(viewState.items) { item in
                        
                        Row(
                            editingItem: $editingItem,
                            editingName: $editingName,
                            scrollProxy: proxy,
                            model: item,
                            update: update(_:),
                            dismissEdit: dismissAction
                        )
                        .id(item.id)
                        .opacity(isEditing ? (selectedItem(item) ? 1 : 0.5) : 1)
                        .onDisappear {
                            if let index = queue.firstIndex(where: {$0.item.id == item.id}) {
                                queue.remove(at: index)
                            }
                        }
                        .onAppear {
                            if let index = viewState.items.firstIndex(of: item) {
                                queue.append(ItemQueue(index: index, item: item))
                            }
                        }
                        .onChange(of: queue) { newValue in
                            print("Values:")
                            let sorted = newValue.sorted(by: {$0.index < $1.index})
                            sorted.forEach { print($0.item.name) }
                            currentlyShowing = sorted
                        }
                    }
                }
                
            }
        }
    }
    
    func update(_ item: Item) {appCore(.edit(item))}
    func dismissAction() {
        if let editingItem = editingItem {
            let index = viewState.items.firstIndex(of: editingItem)
            let oldItem = viewState.items[index!]
            if oldItem.name != editingName {
                update(editingItem.change(.editName(editingName)))
            }
        }
        dismissEditing()
    }
    
    func dismissEditing() {withAnimation(.standard) {editingItem = nil}}
}


extension View {
    
    func geometryReader(callback c: @escaping (GeometryProxy) -> Void) -> some View {
        self.background(
            GeometryReader { geo in
                Color.clear.onAppear {c(geo)}
            }
        )
    }
    func buttonify(performing action: @escaping () -> Void) -> some View {
        Button(action: {action()}, label: {self})
    }
}

struct RowButtonStyle: ButtonStyle {
    let namespace: Namespace.ID
    let isEditing: Bool
    
    func makeBody(configuration: Configuration) -> some View {
        
        let pressedBg = configuration.isPressed
        ? Color(uiColor: .systemBlue)
        : Color.clear
        
        let background = isEditing ? Color.clear : pressedBg
        
        return configuration.label
            .clipShape(Rectangle())
            .background(background.cornerRadius(6).matchedGeometryEffect(id: "background", in: namespace))
            .animation(.linear(duration: 0.3), value: configuration.isPressed)
    }
}

struct Row: View {
    @Namespace var namespace
    @FocusState var focused: Bool
    @Binding var editingItem: Item?
    @Binding var editingName: String
    
    let scrollProxy: ScrollViewProxy
    let model: Item
    let update: (Item) -> Void
    let dismissEdit: () -> Void
    
    private var isEditing: Bool { editingItem == model }
    @State private var editing = false
    
    var body: some View {
        
        if isEditing { editingRow }
        else { collapsedRow }
    }
    
    @State private var position =  CGPoint.zero
    var collapsedRow: some View {
        row
            .frame(height: 48)
            .padding(.horizontal, 12)
            .contentShape(Rectangle())
            .buttonify(performing: tapAction)
            .buttonStyle(
                RowButtonStyle(namespace: namespace, isEditing: editingItem != nil)
            )
            .padding(.horizontal, 8)
            .geometryReader(callback: { position = $0.frame(in: .global).origin })
    }
    
    func tapAction() {
        withAnimation(.standard) {
            if editingItem == nil {
                editingItem = model
               // scrollProxy.scrollTo(model.id, anchor: .bottom)
            }
            else {dismissEdit()}
        }
    }
    
    
    func submitAction() {
        if editingName != model.name {
            update(model.change(.editName(editingName)))
        }
        withAnimation(.standard) { editingItem = nil }
    }
    
    
    var editingRow: some View {
        VStack {
            HStack {
                TextField("Nueva tarea", text: $editingName)
                    .focused($focused)
                    .fontWeight(.bold)
                    .onSubmit { submitAction() }
                    .submitLabel(.done)
                    .matchedGeometryEffect(id: "textfield", in: namespace)
                Spacer()
            }
            Spacer()
        }
        .padding(.top, 12)
        .frame(height: 120)
        .padding(.horizontal, 12)
        // - Needed for capture clicks & not trigger the parent scrollView tap Event
        .contentShape(Rectangle())
        .buttonify{}
        .buttonStyle(.plain)
        // -
        .background(editingRowBackground.matchedGeometryEffect(id: "background", in: namespace))
    }
    
    var editingRowBackground: some View {
        Color(uiColor: .systemGray6)
            .cornerRadius(4)
            .shadow(color: .black.opacity(0.3), radius: 3, x: 0, y: 0)
    }
    
    var row: some View {
        HStack {
            TextField("Nueva tarea", text: .constant(model.name))
                .fontWeight(.bold)
                .disabled(true)
                .matchedGeometryEffect(id: "textfield", in: namespace)
            Spacer()
        }
    }
}
