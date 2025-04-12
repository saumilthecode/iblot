//
//  FunZoneView.swift
//  iblot
//
//  Created by Saumil Anand on 7/4/25.
//

import SwiftUI
import UIKit

// Add AppDelegate reference if it doesn't exist in the project
@objcMembers class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    var rootViewController: UINavigationController?
}

// Add a class to share drawing data between views
class DrawingData: ObservableObject {
    @Published var lines: [[CGPoint]] = []
    @Published var canvasSize: CGSize = CGSize(width: 250, height: 250)
}

struct FunZoneView: View {
    @EnvironmentObject var drawingData: DrawingData
    @State private var selectedEffect: EffectType = .wave
    @State private var effectIntensity: Double = 0.5
    @State private var showingShareSheet = false
    @State private var transformedCode: String = ""
    @State private var transformedLines: [[CGPoint]] = []
    
    // Pan and zoom states
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var mousePosition: CGPoint = .zero
    
    enum EffectType: String, CaseIterable, Identifiable {
        case wave = "Wave"
        case spiral = "Spiral"
        case implode = "Implode"
        case noise = "Noise"
        case jitter = "Jitter"
        
        var id: String { self.rawValue }
    }
    
    func applyEffect(to lines: [[CGPoint]], effect: EffectType, intensity: Double) -> String {
        let scaleX = 125 / drawingData.canvasSize.width
        let scaleY = 125 / drawingData.canvasSize.height
        
        var polyline = "[\n"
        
        for line in lines {
            polyline += "  ["
            for point in line {
                let x = point.x * scaleX
                let y = 125 - (point.y * scaleY)
                polyline += "[\(x), \(y)], "
            }
            polyline = String(polyline.dropLast(2))
            polyline += "],\n"
        }
        
        polyline += "]\n"
        
        var jsCode = """
        const width = 125;
        const height = 125;

        setDocDimensions(width, height);

        const polyline = \(polyline);
        
        // Apply selected effect
        """
        
        // Transform the lines for preview
        transformedLines = transformLinesForPreview(lines: lines, effect: effect, intensity: intensity)
        
        // Add effect-specific code for export
        switch effect {
        case .wave:
            jsCode += """
            
            const transformedPolyline = bt.iteratePoints(polyline, (pt, t) => {
                const [x, y] = pt;
                const waveHeight = \(intensity * 20);
                const frequency = 0.1;
                return [x, y + Math.sin(x * frequency) * waveHeight];
            });
            
            drawLines(transformedPolyline);
            """
        case .spiral:
            jsCode += """
            
            const center = [width/2, height/2];
            const scale = 1 + \(intensity) * 0.5;
            const rotationFactor = \(intensity * 10);
            
            const transformedPolyline = bt.iteratePoints(polyline, (pt, t) => {
                const [x, y] = pt;
                const dx = x - center[0];
                const dy = y - center[1];
                const angle = Math.atan2(dy, dx) + (t * rotationFactor);
                const dist = Math.sqrt(dx*dx + dy*dy) * scale;
                return [
                    center[0] + Math.cos(angle) * dist,
                    center[1] + Math.sin(angle) * dist
                ];
            });
            
            drawLines(transformedPolyline);
            """
        case .implode:
            jsCode += """
            
            const center = [width/2, height/2];
            const implodeFactor = 1 - \(intensity) * 0.8;
            
            const transformedPolyline = bt.copy(polyline);
            bt.originate(transformedPolyline);
            bt.scale(transformedPolyline, implodeFactor);
            bt.translate(transformedPolyline, center);
            
            drawLines(transformedPolyline);
            """
        case .noise:
            jsCode += """
            
            const noiseFactor = \(intensity * 15);
            bt.setRandSeed(Date.now());
            
            const transformedPolyline = bt.iteratePoints(polyline, (pt) => {
                const [x, y] = pt;
                return [
                    x + (bt.rand() - 0.5) * noiseFactor,
                    y + (bt.rand() - 0.5) * noiseFactor
                ];
            });
            
            drawLines(transformedPolyline);
            """
        case .jitter:
            jsCode += """
            
            const jitterAmount = \(intensity * 10);
            bt.setRandSeed(Date.now());
            
            // Resample to add more points
            const transformedPolyline = bt.copy(polyline);
            bt.resample(transformedPolyline, 2);
            
            // Apply jitter to each point
            bt.iteratePoints(transformedPolyline, (pt) => {
                const [x, y] = pt;
                if (bt.rand() > 0.5) {
                    return [
                        x + (bt.rand() - 0.5) * jitterAmount,
                        y + (bt.rand() - 0.5) * jitterAmount
                    ];
                }
                return pt;
            });
            
            drawLines(transformedPolyline);
            """
        }
        
        return jsCode
    }
    
