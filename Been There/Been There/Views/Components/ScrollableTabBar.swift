//
//  ScrollableTabBar.swift
//  Next-track
//
//  Custom pill-shaped scrollable tab bar with center circle selection,
//  haptic feedback, sound effects, and smooth animations
//

import SwiftUI
import UIKit
import AudioToolbox

// MARK: - Tab Item Model

struct TabItem: Identifiable {
    let id = UUID()
    let title: String
    let icon: String
    let color: Color
    let gradientColors: [Color]

    init(title: String, icon: String, color: Color, gradientColors: [Color]? = nil) {
        self.title = title
        self.icon = icon
        self.color = color
        self.gradientColors = gradientColors ?? [color, color.opacity(0.7)]
    }
}

// MARK: - Sound Manager

class TabBarSoundManager {
    static let shared = TabBarSoundManager()
    private init() {}

    func playSelectionSound() {
        AudioServicesPlaySystemSound(1104)
    }

    func playScrollTickSound() {
        AudioServicesPlaySystemSound(1519)
    }
}

// MARK: - Scrollable Tab Bar

struct ScrollableTabBar: View {
    @Binding var selectedTab: Int
    let tabs: [TabItem]
    let centerIndex: Int

    @Environment(\.colorScheme) private var colorScheme

    private let itemSize: CGFloat = 74
    private let circleSize: CGFloat = 74

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Pill-shaped background
                pillBackground

                // Center selection circle
                centerSelectionCircle

