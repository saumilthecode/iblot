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
                        currentLine.append(value.location)
                    }
                    .onEnded { _ in
                        lines.append(currentLine)
                        currentLine = []
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
                
                ShareLink(item: generateJavaScriptCode(from: lines, canvasSize: canvasSize)) {
                    Text("Share JavaScript Code")
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
        let scaleX = 115 / canvasSize.width
        let scaleY = 115 / canvasSize.height
        
        var polyline = "[\n"
        
        for line in lines {
            polyline += "  ["
            for point in line {
                polyline += "[\(point.x * scaleX), \(point.y * scaleY)], "
            }
            polyline = String(polyline.dropLast(2)) // Remove the last comma and space
            polyline += "],\n"
        }
        
        polyline += "]\n"
        
        let jsCode = """
        const width = 115;
        const height = 115;

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
