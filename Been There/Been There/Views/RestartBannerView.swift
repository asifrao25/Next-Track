//
//  RestartBannerView.swift
//  Next-track
//
//  Toast banner shown when app restarts after being terminated
//

import SwiftUI

struct RestartBannerView: View {
    let timeSinceBackground: TimeInterval
    @Binding var isShowing: Bool

    var body: some View {
        VStack {
            HStack(spacing: 10) {
                Image(systemName: "arrow.clockwise.circle.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.orange)

                Text(message)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)

                Spacer()

                Button {
                    withAnimation(.easeOut(duration: 0.2)) {
                        isShowing = false
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white.opacity(0.6))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(red: 0.15, green: 0.15, blue: 0.2))
                    .shadow(color: .black.opacity(0.3), radius: 10, y: 5)
            )
            .padding(.horizontal, 16)
            .padding(.top, 8)

            Spacer()
        }
        .transition(.move(edge: .top).combined(with: .opacity))
        .onAppear {
            // Auto-dismiss after 4 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                withAnimation(.easeOut(duration: 0.3)) {
                    isShowing = false
                }
            }
        }
    }

    private var message: String {
        let minutes = Int(timeSinceBackground / 60)
        let hours = Int(timeSinceBackground / 3600)

        if hours > 0 {
            return "App restarted after \(hours)h \(minutes % 60)m"
        } else if minutes > 0 {
            return "App restarted after \(minutes) min"
        } else {
            return "App restarted"
        }
    }
}

#Preview {
    ZStack {
        Color.gray.ignoresSafeArea()
        RestartBannerView(timeSinceBackground: 300, isShowing: .constant(true))
    }
}
