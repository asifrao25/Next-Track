//
//  ScrollableTabBar.swift
//  Next-track
//
//  Custom scrollable tab bar with momentum scrolling and center-anchored Track tab
//

import SwiftUI
import UIKit

// MARK: - Tab Item Model

struct TabItem: Identifiable {
    let id = UUID()
    let title: String
    let icon: String
    let color: Color
}

// MARK: - Scrollable Tab Bar

struct ScrollableTabBar: View {
    @Binding var selectedTab: Int
    let tabs: [TabItem]
    let centerIndex: Int  // Which tab is the "home" position (Track)

    @State private var scrollPosition: Int?
    @State private var contentOffset: CGFloat = 0
    @State private var isDragging: Bool = false

    // For edge fade indicators
    @State private var canScrollLeft: Bool = false
    @State private var canScrollRight: Bool = false

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .ignoresSafeArea(edges: .bottom)

                VStack(spacing: 0) {
                    // Top separator line
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 0.5)

                    // Scrollable tabs
                    ScrollViewReader { proxy in
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 4) {
                                // Leading spacer for centering
                                Spacer()
                                    .frame(width: max(0, geometry.size.width / 2 - 45))

                                ForEach(Array(tabs.enumerated()), id: \.element.id) { index, tab in
                                    TabButton(
                                        tab: tab,
                                        isSelected: selectedTab == index,
                                        action: {
                                            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                                selectedTab = index
                                                scrollPosition = index
                                            }
                                        }
                                    )
                                    .id(index)
                                }

                                // Trailing spacer for centering
                                Spacer()
                                    .frame(width: max(0, geometry.size.width / 2 - 45))
                            }
                            .padding(.horizontal, 8)
                            .background(
                                GeometryReader { scrollGeometry in
                                    Color.clear.preference(
                                        key: ScrollOffsetPreferenceKey.self,
                                        value: scrollGeometry.frame(in: .named("scroll")).minX
                                    )
                                }
                            )
                        }
                        .coordinateSpace(name: "scroll")
                        .onPreferenceChange(ScrollOffsetPreferenceKey.self) { offset in
                            contentOffset = offset
                            updateScrollIndicators(geometry: geometry)
                        }
                        .scrollTargetBehavior(.viewAligned)
                        .onAppear {
                            // Scroll to center tab on appear
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                withAnimation(.easeOut(duration: 0.3)) {
                                    proxy.scrollTo(centerIndex, anchor: .center)
                                }
                            }
                        }
                        .onChange(of: selectedTab) { _, newValue in
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                proxy.scrollTo(newValue, anchor: .center)
                            }
                        }
                    }
                    .frame(height: 65)
                }

                // Edge fade indicators
                HStack {
                    // Left fade
                    if canScrollLeft {
                        LinearGradient(
                            colors: [
                                Color(UIColor.systemBackground),
                                Color(UIColor.systemBackground).opacity(0)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: 25)
                        .overlay(alignment: .leading) {
                            EdgeIndicator(direction: .leading)
                                .padding(.leading, 4)
                        }
                        .allowsHitTesting(false)
                    }

                    Spacer()

                    // Right fade
                    if canScrollRight {
                        LinearGradient(
                            colors: [
                                Color(UIColor.systemBackground).opacity(0),
                                Color(UIColor.systemBackground)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: 25)
                        .overlay(alignment: .trailing) {
                            EdgeIndicator(direction: .trailing)
                                .padding(.trailing, 4)
                        }
                        .allowsHitTesting(false)
                    }
                }
                .padding(.top, 0.5)  // Account for separator
            }
        }
        .frame(height: 65)
    }

    private func updateScrollIndicators(geometry: GeometryProxy) {
        let screenWidth = geometry.size.width
        let tabWidth: CGFloat = 76  // Tab width + spacing
        let totalContentWidth = CGFloat(tabs.count) * tabWidth + screenWidth - 90

        // Check if we can scroll in either direction
        canScrollLeft = contentOffset < -10
        canScrollRight = contentOffset > -(totalContentWidth - screenWidth - 10)
    }
}

// MARK: - Tab Button

struct TabButton: View {
    let tab: TabItem
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: tab.icon)
                    .font(.system(size: isSelected ? 22 : 18, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? tab.color : .gray)
                    .frame(height: 24)

                Text(tab.title)
                    .font(.system(size: 10, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? tab.color : .gray)
                    .lineLimit(1)
            }
            .frame(width: 72, height: 52)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? tab.color.opacity(0.12) : Color.clear)
            )
            .scaleEffect(isSelected ? 1.05 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isSelected)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Edge Indicator

struct EdgeIndicator: View {
    let direction: HorizontalEdge

    @State private var isAnimating = false

    var body: some View {
        Image(systemName: direction == .leading ? "chevron.left" : "chevron.right")
            .font(.system(size: 10, weight: .bold))
            .foregroundColor(.gray.opacity(0.5))
            .offset(x: isAnimating ? (direction == .leading ? -2 : 2) : 0)
            .animation(
                Animation.easeInOut(duration: 0.7)
                    .repeatForever(autoreverses: true),
                value: isAnimating
            )
            .onAppear { isAnimating = true }
    }
}

// MARK: - Scroll Offset Preference Key

struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - App Tab Definitions

enum AppTab: Int, CaseIterable {
    case stats = 0
    case cities = 1
    case places = 2
    case track = 3
    case insights = 4
    case settings = 5

    var tabItem: TabItem {
        switch self {
        case .stats:
            return TabItem(title: "Stats", icon: "chart.bar.fill", color: .blue)
        case .cities:
            return TabItem(title: "Cities", icon: "building.2.fill", color: .purple)
        case .places:
            return TabItem(title: "Places", icon: "mappin.circle.fill", color: .orange)
        case .track:
            return TabItem(title: "Track", icon: "location.fill", color: .green)
        case .insights:
            return TabItem(title: "Insights", icon: "chart.pie.fill", color: .pink)
        case .settings:
            return TabItem(title: "Settings", icon: "gearshape.fill", color: .gray)
        }
    }

    static var allTabs: [TabItem] {
        allCases.map { $0.tabItem }
    }

    static var centerIndex: Int {
        AppTab.track.rawValue  // Track is at index 3
    }
}

// MARK: - Preview

#Preview {
    VStack {
        Spacer()
        Text("Content Area")
        Spacer()
        ScrollableTabBar(
            selectedTab: .constant(3),
            tabs: AppTab.allTabs,
            centerIndex: AppTab.centerIndex
        )
    }
    .background(Color(UIColor.systemGroupedBackground))
}
