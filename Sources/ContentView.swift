import SwiftUI

enum Module: Int, CaseIterable, Hashable {
    case books      = 0
    case characters = 1
    case threads    = 2
    case timeline   = 3
    case more       = 4

    var label: String {
        switch self {
        case .books:      return "Books"
        case .characters: return "Characters"
        case .threads:    return "Threads"
        case .timeline:   return "Timeline"
        case .more:       return "More"
        }
    }

    var icon: String {
        switch self {
        case .books:      return "books.vertical"
        case .characters: return "person.2"
        case .threads:    return "bubble.left.and.bubble.right"
        case .timeline:   return "timeline.selection"
        case .more:       return "ellipsis"
        }
    }
}

struct ContentView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var selectedModule: Module = .books
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    var body: some View {
        ZStack {
            ParallaxBackgroundView()

            if horizontalSizeClass == .compact {
                TransparentTabBar(
                    selection: Binding(
                        get: { selectedModule.rawValue },
                        set: { selectedModule = Module(rawValue: $0) ?? .books }
                    ),
                    items: Module.allCases.map { (label: $0.label, icon: $0.icon) }
                ) {
                    moduleDetail(selectedModule)
                }
            } else {
                TransparentNavigationSplitView(
                    columnVisibility: $columnVisibility,
                    sidebarTitle: "ParallaxBGTest"
                ) {
                    sidebarContent
                } detail: {
                    moduleDetail(selectedModule)
                }
            }
        }
        .ignoresSafeArea()
    }

    private var sidebarContent: some View {
        VStack(spacing: 0) {
            List {
                ForEach(Module.allCases.filter { $0 != .more }, id: \.self) { module in
                    sidebarRow(module).listRowBackground(Color.clear)
                }
            }
            .listStyle(.sidebar)
            .listRowSpacing(0)
            .listSectionSpacing(0)
            .environment(\.defaultMinListRowHeight, 0)
            .scrollContentBackground(.hidden)

            Divider().background(Color.white.opacity(0.12))

            sidebarRow(.more)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
        }
    }

    private func sidebarRow(_ module: Module) -> some View {
        Button { selectedModule = module } label: {
            Label {
                Text(module.label).font(.headline)
            } icon: {
                Image(systemName: module.icon).font(.system(size: 12))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .foregroundStyle(selectedModule == module ? Color.accentColor : .primary)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 6)
        .padding(.vertical, 6)
        .listRowBackground(
            Group {
                if selectedModule == module {
                    RoundedRectangle(cornerRadius: 10).fill(.ultraThinMaterial)
                } else {
                    Color.clear
                }
            }
        )
        .listRowInsets(EdgeInsets(top: 0, leading: 6, bottom: 0, trailing: 10))
    }

    @ViewBuilder
    private func moduleDetail(_ module: Module) -> some View {
        switch module {
        case .books:      PlaceholderView(title: "Books",      icon: "books.vertical")
        case .characters: PlaceholderView(title: "Characters", icon: "person.2")
        case .threads:    PlaceholderView(title: "Threads",    icon: "bubble.left.and.bubble.right")
        case .timeline:   PlaceholderView(title: "Timeline",   icon: "timeline.selection")
        case .more:       PlaceholderView(title: "More",       icon: "ellipsis")
        }
    }
}

struct PlaceholderView: View {
    let title: String
    let icon: String

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: icon)
                .font(.system(size: 56, weight: .thin))
                .foregroundStyle(.white.opacity(0.7))
            Text(title)
                .font(.largeTitle.weight(.thin))
                .foregroundStyle(.white.opacity(0.9))
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
