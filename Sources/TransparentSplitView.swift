import SwiftUI
import UIKit

// MARK: - TransparentNavigationSplitView

public struct TransparentNavigationSplitView<Sidebar: View, Detail: View>: View {
    @Binding var columnVisibility: NavigationSplitViewVisibility
    var sidebarTitle: String
    var sidebarWidth: CGFloat
    @ViewBuilder var sidebar: () -> Sidebar
    @ViewBuilder var detail: () -> Detail

    public init(
        columnVisibility: Binding<NavigationSplitViewVisibility> = .constant(.all),
        sidebarTitle: String = "",
        sidebarWidth: CGFloat = 260,
        @ViewBuilder sidebar: @escaping () -> Sidebar,
        @ViewBuilder detail: @escaping () -> Detail
    ) {
        self._columnVisibility = columnVisibility
        self.sidebarTitle = sidebarTitle
        self.sidebarWidth = sidebarWidth
        self.sidebar = sidebar
        self.detail = detail
    }

    public var body: some View {
        HStack(spacing: 0) {
            if columnVisibility != .detailOnly {
                SidebarColumn(title: sidebarTitle, width: sidebarWidth, content: sidebar)
                    .transition(.move(edge: .leading))
            }
            detail()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .animation(.easeInOut(duration: 0.25), value: columnVisibility)
    }
}

// MARK: - SidebarColumn

private struct SidebarColumn<Content: View>: View {
    let title: String
    let width: CGFloat
    @ViewBuilder let content: () -> Content

    var body: some View {
        ZStack(alignment: .trailing) {
            Rectangle()
                .fill(.thinMaterial)
                .ignoresSafeArea()
            VStack(spacing: 0) {
                SidebarNavigationBar(title: title)
                content()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            Rectangle()
                .fill(Color.primary.opacity(0.12))
                .frame(width: 0.5)
        }
        .frame(width: width)
        .ignoresSafeArea()
    }
}

// MARK: - SidebarNavigationBar

private struct SidebarNavigationBar: View {
    let title: String

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                Spacer().frame(height: navBarContentHeight)
                Rectangle()
                    .fill(Color.primary.opacity(0.12))
                    .frame(height: 0.5)
            }
            Text(title)
                .font(.headline)
                .foregroundStyle(.primary)
                .padding(.bottom, 10)
        }
        .frame(height: navBarTotalHeight)
    }

    private var navBarTotalHeight: CGFloat { statusBarHeight + 44 }
    private var navBarContentHeight: CGFloat { navBarTotalHeight - 0.5 }
    private var statusBarHeight: CGFloat {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.statusBarManager?.statusBarFrame.height ?? 44
    }
}

// MARK: - TransparentTabBar

public struct TransparentTabBar<Content: View>: View {
    @Binding var selection: Int
    let items: [(label: String, icon: String)]
    @ViewBuilder let content: () -> Content

    public var body: some View {
        ZStack(alignment: .bottom) {
            // Content in its own layer — identity changes here don't affect the pill
            content()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea(edges: .bottom)
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    Color.clear.frame(height: 80)
                }

            // Pill is a ZStack sibling, NOT an overlay.
            // Siblings have independent SwiftUI identity — the pill is never
            // unmounted when content switches module identity.
            TabBarPill(selection: $selection, items: items)
        }
        .ignoresSafeArea()
    }
}

// MARK: - TabBarPill
//
// No-flash floating pill tab bar with drag-to-switch.
//
// Key design decisions:
//   • indicator offset = indicatorIndex * itemWidth + @GestureState dragTranslation
//   • Tap: withAnimation { indicatorIndex = i } — spring slide via withAnimation
//   • Drag: @GestureState dragTranslation updates in real-time (gesture framework
//     bypasses child button priority). On end, withAnimation snaps indicatorIndex.
//   • highPriorityGesture — drag (>8pt) wins over child button taps. Taps (<8pt)
//     still fire buttons because DragGesture fails to start.
//   • Outer pill scales 1.05× on tap (Task bounce), 1.04× while dragging.
//   • Only the pressed button's content scales up (PressScaleButtonStyle).

private struct TabBarPill: View {
    @Binding var selection: Int
    let items: [(label: String, icon: String)]

    @State private var indicatorIndex: Int = 0
    @State private var pillScale: CGFloat = 1.0
    // @GestureState is updated directly by the gesture framework — bypasses button
    // gesture priority so the indicator tracks the finger even when touch starts on a button.
    @GestureState private var dragTranslation: CGFloat = 0

    private let itemWidth: CGFloat  = 70   // narrower to fit 5 tabs
    private let itemHeight: CGFloat = 56
    private let indicatorInset: CGFloat = 5

    private let spring      = Animation.spring(response: 0.33, dampingFraction: 0.72)
    private let pressSpring = Animation.spring(response: 0.22, dampingFraction: 0.6)

