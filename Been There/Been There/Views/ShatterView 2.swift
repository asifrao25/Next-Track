//
//  ShatterView.swift
//  Next-track
//
//  Shatter transition effect - content breaks into pieces
//

import SwiftUI

struct ShatterView<Content: View>: View {
    let shatter: Bool
    let content: Content

    private let rows = 6
    private let cols = 4

    init(shatter: Bool, @ViewBuilder content: () -> Content) {
        self.shatter = shatter
        self.content = content()
    }

    var body: some View {
        GeometryReader { geo in
            let tileWidth = geo.size.width / CGFloat(cols)
            let tileHeight = geo.size.height / CGFloat(rows)

            ForEach(0..<(rows * cols), id: \.self) { index in
                let row = index / cols
                let col = index % cols

                // Each tile clips a portion of the full content
                content
                    .frame(width: geo.size.width, height: geo.size.height)
                    .offset(
                        x: -CGFloat(col) * tileWidth,
                        y: -CGFloat(row) * tileHeight
                    )
                    .frame(width: tileWidth, height: tileHeight, alignment: .topLeading)
                    .clipped()
                    .offset(
                        x: CGFloat(col) * tileWidth + (shatter ? randomX(for: index) : 0),
                        y: CGFloat(row) * tileHeight + (shatter ? randomY(for: index) : 0)
                    )
                    .rotationEffect(.degrees(shatter ? randomRotation(for: index) : 0))
                    .scaleEffect(shatter ? 0.2 : 1.0)
                    .opacity(shatter ? 0 : 1)
                    .animation(
                        .easeOut(duration: 2.5).delay(Double(index) * 0.02),
                        value: shatter
                    )
            }
        }
    }

    // Deterministic random values based on index
    private func randomX(for index: Int) -> CGFloat {
        CGFloat(sin(Double(index * 13 + 7)) * 300)
    }

    private func randomY(for index: Int) -> CGFloat {
        CGFloat(cos(Double(index * 17 + 11)) * 500)
    }

    private func randomRotation(for index: Int) -> Double {
        sin(Double(index * 23 + 5)) * 180
    }
}