                // Tab picker using native Picker for reliability
                TabPicker(
                    selectedIndex: $selectedTab,
                    tabs: tabs,
                    itemSize: itemSize,
                    containerWidth: geometry.size.width
                )
            }
        }
        .frame(height: 75)
        .padding(.horizontal, 8)
        .offset(y: 10)
        .ignoresSafeArea(edges: .bottom)
    }

    // MARK: - Pill Background

    private var pillBackground: some View {
        ZStack {
            Capsule()
                .fill(colorScheme == .dark ? Color(white: 0.06) : Color(white: 0.93))

            Capsule()
                .fill(
                    LinearGradient(
                        colors: [
                            tabs[selectedTab].color.opacity(colorScheme == .dark ? 0.15 : 0.1),
                            .clear
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            Capsule()
                .fill(.ultraThinMaterial)

            Capsule()
                .stroke(
                    LinearGradient(
                        colors: [
                            tabs[selectedTab].color.opacity(0.5),
                            tabs[selectedTab].color.opacity(0.1)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1.5
                )
        }
        .shadow(color: tabs[selectedTab].color.opacity(0.35), radius: 12, x: 0, y: 5)
        .shadow(color: .black.opacity(0.12), radius: 4, x: 0, y: 2)
        .animation(.easeInOut(duration: 0.25), value: selectedTab)
    }

    // MARK: - Center Selection Circle

    private var centerSelectionCircle: some View {
        ZStack {
            Circle()
                .stroke(
                    AngularGradient(
                        colors: [
                            tabs[selectedTab].color,
                            tabs[selectedTab].color.opacity(0.6),
                            tabs[selectedTab].color.opacity(0.3),
                            tabs[selectedTab].color.opacity(0.6),
                            tabs[selectedTab].color
                        ],
                        center: .center
                    ),
                    lineWidth: 3
                )
                .frame(width: circleSize, height: circleSize)
                .shadow(color: tabs[selectedTab].color.opacity(0.7), radius: 8)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            tabs[selectedTab].color.opacity(0.2),
                            tabs[selectedTab].color.opacity(0.05),
                            .clear
                        ],
                        center: .center,
                        startRadius: 5,
                        endRadius: circleSize / 2
                    )
                )
                .frame(width: circleSize - 4, height: circleSize - 4)
        }
        .animation(.easeInOut(duration: 0.25), value: selectedTab)
    }
}

// MARK: - Tab Picker (UIKit-based for reliability)

struct TabPicker: UIViewRepresentable {
    @Binding var selectedIndex: Int
    let tabs: [TabItem]
    let itemSize: CGFloat
    let containerWidth: CGFloat

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.decelerationRate = .fast
        scrollView.delegate = context.coordinator

        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.spacing = 0
        stackView.distribution = .fillEqually
        stackView.translatesAutoresizingMaskIntoConstraints = false

        for (index, tab) in tabs.enumerated() {
            let tabView = createTabView(tab: tab, index: index, isSelected: index == selectedIndex, context: context)
            stackView.addArrangedSubview(tabView)
        }

        scrollView.addSubview(stackView)

        let sidePadding = (containerWidth - itemSize) / 2

        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            stackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            stackView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: sidePadding),
            stackView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -sidePadding),
            stackView.heightAnchor.constraint(equalTo: scrollView.heightAnchor)
        ])

        context.coordinator.scrollView = scrollView
        context.coordinator.stackView = stackView
        context.coordinator.itemSize = itemSize

        return scrollView
    }

    func updateUIView(_ scrollView: UIScrollView, context: Context) {
        // Update tab appearances
        if let stackView = context.coordinator.stackView {
            for (index, view) in stackView.arrangedSubviews.enumerated() {
                updateTabAppearance(view: view, tab: tabs[index], isSelected: index == selectedIndex)
            }
        }

        // Scroll to selected tab if changed externally
        if !context.coordinator.isScrolling {
            let targetOffset = CGFloat(selectedIndex) * itemSize
            if abs(scrollView.contentOffset.x - targetOffset) > 1 {
                scrollView.setContentOffset(CGPoint(x: targetOffset, y: 0), animated: true)
            }
        }
    }

    private func createTabView(tab: TabItem, index: Int, isSelected: Bool, context: Context) -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.tag = index

        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.alignment = .center
        stackView.spacing = 3
        stackView.translatesAutoresizingMaskIntoConstraints = false

        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.tintColor = isSelected ? UIColor(tab.color) : .gray
        imageView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(
            pointSize: isSelected ? 26 : 27,  // Inactive icons 50% larger (18 -> 27)
            weight: isSelected ? .bold : .medium
        )
        imageView.image = UIImage(systemName: tab.icon)
        imageView.tag = 100

        let label = UILabel()
        label.text = tab.title
        label.font = .systemFont(ofSize: isSelected ? 11 : 10, weight: isSelected ? .bold : .medium)
        label.textColor = isSelected ? UIColor(tab.color) : .gray
        label.tag = 101

        stackView.addArrangedSubview(imageView)
        stackView.addArrangedSubview(label)

        container.addSubview(stackView)

        NSLayoutConstraint.activate([
            container.widthAnchor.constraint(equalToConstant: itemSize),
            stackView.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            stackView.centerYAnchor.constraint(equalTo: container.centerYAnchor)
        ])

        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.tabTapped(_:)))
        container.addGestureRecognizer(tapGesture)

        let scale: CGFloat = isSelected ? 1.1 : 1.0  // No shrinking for inactive
        let alpha: CGFloat = isSelected ? 1.0 : 0.7  // More visible when inactive
        container.transform = CGAffineTransform(scaleX: scale, y: scale)
        container.alpha = alpha

        return container
    }

    private func updateTabAppearance(view: UIView, tab: TabItem, isSelected: Bool) {
        UIView.animate(withDuration: 0.25, delay: 0, options: .curveEaseInOut) {
            let scale: CGFloat = isSelected ? 1.1 : 1.0  // No shrinking for inactive
            view.transform = CGAffineTransform(scaleX: scale, y: scale)
            view.alpha = isSelected ? 1.0 : 0.7  // More visible when inactive

            if let imageView = view.viewWithTag(100) as? UIImageView {
                imageView.tintColor = isSelected ? UIColor(tab.color) : .gray
                imageView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(
                    pointSize: isSelected ? 26 : 27,  // Inactive icons 50% larger (18 -> 27)
                    weight: isSelected ? .bold : .medium
                )
                imageView.image = UIImage(systemName: tab.icon)
            }

            if let label = view.viewWithTag(101) as? UILabel {
                label.textColor = isSelected ? UIColor(tab.color) : .gray
                label.font = .systemFont(ofSize: isSelected ? 11 : 10, weight: isSelected ? .bold : .medium)
            }
        }
    }

    class Coordinator: NSObject, UIScrollViewDelegate {
        var parent: TabPicker
        var scrollView: UIScrollView?
        var stackView: UIStackView?
        var itemSize: CGFloat = 74
        var isScrolling = false
        var lastHapticIndex = -1

        init(_ parent: TabPicker) {
            self.parent = parent
            self.lastHapticIndex = parent.selectedIndex
        }

        @objc func tabTapped(_ gesture: UITapGestureRecognizer) {
            guard let view = gesture.view else { return }
            let index = view.tag

            parent.selectedIndex = index
            HapticManager.shared.selectionChanged()
            TabBarSoundManager.shared.playSelectionSound()

            if let scrollView = scrollView {
                let targetOffset = CGFloat(index) * itemSize
                scrollView.setContentOffset(CGPoint(x: targetOffset, y: 0), animated: true)
            }
        }

        func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
            isScrolling = true
        }

        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            let currentIndex = Int(round(scrollView.contentOffset.x / itemSize))
            let clampedIndex = max(0, min(parent.tabs.count - 1, currentIndex))

            // Haptic when crossing tab boundaries
            if clampedIndex != lastHapticIndex && isScrolling {
                lastHapticIndex = clampedIndex
                HapticManager.shared.buttonTap()
                TabBarSoundManager.shared.playScrollTickSound()
            }
        }

        func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
            // Snap to nearest tab
            let targetIndex = Int(round(targetContentOffset.pointee.x / itemSize))
            let clampedIndex = max(0, min(parent.tabs.count - 1, targetIndex))
            targetContentOffset.pointee.x = CGFloat(clampedIndex) * itemSize
        }

        func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
            if !decelerate {
                snapToNearestTab(scrollView)
            }
        }

        func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
            snapToNearestTab(scrollView)
        }

        private func snapToNearestTab(_ scrollView: UIScrollView) {
            isScrolling = false
            let currentIndex = Int(round(scrollView.contentOffset.x / itemSize))
            let clampedIndex = max(0, min(parent.tabs.count - 1, currentIndex))

            if clampedIndex != parent.selectedIndex {
                parent.selectedIndex = clampedIndex
                HapticManager.shared.selectionChanged()
                TabBarSoundManager.shared.playSelectionSound()
            }
        }
    }
}