    // Apply transformation to lines natively in Swift for preview
    func transformLinesForPreview(lines: [[CGPoint]], effect: EffectType, intensity: Double) -> [[CGPoint]] {
        guard !lines.isEmpty else { return [] }
        
        let center = CGPoint(x: drawingData.canvasSize.width / 2, y: drawingData.canvasSize.height / 2)
        
        switch effect {
        case .wave:
            return lines.map { line in
                line.map { point in
                    let waveHeight = CGFloat(intensity * 20)
                    let frequency: CGFloat = 0.1
                    return CGPoint(
                        x: point.x,
                        y: point.y + sin(point.x * frequency) * waveHeight
                    )
                }
            }
            
        case .spiral:
            return lines.map { line in
                line.enumerated().map { (index, point) in
                    let t = CGFloat(index) / max(CGFloat(line.count - 1), 1)
                    let scale = 1 + CGFloat(intensity) * 0.5
                    let rotationFactor = CGFloat(intensity * 10)
                    
                    let dx = point.x - center.x
                    let dy = point.y - center.y
                    let angle = atan2(dy, dx) + (t * rotationFactor)
                    let dist = sqrt(dx*dx + dy*dy) * scale
                    
                    return CGPoint(
                        x: center.x + cos(angle) * dist,
                        y: center.y + sin(angle) * dist
                    )
                }
            }
            
        case .implode:
            let implodeFactor = 1 - CGFloat(intensity) * 0.8
            var transformedLines = lines
            
            // Find the bounding box
            var minX: CGFloat = .infinity
            var minY: CGFloat = .infinity
            var maxX: CGFloat = -.infinity
            var maxY: CGFloat = -.infinity
            
            for line in lines {
                for point in line {
                    minX = min(minX, point.x)
                    minY = min(minY, point.y)
                    maxX = max(maxX, point.x)
                    maxY = max(maxY, point.y)
                }
            }
            
            let centerX = (minX + maxX) / 2
            let centerY = (minY + maxY) / 2
            
            return transformedLines.map { line in
                line.map { point in
                    let dx = point.x - centerX
                    let dy = point.y - centerY
                    return CGPoint(
                        x: center.x + dx * implodeFactor,
                        y: center.y + dy * implodeFactor
                    )
                }
            }
            
        case .noise:
            let noiseFactor = CGFloat(intensity * 15)
            
            return lines.map { line in
                line.map { point in
                    CGPoint(
                        x: point.x + (CGFloat.random(in: -0.5...0.5) * noiseFactor),
                        y: point.y + (CGFloat.random(in: -0.5...0.5) * noiseFactor)
                    )
                }
            }
            
        case .jitter:
            let jitterAmount = CGFloat(intensity * 10)
            
            return lines.map { line in
                line.map { point in
                    if Bool.random() {
                        return CGPoint(
                            x: point.x + (CGFloat.random(in: -0.5...0.5) * jitterAmount),
                            y: point.y + (CGFloat.random(in: -0.5...0.5) * jitterAmount)
                        )
                    }
                    return point
                }
            }
        }
    }
    
    func updatePreview() {
        if !drawingData.lines.isEmpty {
            transformedCode = applyEffect(to: drawingData.lines, effect: selectedEffect, intensity: effectIntensity)
        }
    }
    
    func centerView() {
        scale = 1.0
        offset = .zero
    }
    
