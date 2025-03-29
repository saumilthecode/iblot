//
//  ContentView.swift
//  iblot
//
//  Created by Saumil Anand on 22/12/24.
//

import SwiftUI

struct ContentView: View {
    @State private var lines: [[CGPoint]] = []
    @State private var currentLine: [CGPoint] = []
    @State private var canvasSize: CGSize = CGSize(width: 250, height: 250)
    @State private var isErasing: Bool = false
    
    var body: some View {
        VStack {
            GeometryReader { geometry in
                Canvas { context, size in
                    DispatchQueue.main.async {
                        canvasSize = size
                    }
                    
                    for line in lines {
                        drawLine(context: context, line: line, size: size)
                    }
                    
                    drawLine(context: context, line: currentLine, size: size)
                }
                .gesture(DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let location = value.location
                        if isErasing {
                            // Remove lines that are close to the touch point
                            lines = lines.map { line in
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
                            lines.append(currentLine)
                            currentLine = []
                        }
                    }
                )
                .background(Color.white)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .aspectRatio(1, contentMode: .fit)
                .border(Color.black, width: 1)
            }
            
            HStack {
                Button("Clear") {
                    lines.removeAll()
                }
                .padding()
                
                Button(isErasing ? "Draw" : "Erase") {
                    isErasing.toggle()
                }
                .padding()
                .foregroundColor(isErasing ? .red : .blue)
                
                ShareLink(item: generateJavaScriptCode(from: lines, canvasSize: canvasSize)) {
                    Text("AIRDROP RAAAH")
                }
                .padding()
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
                // Flip Y coordinate by subtracting from canvas height
                polyline += "[\(point.x * scaleX), \(125 - (point.y * scaleY))], "
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

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
