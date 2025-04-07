//
//  FunZoneView.swift
//  iblot
//
//  Created by Saumil Anand on 7/4/25.
//

import SwiftUI
import UIKit
import WebKit

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
    @State private var previewHTML: String = ""
    @State private var showPreview: Bool = false
    
    enum EffectType: String, CaseIterable, Identifiable {
        case wave = "Wave"
        case spiral = "Spiral"
        case implode = "Implode"  // Changed from explode to implode
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
        
        // Add effect-specific code
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
    
    func generatePreviewHTML(jsCode: String) -> String {
        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <style>
                body { margin: 0; overflow: hidden; display: flex; justify-content: center; align-items: center; }
                canvas { border: 1px solid #ccc; background: white; }
            </style>
        </head>
        <body>
            <canvas id="canvas" width="250" height="250"></canvas>
            <script>
                const canvas = document.getElementById('canvas');
                const ctx = canvas.getContext('2d');
                
                // Mock Blot toolkit functions
                const bt = {
                    iteratePoints: function(polylines, callback) {
                        return polylines.map(polyline => {
                            const newLine = [];
                            for (let i = 0; i < polyline.length; i++) {
                                const result = callback(polyline[i], i / (polyline.length - 1));
                                if (result !== "BREAK" && result !== "REMOVE") {
                                    newLine.push(result);
                                } else if (result === "BREAK" && newLine.length > 0) {
                                    break;
                                }
                            }
                            return newLine;
                        });
                    },
                    scale: function(polylines, scale, origin = [62.5, 62.5]) {
                        return polylines.map(polyline => {
                            return polyline.map(point => {
                                const dx = point[0] - origin[0];
                                const dy = point[1] - origin[1];
                                return [
                                    origin[0] + dx * (typeof scale === 'number' ? scale : scale[0]),
                                    origin[1] + dy * (typeof scale === 'number' ? scale : scale[1])
                                ];
                            });
                        });
                    },
                    translate: function(polylines, offset) {
                        return polylines.map(polyline => {
                            return polyline.map(point => {
                                return [point[0] + offset[0], point[1] + offset[1]];
                            });
                        });
                    },
                    originate: function(polylines) {
                        // Find center
                        let minX = Infinity, minY = Infinity, maxX = -Infinity, maxY = -Infinity;
                        polylines.forEach(polyline => {
                            polyline.forEach(point => {
                                minX = Math.min(minX, point[0]);
                                minY = Math.min(minY, point[1]);
                                maxX = Math.max(maxX, point[0]);
                                maxY = Math.max(maxY, point[1]);
                            });
                        });
                        
                        const centerX = (minX + maxX) / 2;
                        const centerY = (minY + maxY) / 2;
                        
                        return bt.translate(polylines, [-centerX, -centerY]);
                    },
                    copy: function(polylines) {
                        return JSON.parse(JSON.stringify(polylines));
                    },
                    resample: function(polylines, sampleRate) {
                        // Simple implementation for preview
                        return polylines;
                    },
                    rand: function() {
                        return Math.random();
                    },
                    setRandSeed: function(seed) {
                        // Do nothing for preview
                    }
                };
                
                function setDocDimensions(width, height) {
                    // Scale canvas for preview
                    canvas.width = width * 2;
                    canvas.height = height * 2;
                    ctx.scale(2, 2);
                }
                
                function drawLines(polylines) {
                    ctx.clearRect(0, 0, canvas.width, canvas.height);
                    ctx.lineWidth = 1;
                    ctx.strokeStyle = 'black';
                    
                    polylines.forEach(polyline => {
                        if (polyline.length > 0) {
                            ctx.beginPath();
                            ctx.moveTo(polyline[0][0], polyline[0][1]);
                            for (let i = 1; i < polyline.length; i++) {
                                ctx.lineTo(polyline[i][0], polyline[i][1]);
                            }
                            ctx.stroke();
                        }
                    });
                }
                
                // Execute the user's code
                \(jsCode)
            </script>
        </body>
        </html>
        """
    }
    
    func updatePreview() {
        if !drawingData.lines.isEmpty {
            let jsCode = applyEffect(to: drawingData.lines, effect: selectedEffect, intensity: effectIntensity)
            previewHTML = generatePreviewHTML(jsCode: jsCode)
            transformedCode = jsCode
            showPreview = true
        }
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
                
                // Preview WebView
                if showPreview {
                    WebView(htmlString: previewHTML)
                        .frame(height: 250)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                        .padding(.horizontal)
                }
                
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

// WebView to render HTML preview
struct WebView: UIViewRepresentable {
    let htmlString: String
    
    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.backgroundColor = .clear
        webView.isOpaque = false
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        webView.loadHTMLString(htmlString, baseURL: nil)
    }
}

struct FunZoneView_Previews: PreviewProvider {
    static var previews: some View {
        FunZoneView()
            .environmentObject(DrawingData())
    }
} 