    var body: some View {
        VStack(spacing: 20) {
            if drawingData.lines.isEmpty {
                Text("Draw something in the Draw tab first!")
                    .font(.headline)
                    .padding()
            } else {
                Text("Fun Zone - Transform Your Drawing")
                    .font(.headline)
                
                // Native Preview Canvas
                ZStack {
                    GeometryReader { geometry in
                        let size = min(geometry.size.width, 250)
                        
                        ZStack {
                            // Canvas for drawing
                            Canvas { context, canvasSize in
                                // Draw document boundaries
                                let docRect = CGRect(x: 0, y: 0, width: canvasSize.width, height: canvasSize.height)
                                context.stroke(Path(docRect), with: .color(.blue.opacity(0.5)))
                                
                                // Apply transformations for pan and zoom
                                context.translateBy(x: offset.width + canvasSize.width/2, y: offset.height + canvasSize.height/2)
                                context.scaleBy(x: scale, y: scale)
                                context.translateBy(x: -canvasSize.width/2, y: -canvasSize.height/2)
                                
                                // Draw the transformed lines
                                for line in transformedLines {
                                    let path = Path { path in
                                        guard let firstPoint = line.first else { return }
                                        
                                        // Scale the points to fit the canvas
                                        let scaleX = canvasSize.width / drawingData.canvasSize.width
                                        let scaleY = canvasSize.height / drawingData.canvasSize.height
                                        
                                        path.move(to: CGPoint(x: firstPoint.x * scaleX, y: firstPoint.y * scaleY))
                                        for point in line.dropFirst() {
                                            path.addLine(to: CGPoint(x: point.x * scaleX, y: point.y * scaleY))
                                        }
                                    }
                                    context.stroke(path, with: .color(.black), lineWidth: 2)
                                }
                            }
                            .frame(width: size, height: size)
                            .background(Color.white)
                            .border(Color.gray, width: 1)
                            .cornerRadius(8)
                            .clipped()
                            .gesture(
                                MagnificationGesture()
                                    .onChanged { value in
                                        let delta = value / lastScale
                                        lastScale = value
                                        scale *= delta
                                    }
                                    .onEnded { _ in
                                        lastScale = 1.0
                                    }
                            )
                            .gesture(
                                DragGesture()
                                    .onChanged { value in
                                        offset = CGSize(
                                            width: lastOffset.width + value.translation.width,
                                            height: lastOffset.height + value.translation.height
                                        )
                                    }
                                    .onEnded { _ in
                                        lastOffset = offset
                                    }
                            )
                            
                            // Mouse position display
                            Text(String(format: "%.1f, %.1f", mousePosition.x, mousePosition.y))
                                .font(.caption)
                                .padding(4)
                                .background(Color.black.opacity(0.6))
                                .foregroundColor(.white)
                                .cornerRadius(4)
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                                .padding(8)
                            
                            // Center view button
                            Button(action: centerView) {
                                Image(systemName: "arrow.up.left.and.down.right.magnifyingglass")
                                    .foregroundColor(.white)
                                    .padding(8)
                                    .background(Circle().fill(Color.blue.opacity(0.8)))
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                            .padding(8)
                        }
                        .frame(width: size, height: size)
                        .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                    }
                    .frame(height: 250)
                }
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            mousePosition = value.location
                        }
                )
                .padding(.horizontal)
                
                GroupBox {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Effect")
                            .font(.subheadline)
                        
                        Picker("Effect Type", selection: $selectedEffect) {
                            ForEach(EffectType.allCases) { effect in
                                Text(effect.rawValue).tag(effect)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .onChange(of: selectedEffect) { _ in
                            updatePreview()
                        }
                        
                        Text("Intensity: \(Int(effectIntensity * 100))%")
                            .font(.subheadline)
                        
                        Slider(value: $effectIntensity, in: 0.1...1.0, step: 0.1)
                            .padding(.bottom)
                            .onChange(of: effectIntensity) { _ in
                                updatePreview()
                            }
                        
                        HStack {
                            Button("Preview") {
                                updatePreview()
                            }
                            .buttonStyle(.bordered)
                            .frame(maxWidth: .infinity)
                            
                            Button("Share") {
                                showingShareSheet = true
                            }
                            .buttonStyle(.borderedProminent)
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .padding()
                }
                .padding(.horizontal)
                
                Text("Effects will be applied to your drawing and can be shared through Airdrop.")
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
        }
        .padding()
        .onAppear {
            updatePreview()
        }
        .sheet(isPresented: $showingShareSheet) {
            ShareSheet(activityItems: [transformedCode])
        }
    }
}

struct FunZoneView_Previews: PreviewProvider {
    static var previews: some View {
        FunZoneView()
            .environmentObject(DrawingData())
    }
} 