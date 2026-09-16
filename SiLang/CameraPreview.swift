//
//  CameraPreview.swift
//  SiLang
//
//  Created by Gian Denggan Benjamin on 14/09/26.
//

import SwiftUI
import AVFoundation

struct CameraPreview: UIViewRepresentable {
    let sessionLayer: AVCaptureVideoPreviewLayer

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        sessionLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(sessionLayer)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        DispatchQueue.main.async {
            sessionLayer.frame = uiView.bounds
        }
    }
}
