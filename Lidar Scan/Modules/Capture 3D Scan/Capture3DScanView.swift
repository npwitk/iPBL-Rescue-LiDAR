//
//  Capture3DScanView.swift
//  Lidar Scan
//
//  Created by Cedan Misquith on 27/04/25.
//

import SwiftUI

struct Capture3DScanView: View {
    @Environment(\.presentationMode) var mode: Binding<PresentationMode>
    @State var submittedExportRequest = false
    @State var submittedName = ""
    @State var pauseSession: Bool = false
    var body: some View {
        NavigationView {
            ZStack(alignment: .bottom) {
                ARWrapperView(submittedExportRequest: $submittedExportRequest,
                              submittedName: $submittedName,
                              pauseSession: $pauseSession)
                .ignoresSafeArea()
                VStack {
                    HStack {
                        Button {
                            self.mode.wrappedValue.dismiss()
                        } label: {
                            Text("Back")
                                .frame(width: 80)
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                        .frame(width: 40, height: 40)
                        Spacer()
                    }.padding(.leading, 40)
                    Spacer()
                    Button {
                        pauseSession = true
                        alertView(title: "Save File",
                                  message: "Enter your file name",
                                  hintText: "file name") { text in
                            submittedName = text
                            submittedExportRequest.toggle()
                            self.mode.wrappedValue.dismiss()
                        } secondaryAction: {
                            print("Cancelled")
                            pauseSession = false
                        }
                    } label: {
                        Text("Export")
                            .frame(width: UIScreen.main.bounds.width-120)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                }
            }
        }
    }
}

#Preview {
    Capture3DScanView()
}
