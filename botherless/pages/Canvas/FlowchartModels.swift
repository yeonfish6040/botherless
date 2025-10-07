// MARK: - CGRect Extension for Codable
extension CGRect: Codable {
    enum CodingKeys: String, CodingKey {
        case x, y, width, height
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let x = try container.decode(CGFloat.self, forKey: .x)
        let y = try container.decode(CGFloat.self, forKey: .y)
        let width = try container.decode(CGFloat.self, forKey: .width)
        let height = try container.decode(CGFloat.self, forKey: .height)
        self.init(x: x, y: y, width: width, height: height)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(origin.x, forKey: .x)
        try container.encode(origin.y, forKey: .y)
        try container.encode(size.width, forKey: .width)
        try container.encode(size.height, forKey: .height)
    }
}//
//  FlowchartModels.swift
//  botherless
//
//  Created by Yeonjun Lee on 10/17/25.
//

import SwiftUI

// MARK: - Arrow Model
struct Arrow: Identifiable, Codable {
    let id: UUID
    var startPoint: CGPoint
    var endPoint: CGPoint
    var isBidirectional: Bool
    var color: Color = .black
    var centerPoint: CGPoint {
        CGPoint(
            x: (startPoint.x + endPoint.x) / 2,
            y: (startPoint.y + endPoint.y) / 2
        )
    }
    
    init(id: UUID = UUID(), startPoint: CGPoint, endPoint: CGPoint, isBidirectional: Bool = false) {
        self.id = id
        self.startPoint = startPoint
        self.endPoint = endPoint
        self.isBidirectional = isBidirectional
    }
    
    func contains(point: CGPoint, threshold: CGFloat = 15.0) -> Bool {
        return distanceFromPointToLine(point: point) < threshold
    }
    
    private func distanceFromPointToLine(point: CGPoint) -> CGFloat {
        let A = point.x - startPoint.x
        let B = point.y - startPoint.y
        let C = endPoint.x - startPoint.x
        let D = endPoint.y - startPoint.y
        
        let dot = A * C + B * D
        let lenSq = C * C + D * D
        var param: CGFloat = -1
        
        if lenSq != 0 {
            param = dot / lenSq
        }
        
        var xx, yy: CGFloat
        
        if param < 0 {
            xx = startPoint.x
            yy = startPoint.y
        } else if param > 1 {
            xx = endPoint.x
            yy = endPoint.y
        } else {
            xx = startPoint.x + param * C
            yy = startPoint.y + param * D
        }
        
        let dx = point.x - xx
        let dy = point.y - yy
        
        return sqrt(dx * dx + dy * dy)
    }
}

// MARK: - Symbol Model
struct FlowSymbol: Identifiable, Codable {
    let id: UUID
    var position: CGPoint  // Center point of the symbol
    var paths: [DrawingPath]
    var assignedKey: String?
    var size: CGSize
    var boundingBox: CGRect
    
    init(id: UUID = UUID(), position: CGPoint, paths: [DrawingPath], assignedKey: String? = nil) {
        self.id = id
        self.position = position
        self.paths = paths
        self.assignedKey = assignedKey
        
        // Calculate bounding box from all points (paths are relative to center)
        var allPoints: [CGPoint] = []
        for path in paths {
            allPoints.append(contentsOf: path.points)
        }
        
        if allPoints.isEmpty {
            self.size = CGSize(width: 50, height: 50)
            self.boundingBox = CGRect(
                x: position.x - 25,
                y: position.y - 25,
                width: 50,
                height: 50
            )
        } else {
            let minX = allPoints.map { $0.x }.min() ?? 0
            let minY = allPoints.map { $0.y }.min() ?? 0
            let maxX = allPoints.map { $0.x }.max() ?? 0
            let maxY = allPoints.map { $0.y }.max() ?? 0
            
            let width = maxX - minX + 20  // Add padding
            let height = maxY - minY + 20
            
            self.size = CGSize(width: width, height: height)
            // Position is the center, so bounding box starts at position - size/2
            self.boundingBox = CGRect(
                x: position.x - width / 2,
                y: position.y - height / 2,
                width: width,
                height: height
            )
        }
    }
    
