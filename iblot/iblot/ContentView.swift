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
                Button("Export SVG") {
                    let svg = generateSVG(from: lines, canvasSize: canvasSize)
                    saveSVG(svg)
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
    
    func generateSVG(from lines: [[CGPoint]], canvasSize: CGSize) -> String {
        let scaleX = 250 / canvasSize.width
        let scaleY = 250 / canvasSize.height
        
        var svg = """
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 250 250" width="250" height="250">
        """
        
        for line in lines {
            guard let firstPoint = line.first else { continue }
            svg += """
            <path d="M \(firstPoint.x * scaleX) \(firstPoint.y * scaleY)
            """
            for point in line.dropFirst() {
                svg += "L \(point.x * scaleX) \(point.y * scaleY) "
            }
            svg += "\" stroke=\"black\" fill=\"none\" stroke-width=\"2\"/>\n"
        }
        
        svg += "</svg>"
        return svg
    }
    
    func saveSVG(_ svg: String) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.svg]
        panel.nameFieldStringValue = "drawing.svg"
        panel.begin { result in
            if result == .OK, let url = panel.url {
                do {
                    try svg.write(to: url, atomically: true, encoding: .utf8)
                } catch {
                    print("Failed to save SVG: \(error)")
                }
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
