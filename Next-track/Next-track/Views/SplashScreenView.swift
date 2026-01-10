//
//  SplashScreenView.swift
//  Next-track
//
//  Video splash screen - plays full-screen video on app launch
//

import SwiftUI
import UIKit
import AVKit

struct SplashScreenView: View {
    @State private var player: AVPlayer?

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background color
                Color.black
                    .ignoresSafeArea()

                // Video player - fills entire screen
                if let player = player {
                    PlayerContainerView(player: player)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .ignoresSafeArea()
                }
            }
        }
        .ignoresSafeArea()
        .onAppear {
            setupPlayer()
        }
        .onDisappear {
            player?.pause()
            player = nil
        }
    }

    private func setupPlayer() {
        guard let videoURL = Bundle.main.url(forResource: "Video_Duration_and_Animation_Adjusted", withExtension: "mp4") else {
            print("[SplashScreen] ❌ Could not find video in bundle")
            return
        }

        print("[SplashScreen] ✅ Found video at: \(videoURL)")

        let playerItem = AVPlayerItem(url: videoURL)
        let newPlayer = AVPlayer(playerItem: playerItem)
        newPlayer.isMuted = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            self.player = newPlayer
            self.player?.play()
            print("[SplashScreen] ▶️ Started playing video")
        }
    }
}

// MARK: - UIKit Video Player Container

struct PlayerContainerView: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> UIView {
        let container = UIView()
        container.backgroundColor = .black

        let playerLayer = AVPlayerLayer(player: player)
        playerLayer.videoGravity = .resizeAspectFill // Fill entire screen
        playerLayer.frame = container.bounds
        container.layer.addSublayer(playerLayer)

        // Store reference for updates
        context.coordinator.playerLayer = playerLayer

        return container
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        // Update frame when size changes
        DispatchQueue.main.async {
            context.coordinator.playerLayer?.frame = uiView.bounds
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator {
        var playerLayer: AVPlayerLayer?
    }
}

// MARK: - Preview

#if DEBUG
struct SplashScreenView_Previews: PreviewProvider {
    static var previews: some View {
        SplashScreenView()
    }
}
#endif
