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

    @Published var subtitleText: String = ""

    private var model: BisindoTranscriber?
    private let queueSize = 90
    private var queue = [MLMultiArray]()
    private var frameCounter = 0
    private var queueSamplingCounter = 0
    private let queueSamplingCount = 5
    private let confidenceThreshold: Double = 0.6

    override init() {
        super.init()
        do {
            model = try BisindoTranscriber(configuration: MLModelConfiguration())
        } catch {
            print("Failed to load BisindoTranscriber: \(error)")
        }
    }


    @Published var cameraPosition: AVCaptureDevice.Position = .back

    func startSession() {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: cameraPosition),
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

    func flipCamera() {
        session.beginConfiguration()

        for input in session.inputs {
            session.removeInput(input)
        }

        cameraPosition = (cameraPosition == .back) ? .front : .back

        if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: cameraPosition),
           let input = try? AVCaptureDeviceInput(device: device),
           session.canAddInput(input) {
            session.addInput(input)
        }

        session.commitConfiguration()

        queue.removeAll()
        queueSamplingCounter = 0
    }

    func getPreviewLayer() -> AVCaptureVideoPreviewLayer {
        if let layer = previewLayer { return layer }
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        previewLayer = layer
        return layer
    }


    private func getHands(from pixelBuffer: CVPixelBuffer) -> [MLMultiArray] {
        let request = VNDetectHumanHandPoseRequest()
        request.maximumHandCount = 2

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        try? handler.perform([request])

        guard let results = request.results else { return [] }

        var hands = [MLMultiArray]()
        for observation in results {
            // Use keypointsMultiArray — gives the exact format the model expects
            if let keypoints = try? observation.keypointsMultiArray() {
                hands.append(keypoints)
            }
        }
        return hands
    }
}


extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }


        let hands = getHands(from: pixelBuffer)
        guard !hands.isEmpty else { return }

        let pose = hands[0]

        queue.append(pose)
        queue = Array(queue.suffix(queueSize))
        queueSamplingCounter += 1

        if queue.count == queueSize && queueSamplingCounter % queueSamplingCount == 0 {
            let poses = MLMultiArray(concatenating: queue, axis: 0, dataType: .float32)

            do {
                let prediction = try model?.prediction(poses: poses)
                guard let label = prediction?.label,
                      let confidence = prediction?.labelProbabilities[label] else { return }

                if confidence > confidenceThreshold {
                    DispatchQueue.main.async {
                        self.subtitleText = label
                    }
                }
            } catch {
                print("Prediction failed: \(error)")
            }
        }
    }
}
