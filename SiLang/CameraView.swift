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
            CameraPreview(sessionLayer: cameraManager.getPreviewLayer())
                .ignoresSafeArea()

            VStack {
                HStack {
                    Spacer()
                    Button {
                        cameraManager.flipCamera()
                    } label: {
                        Image(systemName: "camera.rotate.fill")
                            .font(.title2)
                            .foregroundStyle(.white)
                            .padding(12)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    .padding(.trailing, 16)
                    .padding(.top, 12)
                }

                Spacer()

                Text(cameraManager.subtitleText.isEmpty
                     ? " "
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
