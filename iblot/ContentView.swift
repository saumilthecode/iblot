import SwiftUI

struct ContentView: View {
    var body: some View {
        Text("Hello, world!")
    }

    func svgToPolylines(svg: String) -> String {
        // Parse the SVG path data
        // This is a simplified example, real parsing would be more complex
        let pathData = svg.split(separator: " ")
        var polylines: [[CGPoint]] = []
        var currentPolyline: [CGPoint] = []
        var currentPoint = CGPoint.zero

        for command in pathData {
            switch command {
            case "M":
                if !currentPolyline.isEmpty {
                    polylines.append(currentPolyline)
                    currentPolyline = []
                }
            case "L":
                if let x = Double(pathData.next()), let y = Double(pathData.next()) {
                    currentPoint = CGPoint(x: x, y: y)
                    currentPolyline.append(currentPoint)
                }
            default:
                break
            }
        }
        if !currentPolyline.isEmpty {
            polylines.append(currentPolyline)
        }

        // Scale the polylines to 115x115
        let scaleX = 115 / canvasSize.width
        let scaleY = 115 / canvasSize.height
        let scaledPolylines = polylines.map { polyline in
            polyline.map { point in
                CGPoint(x: point.x * scaleX, y: point.y * scaleY)
            }
        }

        // Convert to string
        var polylineString = ""
        for polyline in scaledPolylines {
            for point in polyline {
                polylineString += "\(point.x),\(point.y) "
            }
            polylineString += "| "
        }

        return polylineString
    }

    // Example usage
    func exampleUsage() {
        let svg = "M 10 10 L 20 20 L 30 30"
        let polylineString = svgToPolylines(svg: svg)
        print(polylineString)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
} 