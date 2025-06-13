//
//  ContentView.swift
//  iblot
//
//  Created by Saumil Anand on 22/12/24.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var drawingData = DrawingData()
    
    var body: some View {
        TabView {
            DrawingView()
                .tabItem {
                    Label("Draw", systemImage: "pencil")
                }
            
            FunZoneView()
                .tabItem {
                    Label("Fun Zone", systemImage: "star")
                }
        }
        .environmentObject(drawingData)
    }
}

struct DrawingView: View {
    @EnvironmentObject var drawingData: DrawingData
    @State private var currentLine: [CGPoint] = []
    @State private var isErasing: Bool = false
    @State private var showingUploadConfirmation = false
    @State private var showingUploadSuccess = false
    @State private var showingShareSheet = false
    @State private var showingClearConfirmation = false
    
    // Add function to render and upload image
    func renderAndUploadImage(size: CGSize) {
        let renderer = ImageRenderer(content:
            Canvas { context, _ in
                for line in drawingData.lines {
                    drawLine(context: context, line: line, size: size)
                }
            }
            .frame(width: size.width, height: size.height)
        )
        
        // Configure renderer for transparency
        renderer.isOpaque = false
        
        guard let uiImage = renderer.uiImage else { return }
        guard let pngData = uiImage.pngData() else { return }
        
        // Commenting out the upload to server part
        // let url = URL(string: "https://dino.bbsshack.club/upload")!
        // var request = URLRequest(url: url)
        // request.httpMethod = "POST"
        
        // let boundary = "Boundary-\(UUID().uuidString)"
        // request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        // var body = Data()
        // // Generate unique filename using timestamp and random string
        // let timestamp = Int(Date().timeIntervalSince1970)
        // let randomString = UUID().uuidString.prefix(8)
        // let filename = "drawing_\(timestamp)_\(randomString).png"
        // let fieldName = "file"
        
        // body.append("--\(boundary)\r\n".data(using: .utf8)!)
        // body.append("Content-Disposition: form-data; name=\"\(fieldName)\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        // body.append("Content-Type: image/png\r\n\r\n".data(using: .utf8)!)
        // body.append(pngData)
        // body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        
        // request.httpBody = body

        // URLSession.shared.dataTask(with: request) { data, response, error in
        //     if let error = error {
        //         print("Upload error: \(error)")
        //         return
        //     }
        //     if let httpResponse = response as? HTTPURLResponse {
        //         print("Upload status: \(httpResponse.statusCode)")
        //         if httpResponse.statusCode == 200 {
        //             DispatchQueue.main.async {
        //                 showingUploadSuccess = true
        //             }
        //         }
        //     }
        // }.resume()
    }


    var body: some View {
        VStack(spacing: 20) {
            GeometryReader { geometry in
                Canvas { context, size in
                    DispatchQueue.main.async {
                        drawingData.canvasSize = size
                    }
                    
                    for line in drawingData.lines {
                        drawLine(context: context, line: line, size: size)
                    }
                    
                    drawLine(context: context, line: currentLine, size: size)
                }
                .gesture(
                    SimultaneousGesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                let location = value.location
                                if isErasing {
                                    // Remove lines that are close to the touch point
                                    drawingData.lines = drawingData.lines.map { line in
                                        line.filter { point in
                                            let distance = sqrt(pow(point.x - location.x, 2) + pow(point.y - location.y, 2))
                                            return distance > 20 // Eraser radius
                                        }
                                    }.filter { !$0.isEmpty }
                                } else {
                                    currentLine.append(location)
                                }
                            }
                            .onEnded { _ in
                                if !isErasing {
                                    drawingData.lines.append(currentLine)
                                    currentLine = []
                                }
                            },
                        TapGesture(count: 1)
                            .onEnded { _ in
                                // This gesture helps prevent multi-touch issues
                            }
                    )
                )
                .background(Color.white)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .aspectRatio(1, contentMode: .fit)
                .border(Color.black, width: 1)
            }
            
            // Drawing controls directly below canvas
            HStack {
                Button("Clear") {
                    showingClearConfirmation = true
                }
                .padding()
                .foregroundColor(.red)
                .alert("Confirm Clear", isPresented: $showingClearConfirmation) {
                    Button("Cancel", role: .cancel) { }
                    Button("Clear", role: .destructive) {
                        drawingData.lines.removeAll()
                    }
                } message: {
                    Text("Are you sure you want to clear the drawing?")
                }
                
                Button("Undo") {
                    if !drawingData.lines.isEmpty {
                        drawingData.lines.removeLast()
                    }
                }
                .padding()
                .foregroundColor(.blue)
                .disabled(drawingData.lines.isEmpty)
                
                Button(isErasing ? "Draw" : "Erase") {
                    isErasing.toggle()
                }
                .padding()
                .foregroundColor(isErasing ? .red : .blue)
            }
            
            Spacer()
            
            // Upload and Airdrop buttons at bottom
            HStack {
                // Button("Upload") {
                //     showingUploadConfirmation = true
                // }
                // .padding()
                // .alert("Confirm Upload", isPresented: $showingUploadConfirmation) {
                //     Button("Cancel", role: .cancel) { }
                //     Button("Upload") {
                //         renderAndUploadImage(size: drawingData.canvasSize)
                //     }
                // } message: {
                //     Text("Are you sure you want to upload this drawing?")
                // }
                // .alert("Success", isPresented: $showingUploadSuccess) {
                //     Button("OK", role: .cancel) { }
                // } message: {
                //     Text("Your drawing was successfully uploaded!")
                // }
                
                Button("Airdrop!") {
                    showingShareSheet = true
                }
                .padding()
                .sheet(isPresented: $showingShareSheet) {
                    ShareSheet(activityItems: [generateJavaScriptCode(from: drawingData.lines, canvasSize: drawingData.canvasSize)])
                }
            }
        }
        .padding()
    }
    
    func drawLine(context: GraphicsContext, line: [CGPoint], size: CGSize) {
        let path = Path { path in
            guard let firstPoint = line.first else { return }
            path.move(to: firstPoint)
            for point in line.dropFirst() {
                path.addLine(to: point)
            }
        }
        context.stroke(path, with: .color(.black), lineWidth: 2)
    }
    
    func generateJavaScriptCode(from lines: [[CGPoint]], canvasSize: CGSize) -> String {
        let scaleX = 125 / canvasSize.width
        let scaleY = 125 / canvasSize.height
        
        var polyline = "[\n"
        
        for line in lines {
            polyline += "  ["
            for point in line {
                // Scale and constrain points to stay within 0-125 range
                let x = min(max(point.x * scaleX, 0), 125)
                let y = min(max(125 - (point.y * scaleY), 0), 125)
                polyline += "[\(x), \(y)], "
            }
            polyline = String(polyline.dropLast(2)) // Remove the last comma and space
            polyline += "],\n"
        }
        
        polyline += "]\n"
        
        let jsCode = """
        const width = 125;
        const height = 125;

        setDocDimensions(width, height);

        const polyline = \(polyline);

        drawLines(polyline);
        """
        
        return jsCode
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
