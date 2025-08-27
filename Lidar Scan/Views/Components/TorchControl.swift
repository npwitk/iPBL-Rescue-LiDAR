//
//  TorchControl.swift
//  Rescue Robot Sensor Head
//

import SwiftUI
import AVFoundation

struct TorchControl: View {
    @Binding var level: Float
    @State private var hasTorch = false
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "flashlight.off.fill")
                    .foregroundColor(.white)
                    .font(.caption)
                
                Text("Torch")
                    .font(.caption)
                    .foregroundColor(.white)
                
                Spacer()
                
                Text("\(Int(level * 100))%")
                    .font(.caption.monospacedDigit())
                    .foregroundColor(.white)
            }
            
            if hasTorch {
                Slider(value: Binding(
                    get: { level },
                    set: { newValue in
                        level = newValue
                    }
                ), in: 0...1)
                .accentColor(.yellow)
                .disabled(!hasTorch)
            } else {
                Text("Torch not available")
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
        }
        .padding()
        .background(Color.black.opacity(0.6))
        .cornerRadius(12)
        .onAppear {
            checkTorchAvailability()
        }
    }
    
    private func checkTorchAvailability() {
        guard let device = AVCaptureDevice.default(for: .video) else {
            hasTorch = false
            return
        }
        hasTorch = device.hasTorch
    }
}

#Preview {
    TorchControl(level: .constant(0.5))
        .background(Color.blue)
}