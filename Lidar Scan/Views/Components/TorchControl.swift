//
//  TorchControl.swift
//  Rescue Robot Sensor Head
//

import SwiftUI
import AVFoundation

struct TorchControl: View {
    @Binding var isOn: Bool
    @State private var hasTorch = false
    
    var body: some View {
        Button(action: {
            if hasTorch {
                isOn.toggle()
            }
        }) {
            HStack(spacing: 8) {
                Image(systemName: isOn ? "flashlight.on.fill" : "flashlight.off.fill")
                    .font(.caption)
                    .foregroundColor(isOn ? .yellow : .white)
                
                Text("Torch")
                    .font(.caption.bold())
                    .foregroundColor(.white)
                
                Text(isOn ? "ON" : "OFF")
                    .font(.caption2)
                    .foregroundColor(isOn ? .yellow : .gray)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.black.opacity(0.6))
            .cornerRadius(20)
        }
        .disabled(!hasTorch)
        .opacity(hasTorch ? 1.0 : 0.5)
        .onAppear {
            checkTorchAvailability()
        }
    }
    
    private func checkTorchAvailability() {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            hasTorch = false
            return
        }
        hasTorch = device.hasTorch
    }
}

#Preview {
    TorchControl(isOn: .constant(false))
        .background(Color.blue)
}