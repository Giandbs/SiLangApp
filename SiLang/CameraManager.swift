//
//  CameraManager.swift
//  SiLang
//
//  Created by Gian Denggan Benjamin on 14/09/26.
//

import AVFoundation
import UIKit
import Combine
import CoreML
import Vision

class CameraManager: NSObject, ObservableObject {
    private let session = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private var previewLayer: AVCaptureVideoPreviewLayer?

    /// The latest subtitle string from sign detection.
    @Published var subtitleText: String = ""

    // Model expects [150, 3, 21] — 150 frames of 21 hand landmarks with (x, y, confidence)
    private let frameCount = 150
    private let jointCount = 21
    private var poseWindow: [[SIMD3<Float>]] = []  // each entry is 21 joints

    private var model: BisindoTranscriber?

    override init() {
        super.init()
        do {
            model = try BisindoTranscriber(configuration: MLModelConfiguration())
        } catch {
            print("Failed to load BisindoTranscriber: \(error)")
        }
    }

    // MARK: - Session

    func startSession() {
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input),
              session.canAddOutput(videoOutput) else { return }

        session.beginConfiguration()
        session.addInput(input)
        videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
        session.addOutput(videoOutput)
        session.commitConfiguration()

        DispatchQueue.global(qos: .userInitiated).async {
            self.session.startRunning()
        }
    }

    func stopSession() {
        session.stopRunning()
    }

    func getPreviewLayer() -> AVCaptureVideoPreviewLayer {
        if let layer = previewLayer { return layer }
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        previewLayer = layer
        return layer
    }

    // MARK: - Prediction

    private func predict() {
        guard let model = model else { return }

        // Build MLMultiArray with shape [240, 3, 21]
        guard let multiArray = try? MLMultiArray(shape: [150, 3, 21], dataType: .float32) else { return }

        for (frameIdx, joints) in poseWindow.enumerated() {
            for (jointIdx, joint) in joints.enumerated() {
                multiArray[[frameIdx, 0, jointIdx] as [NSNumber]] = NSNumber(value: joint.x)
                multiArray[[frameIdx, 1, jointIdx] as [NSNumber]] = NSNumber(value: joint.y)
                multiArray[[frameIdx, 2, jointIdx] as [NSNumber]] = NSNumber(value: joint.z)
            }
        }

        do {
            let input = BisindoTranscriberInput(poses: multiArray)
            let output = try model.prediction(input: input)
            let label = output.label

            DispatchQueue.main.async {
                if !label.isEmpty {
                    self.subtitleText = label
                }
            }
        } catch {
            print("Prediction failed: \(error)")
        }
    }
}

// MARK: - Process each frame: detect hand pose → accumulate → predict

extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let request = VNDetectHumanHandPoseRequest()
        request.maximumHandCount = 1

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        try? handler.perform([request])

        guard let observation = request.results?.first else {
            // No hand detected — add a zero frame so timing stays consistent
            poseWindow.append(Array(repeating: SIMD3<Float>(0, 0, 0), count: jointCount))
            if poseWindow.count > frameCount { poseWindow.removeFirst() }
            return
        }

        // Extract 21 hand joint positions
        var joints: [SIMD3<Float>] = []
        let allJoints: [VNHumanHandPoseObservation.JointName] = [
            .wrist,
            .thumbCMC, .thumbMP, .thumbIP, .thumbTip,
            .indexMCP, .indexPIP, .indexDIP, .indexTip,
            .middleMCP, .middlePIP, .middleDIP, .middleTip,
            .ringMCP, .ringPIP, .ringDIP, .ringTip,
            .littleMCP, .littlePIP, .littleDIP, .littleTip
        ]

        for joint in allJoints {
            if let point = try? observation.recognizedPoint(joint) {
                joints.append(SIMD3<Float>(Float(point.x), Float(point.y), Float(point.confidence)))
            } else {
                joints.append(SIMD3<Float>(0, 0, 0))
            }
        }

        poseWindow.append(joints)
        if poseWindow.count > frameCount { poseWindow.removeFirst() }

        // Run prediction once we have enough frames
        if poseWindow.count == frameCount {
            predict()
        }
    }
}
