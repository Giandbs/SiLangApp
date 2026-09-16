import SwiftUI

struct ContentView: View {
    @StateObject private var cameraManager = CameraManager()

    var body: some View {
        CameraView(cameraManager: cameraManager)
    }
}
