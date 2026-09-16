//
//  CameraView.swift
//  SiLang
//
//  Created by Gian Denggan Benjamin on 14/09/26.
//

import SwiftUI

struct CameraView: View {
    @ObservedObject var cameraManager: CameraManager

    var body: some View {
        ZStack {
            // Live camera feed
            CameraPreview(sessionLayer: cameraManager.getPreviewLayer())
                .ignoresSafeArea()

            // Subtitle overlay at the bottom
            VStack {
                Spacer()
                Text(cameraManager.subtitleText.isEmpty
                     ? "Waiting for sign…"
                     : cameraManager.subtitleText)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal)
                    .padding(.bottom, 30)
            }
        }
        .onAppear { cameraManager.startSession() }
        .onDisappear { cameraManager.stopSession() }
    }
}