    // Indicator x position: slot base + live drag delta, clamped to pill bounds
    private var indicatorX: CGFloat {
        let base = CGFloat(indicatorIndex) * itemWidth + indicatorInset
        let lo   = indicatorInset
        let hi   = CGFloat(items.count - 1) * itemWidth + indicatorInset
        return min(max(base + dragTranslation, lo), hi)
    }

    var body: some View {
        ZStack(alignment: .topLeading) {

            // ── Persistent indicator (never removed) ──────────────────
            indicator

            // ── Tab items ────────────────────────────────────────────
            HStack(spacing: 0) {
                ForEach(items.indices, id: \.self) { i in
                    tabItem(index: i)
                        .frame(width: itemWidth, height: itemHeight)
                }
            }
        }
        .onAppear { indicatorIndex = selection }
        .onChange(of: selection) { _, v in
            withAnimation(spring) { indicatorIndex = v }
        }
        .scaleEffect(pillScale)
        .animation(pressSpring, value: pillScale)
        // ── Drag gesture: highPriority overrides child button priority so drag
        //    always starts after 8pt movement. Taps (<8pt) still fire buttons. ──
        .highPriorityGesture(
            DragGesture(minimumDistance: 8)
                .updating($dragTranslation) { value, state, _ in
                    state = value.translation.width
                }
                .onChanged { _ in
                    // Implicit animation via .animation(pressSpring, value: pillScale)
                    if pillScale < 1.04 { pillScale = 1.04 }
                }
                .onEnded { value in
                    let base    = CGFloat(indicatorIndex) * itemWidth
                    let finalX  = base + value.translation.width
                    let clamped = min(max(Int((finalX / itemWidth).rounded()), 0), items.count - 1)
                    withAnimation(spring) { indicatorIndex = clamped }
                    selection = clamped
                    withAnimation(pressSpring) { pillScale = 1.0 }
                }
        )
        // ── Outer pill chrome ─────────────────────────────────────────
        .background {
            ZStack {
                Capsule().fill(.ultraThinMaterial)
                Capsule()
                    .fill(
                        LinearGradient(
                            stops: [
                                .init(color: .white.opacity(0.26), location: 0),
                                .init(color: .white.opacity(0.08), location: 0.35),
                                .init(color: .clear, location: 0.6),
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
        }
        .overlay {
            Capsule()
                .strokeBorder(Color.white.opacity(0.22), lineWidth: 0.5)
        }
        .shadow(color: .black.opacity(0.30), radius: 30, x: 0, y: 12)
        .shadow(color: .black.opacity(0.10), radius: 5,  x: 0, y: 2)
        .padding(.bottom, safeAreaBottom + 4)
    }

    // Indicator: offset driven by indicatorX (= slot + dragOffset).
    // No .animation() modifier — all motion comes from withAnimation calls above.
    private var indicator: some View {
        Capsule()
            .fill(Color.accentColor.opacity(0.07))
            .overlay {
                Capsule()
                    .strokeBorder(Color.accentColor.opacity(0.55), lineWidth: 1.5)
            }
            .overlay {
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [.white.opacity(0.18), .clear],
                            startPoint: .top,
                            endPoint: .center
                        )
                    )
            }
            .frame(
                width:  itemWidth  - indicatorInset * 2,
                height: itemHeight - indicatorInset * 2
            )
            .offset(x: indicatorX, y: indicatorInset)
    }

    @ViewBuilder
    private func tabItem(index i: Int) -> some View {
        let isSelected = selection == i

        Button {
            withAnimation(spring) { indicatorIndex = i }
            selection = i
            // Bounce the outer pill
            withAnimation(.spring(response: 0.18, dampingFraction: 0.45)) { pillScale = 1.05 }
            Task {
                try? await Task.sleep(for: .milliseconds(130))
                withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) { pillScale = 1.0 }
            }
        } label: {
            VStack(spacing: 3) {
                Image(systemName: items[i].icon)
                    .font(.system(size: 18, weight: isSelected ? .semibold : .regular))
                Text(items[i].label)
                    .font(.system(size: 10, weight: isSelected ? .semibold : .regular))
                    .lineLimit(1)
            }
            .foregroundStyle(isSelected ? Color.accentColor : .secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .buttonStyle(PressScaleButtonStyle())
        .contentShape(Rectangle())
        .animation(spring, value: selection)
    }

    private var safeAreaBottom: CGFloat {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.windows.first?.safeAreaInsets.bottom ?? 0
    }
}

// MARK: - PressScaleButtonStyle

/// Only the pressed button's content scales up — other tabs are unaffected.
private struct PressScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 1.15 : 1.0)
            .animation(.spring(response: 0.18, dampingFraction: 0.5), value: configuration.isPressed)
    }
}
