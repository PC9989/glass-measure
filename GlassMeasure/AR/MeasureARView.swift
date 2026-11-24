import RealityKit
import SwiftUI

struct MeasureARRepresentable: UIViewRepresentable {
    @ObservedObject var controller: MeasureController

    func makeUIView(context: Context) -> ARView {
        let view = ARView(frame: .zero)
        view.automaticallyConfigureSession = false
        view.renderOptions = [.disableMotionBlur, .disableDepthOfField, .disablePersonOcclusion]
        controller.attach(view)
        return view
    }

    func updateUIView(_ uiView: ARView, context: Context) {}
}
