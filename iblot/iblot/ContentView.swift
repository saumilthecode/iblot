//
//  ContentView.swift
//  iblot
//
//  Created by Saumil Anand on 22/12/24.
//

import SwiftUI
import AVFoundation
import Vision

struct ContentView: View {
    @StateObject private var drawingData = DrawingData()
    
    var body: some View {
        TabView {
            DrawingView()
                .tabItem {
                    Label("Draw", systemImage: "pencil")
                }
            
            CameraView()
                .tabItem {
                    Label("Camera", systemImage: "camera")
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

struct CameraView: View {
    @EnvironmentObject var drawingData: DrawingData
    @StateObject private var camera = CameraModel()
    @State private var showingImagePicker = false
    @State private var showingProcessingAlert = false
    @State private var previewLines: [[CGPoint]] = []
    @State private var contrastValue: Double = 2.0
    @State private var showingPermissionAlert = false
    @State private var isFocusing = false
    
    var body: some View {
        VStack(spacing: 0) {
            if let image = camera.image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 300)
                
                Button("Convert to Drawing") {
                    showingProcessingAlert = true
                    processImage(image)
                }
                .padding()
                .alert("Processing Image", isPresented: $showingProcessingAlert) {
                    Button("OK", role: .cancel) { }
                } message: {
                    Text("Converting image to drawing...")
                }
            } else {
                GeometryReader { geometry in
                    ZStack {
                        CameraPreviewView(session: camera.session)
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .clipped()
                            .ignoresSafeArea()
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.white.opacity(0.5), lineWidth: 2)
                            )
                            .gesture(
                                TapGesture()
                                    .onEnded { _ in
                                        isFocusing = true
                                        camera.focusCamera()
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                            isFocusing = false
                                        }
                                    }
                            )
                        
                        if isFocusing {
                            Circle()
                                .stroke(Color.yellow, lineWidth: 2)
                                .frame(width: 70, height: 70)
                                .transition(.opacity)
                        }
                        
                        Canvas { context, size in
                            for line in previewLines {
                                drawLine(context: context, line: line, size: size)
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                VStack(spacing: 16) {
                    HStack {
                        Image(systemName: "circle.lefthalf.filled")
                            .foregroundColor(.gray)
                        Slider(value: $contrastValue, in: 1.0...5.0) { _ in
                            camera.updateContrast(contrastValue)
                        }
                        Image(systemName: "circle.righthalf.filled")
                            .foregroundColor(.gray)
                    }
                    .padding(.horizontal)
                    
                    HStack {
                        Text("Contrast: \(String(format: "%.1f", contrastValue))")
                            .foregroundColor(.gray)
                            .font(.caption)
                    }
                    
                    Button(action: {
                        camera.takePicture()
                    }) {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 70, height: 70)
                            .overlay(
                                Circle()
                                    .stroke(Color.black, lineWidth: 2)
                                    .frame(width: 60, height: 60)
                            )
                    }
                    .padding(.bottom)
                }
            }
        }
        .onAppear {
            camera.checkPermissions()
            camera.onFrameProcessed = { lines in
                previewLines = lines
            }
            camera.updateContrast(contrastValue)
        }
        .alert("Camera Access Required", isPresented: $showingPermissionAlert) {
            Button("Settings", role: .none) {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Please allow camera access in Settings to use this feature.")
        }
    }
    
    func drawLine(context: GraphicsContext, line: [CGPoint], size: CGSize) {
        let path = Path { path in
            guard let firstPoint = line.first else { return }
            // Scale normalized points to canvas size
            let first = CGPoint(x: firstPoint.x * size.width, y: firstPoint.y * size.height)
            path.move(to: first)
            for point in line.dropFirst() {
                let scaled = CGPoint(x: point.x * size.width, y: point.y * size.height)
                path.addLine(to: scaled)
            }
        }
        context.stroke(path, with: .color(.red), lineWidth: 2)
    }
    
    func processImage(_ image: UIImage) {
        guard let cgImage = image.cgImage else { return }
        
        let request = VNDetectContoursRequest()
        request.contrastAdjustment = Float(contrastValue)
        request.detectsDarkOnLight = true
        request.maximumImageDimension = 512
        request.contrastPivot = 0.2
        
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        
        do {
            try handler.perform([request])
            if let contours = request.results?.first?.topLevelContours {
                var newLines: [[CGPoint]] = []
                
                for contour in contours {
                    var points: [CGPoint] = []
                    let path = contour.normalizedPath
                    
                    path.applyWithBlock { element in
                        let pathPoints = element.pointee.points
                        switch element.pointee.type {
                        case .moveToPoint:
                            points.append(CGPoint(x: pathPoints[0].x, y: pathPoints[0].y)) // Store normalized
                        case .addLineToPoint:
                            points.append(CGPoint(x: pathPoints[0].x, y: pathPoints[0].y)) // Store normalized
                        default:
                            break
                        }
                    }
                    
                    if !points.isEmpty {
                        newLines.append(points)
                    }
                }
                
                DispatchQueue.main.async {
                    drawingData.lines = newLines
                    showingProcessingAlert = false
                }
            }
        } catch {
            print("Failed to process image: \(error)")
            showingProcessingAlert = false
        }
    }
}

struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession?
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero) // Use .zero to let SwiftUI size it
        let previewLayer = AVCaptureVideoPreviewLayer(session: session ?? AVCaptureSession())
        previewLayer.frame = view.bounds
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.connection?.videoOrientation = .portrait
        previewLayer.connection?.isVideoMirrored = false
        previewLayer.setAffineTransform(CGAffineTransform(scaleX: 1, y: -1)) // Vertical flip
        view.layer.addSublayer(previewLayer)
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        if let previewLayer = uiView.layer.sublayers?.first as? AVCaptureVideoPreviewLayer {
            previewLayer.frame = uiView.bounds
            previewLayer.connection?.videoOrientation = .portrait
            previewLayer.connection?.isVideoMirrored = false
            previewLayer.setAffineTransform(CGAffineTransform(scaleX: 1, y: -1)) // Vertical flip
        }
    }
}