// MARK: - App Tab Definitions

enum AppTab: Int, CaseIterable {
    case stats = 0
    case visited = 1      // Merged Cities + Countries
    case track = 2
    case insights = 3
    case settings = 4

    var tabItem: TabItem {
        switch self {
        case .stats:
            return TabItem(title: "Stats", icon: "chart.bar.fill", color: .blue, gradientColors: [.blue, .cyan])
        case .visited:
            return TabItem(title: "Visited", icon: "globe.americas.fill", color: .teal, gradientColors: [.teal, .purple])
        case .track:
            return TabItem(title: "Track", icon: "location.fill", color: .green, gradientColors: [.green, .mint])
        case .insights:
            return TabItem(title: "Insights", icon: "chart.pie.fill", color: .pink, gradientColors: [.pink, .red])
        case .settings:
            return TabItem(title: "Settings", icon: "gearshape.fill", color: Color(white: 0.5), gradientColors: [Color(white: 0.5), Color(white: 0.7)])
        }
    }

    static var allTabs: [TabItem] { allCases.map { $0.tabItem } }
    static var centerIndex: Int { AppTab.track.rawValue }
}

// MARK: - Preview

#Preview {
    VStack {
        Spacer()
        Text("Content Area").foregroundStyle(.secondary)
        Spacer()
        ScrollableTabBar(selectedTab: .constant(3), tabs: AppTab.allTabs, centerIndex: AppTab.centerIndex)
    }
    .background(Color(UIColor.systemGroupedBackground))
}

#Preview("Dark Mode") {
    VStack {
        Spacer()
        Text("Content Area").foregroundStyle(.secondary)
        Spacer()
        ScrollableTabBar(selectedTab: .constant(3), tabs: AppTab.allTabs, centerIndex: AppTab.centerIndex)
    }
    .background(Color(UIColor.systemGroupedBackground))
    .preferredColorScheme(.dark)
}
