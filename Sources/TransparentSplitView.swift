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
//   • @State indicatorOffset: CGFloat — directly animatable by withAnimation.
//     Using Int was the bug: SwiftUI can't interpolate Int for smooth slides.
//   • @GestureState dragTranslation added on top for real-time finger tracking.
//   • Tap: withAnimation(spring) { indicatorOffset = targetOffset(i) } → smooth slide.
//   • Drag: .simultaneousGesture so buttons AND drag both work. dragTranslation
//     follows finger; .onEnded snaps with withAnimation.
//   • Outer pill: 1.05× bounce on tap, 1.04× scale during drag.
//   • Only pressed button's content scales (PressScaleButtonStyle).

private struct TabBarPill: View {
    @Binding var selection: Int
    let items: [(label: String, icon: String)]

    // CGFloat — directly animatable. withAnimation smoothly interpolates the x offset.
    // Int was the bug: SwiftUI can't interpolate Int, so no slide animation fired.
    @State private var indicatorOffset: CGFloat = 0
    // Gesture framework writes this directly, so it updates every frame during drag
    // regardless of button gesture competition.
    @GestureState private var dragTranslation: CGFloat = 0
    @State private var pillScale: CGFloat = 1.0

    private let itemWidth: CGFloat  = 70
    private let itemHeight: CGFloat = 56
    private let indicatorInset: CGFloat = 5

    private let spring      = Animation.spring(response: 0.33, dampingFraction: 0.72)
    private let pressSpring = Animation.spring(response: 0.22, dampingFraction: 0.6)

    private func targetOffset(for index: Int) -> CGFloat {
        CGFloat(index) * itemWidth + indicatorInset
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            indicator
            HStack(spacing: 0) {
                ForEach(items.indices, id: \.self) { i in
                    tabItem(index: i)
                        .frame(width: itemWidth, height: itemHeight)
                }
            }
        }
        .onAppear { indicatorOffset = targetOffset(for: selection) }
        .onChange(of: selection) { _, v in
            withAnimation(spring) { indicatorOffset = targetOffset(for: v) }
        }
        .scaleEffect(pillScale)
        .animation(pressSpring, value: pillScale)
        // simultaneousGesture lets buttons AND the drag both fire.
        // Buttons handle tap-to-select. Drag handles swipe-to-slide.
        .simultaneousGesture(
            DragGesture(minimumDistance: 10)
                .updating($dragTranslation) { value, state, _ in
                    state = value.translation.width
                }
                .onChanged { _ in
                    if pillScale < 1.04 { pillScale = 1.04 }
                }
                .onEnded { value in
                    let currentX = indicatorOffset + value.translation.width
                    let lo = indicatorInset
                    let hi = targetOffset(for: items.count - 1)
                    let clamped = min(max(Int(((currentX - indicatorInset) / itemWidth).rounded()), 0), items.count - 1)
                    withAnimation(spring) { indicatorOffset = targetOffset(for: clamped) }
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
            .frame(width: itemWidth - indicatorInset * 2, height: itemHeight - indicatorInset * 2)
            // indicatorOffset is CGFloat → withAnimation interpolates it smoothly.
            // dragTranslation adds live finger tracking on top.
            .offset(x: indicatorOffset + dragTranslation, y: indicatorInset)
    }

    @ViewBuilder
    private func tabItem(index i: Int) -> some View {
        let isSelected = selection == i
        Button {
            withAnimation(spring) { indicatorOffset = targetOffset(for: i) }
            selection = i
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