class CameraModel: NSObject, ObservableObject, AVCapturePhotoCaptureDelegate, AVCaptureVideoDataOutputSampleBufferDelegate {
    @Published var image: UIImage?
    var session: AVCaptureSession?
    private var output = AVCapturePhotoOutput()
    private var videoOutput = AVCaptureVideoDataOutput()
    var onFrameProcessed: ([[CGPoint]]) -> Void = { _ in }
    private var lastProcessedTime: TimeInterval = 0
    private let processingInterval: TimeInterval = 0.1
    private var currentContrast: Float = 2.0
    private var device: AVCaptureDevice?
    
    func updateContrast(_ value: Double) {
        currentContrast = Float(value)
    }
    
    func checkPermissions() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            setupCamera()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                if granted {
                    DispatchQueue.main.async {
                        self?.setupCamera()
                    }
                }
            }
        case .denied, .restricted:
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: NSNotification.Name("ShowCameraPermissionAlert"), object: nil)
            }
        @unknown default:
            break
        }
    }
    
    func focusCamera() {
        guard let device = device else { return }
        
        do {
            try device.lockForConfiguration()
            if device.isFocusPointOfInterestSupported {
                device.focusPointOfInterest = CGPoint(x: 0.5, y: 0.5)
                device.focusMode = .autoFocus
            }
            device.unlockForConfiguration()
        } catch {
            print("Error focusing camera: \(error)")
        }
    }
    
    private func setupCamera() {
        let session = AVCaptureSession()
        self.session = session
        
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device) else { return }
        
        self.device = device
        
        session.beginConfiguration()
        session.addInput(input)
        session.addOutput(output)
        
        // Setup video output for real-time processing
        videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
        session.addOutput(videoOutput)
        
        // Set video orientation
        if let connection = videoOutput.connection(with: .video) {
            connection.videoOrientation = .portrait
            connection.isVideoMirrored = false
            connection.videoOrientation = .portrait
        }
        
        session.commitConfiguration()
        
        DispatchQueue.global(qos: .background).async {
            session.startRunning()
        }
    }
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        let currentTime = CACurrentMediaTime()
        guard currentTime - lastProcessedTime >= processingInterval else { return }
        lastProcessedTime = currentTime
        
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        let request = VNDetectContoursRequest()
        request.contrastAdjustment = currentContrast
        request.detectsDarkOnLight = true
        request.maximumImageDimension = 512
        request.contrastPivot = 0.2
        
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        
        do {
            try handler.perform([request])
            if let contours = request.results?.first?.topLevelContours {
                var newLines: [[CGPoint]] = []
                
                for contour in contours {
                    var points: [CGPoint] = []
                    let path = contour.normalizedPath
                    
                    path.applyWithBlock { element in
                        let pathPoints = element.pointee.points
                        switch element.pointee.type {
                        case .moveToPoint:
                            points.append(CGPoint(x: pathPoints[0].x, y: pathPoints[0].y)) // Store normalized
                        case .addLineToPoint:
                            points.append(CGPoint(x: pathPoints[0].x, y: pathPoints[0].y)) // Store normalized
                        default:
                            break
                        }
                    }
                    
                    if !points.isEmpty {
                        newLines.append(points)
                    }
                }
                
                DispatchQueue.main.async {
                    self.onFrameProcessed(newLines)
                }
            }
        } catch {
            print("Failed to process frame: \(error)")
        }
    }
    
    func takePicture() {
        let settings = AVCapturePhotoSettings()
        output.capturePhoto(with: settings, delegate: self)
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let imageData = photo.fileDataRepresentation(),
           let image = UIImage(data: imageData) {
            DispatchQueue.main.async {
                self.image = image
            }
        }
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