    // Create a copy with new position (for placing assigned symbols)
    func copy(at newPosition: CGPoint) -> FlowSymbol {
        var copy = self
        copy.position = newPosition
        copy.boundingBox = CGRect(
            x: newPosition.x - size.width / 2,
            y: newPosition.y - size.height / 2,
            width: size.width,
            height: size.height
        )
        return copy
    }
    
    // Check if a point is inside the bounding box
    func contains(point: CGPoint) -> Bool {
        return boundingBox.contains(point)
    }
}

// MARK: - Drawing Path
struct DrawingPath: Identifiable, Codable {
    let id: UUID
    var points: [CGPoint]
    var color: Color = .black
    var lineWidth: CGFloat = 2.0
    
    init(id: UUID = UUID(), points: [CGPoint] = []) {
        self.id = id
        self.points = points
    }
}

// MARK: - Drawing Mode
enum DrawingMode {
    case arrow
    case symbol
    case assigningSymbol(FlowSymbol)
    case placingSymbol(String) // Key that was pressed
    case draggingSymbol(UUID)
    case draggingArrow(UUID, CGPoint) // Arrow ID and initial touch offset
    case none
}

// MARK: - Canvas Mode
enum CanvasMode: Int, CaseIterable {
    case draw = 0
    case move = 1
    case erase = 2
    
    var icon: String {
        switch self {
        case .draw: return "pencil.tip"
        case .move: return "hand.draw"
        case .erase: return "eraser.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .draw: return .blue
        case .move: return .green
        case .erase: return .red
        }
    }
    
    var name: String {
        switch self {
        case .draw: return "Draw"
        case .move: return "Move"
        case .erase: return "Erase"
        }
    }
    
    func next() -> CanvasMode {
        let allCases = CanvasMode.allCases
        let currentIndex = allCases.firstIndex(of: self) ?? 0
        let nextIndex = (currentIndex + 1) % allCases.count
        return allCases[nextIndex]
    }
}

// MARK: - Modifier Keys State
struct ModifierKeys {
    var isCommandPressed: Bool = false
    var isOptionPressed: Bool = false
    var isShiftPressed: Bool = false
}

// MARK: - Color Extension for Codable
extension Color: Codable {
    enum CodingKeys: String, CodingKey {
        case red, green, blue, opacity
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let red = try container.decode(Double.self, forKey: .red)
        let green = try container.decode(Double.self, forKey: .green)
        let blue = try container.decode(Double.self, forKey: .blue)
        let opacity = try container.decode(Double.self, forKey: .opacity)
        self.init(red: red, green: green, blue: blue, opacity: opacity)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        guard let components = UIColor(self).cgColor.components else { return }
        try container.encode(components[0], forKey: .red)
        try container.encode(components[1], forKey: .green)
        try container.encode(components[2], forKey: .blue)
        try container.encode(components.count > 3 ? components[3] : 1.0, forKey: .opacity)
    }
}

// MARK: - CGPoint Extension for Codable
extension CGPoint: Codable {
    enum CodingKeys: String, CodingKey {
        case x, y
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let x = try container.decode(CGFloat.self, forKey: .x)
        let y = try container.decode(CGFloat.self, forKey: .y)
        self.init(x: x, y: y)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(x, forKey: .x)
        try container.encode(y, forKey: .y)
    }
}

// MARK: - CGSize Extension for Codable
extension CGSize: Codable {
    enum CodingKeys: String, CodingKey {
        case width, height
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let width = try container.decode(CGFloat.self, forKey: .width)
        let height = try container.decode(CGFloat.self, forKey: .height)
        self.init(width: width, height: height)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(width, forKey: .width)
        try container.encode(height, forKey: .height)
    }
}
