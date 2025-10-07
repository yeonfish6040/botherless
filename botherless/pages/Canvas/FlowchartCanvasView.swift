//
//  FlowchartCanvasView.swift
//  botherless
//
//  Created by Yeonjun Lee on 10/17/25.
//

import SwiftUI
import PencilKit

struct FlowchartCanvasView: View {
    @StateObject private var viewModel = FlowchartViewModel()
    @State private var screenSize: CGSize = .zero
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color(white: 0.96)
                    .edgesIgnoringSafeArea(.all)
                
                // Interactive canvas layer
                InteractiveCanvas(
                    onModifierChanged: { modifiers in
                        viewModel.modifierKeys.isCommandPressed = modifiers.contains(.command)
                        viewModel.modifierKeys.isOptionPressed = modifiers.contains(.alternate)
                        viewModel.modifierKeys.isShiftPressed = modifiers.contains(.shift)
                        
                        if !modifiers.contains(.command) {
                            viewModel.handleKeyRelease("command")
                        }
                    },
                    onKeyPressed: { key in
                        print("🎹 Canvas received key: '\(key)'")
                        viewModel.handleKeyPress(key)
                    },
                    onKeyReleased: { _ in },
                    onTouchBegan: { point in
                        let canvasPoint = viewModel.screenToCanvas(point, screenSize: geometry.size)
                        viewModel.startDrawing(at: canvasPoint)
                    },
                    onTouchMoved: { point in
                        let canvasPoint = viewModel.screenToCanvas(point, screenSize: geometry.size)
                        viewModel.continueDrawing(at: canvasPoint)
                    },
                    onTouchEnded: { point in
                        let canvasPoint = viewModel.screenToCanvas(point, screenSize: geometry.size)
                        viewModel.endDrawing(at: canvasPoint)
                    },
                    onPinchChanged: { scale in
                        viewModel.handlePinchChanged(scale)
                    },
                    onPinchEnded: { scale in
                        viewModel.handlePinchEnded(scale)
                    },
                    onPanChanged: { translation in
                        viewModel.updateCanvasOffset(translation)
                    },
                    onPanEnded: {},
                    onDoubleTap: {
                        viewModel.cycleCanvasMode()
                    },
                    isPencilOnlyMode: viewModel.isPencilOnlyMode
                )
                
                // Drawing canvas
                Canvas { context, size in
                    // Draw all arrows
                    for arrow in viewModel.arrows {
                        drawArrow(context: context, arrow: arrow, size: size)
                    }
                    
                    // Draw all symbols
                    for symbol in viewModel.symbols {
                        drawSymbol(context: context, symbol: symbol, size: size)
                    }
                    
                    // Draw current path being drawn
                    if !viewModel.currentPath.points.isEmpty {
                        drawPath(context: context, path: viewModel.currentPath, size: size)
                    }
                    
                    // Draw symbol paths in progress
                    for path in viewModel.symbolPathsInProgress {
                        drawPath(context: context, path: path, size: size)
                    }
                }
                .allowsHitTesting(false)
                
                // UI Overlays
                VStack {
                    HStack(alignment: .top) {
                        Spacer()
                        statusIndicator
                            .padding(.top, 20)
                            .padding(.trailing, 20)
                    }
                    
                    Spacer()
                    
                    // Bottom bar with help and zoom controls
                    HStack(spacing: 20) {
                        Spacer()
                        helpText
                        Spacer()
                        controlButtons
                            .padding(.trailing, 20)
                    }
                    .padding(.bottom, 20)
                }
                
                HStack {
                    VStack(spacing: 12) {
                        modeSelector
                        leftToolbar
                    }
                    .padding(.leading, 20)
                    Spacer()
                }
                
                if viewModel.showAssignmentPrompt {
                    assignmentPromptOverlay
                }
            }
            .onAppear {
                screenSize = geometry.size
            }
            .onChange(of: geometry.size) { newSize in
                screenSize = newSize
            }
        }
    }
    
    // MARK: - Mode Selector
    private var modeSelector: some View {
        VStack(spacing: 0) {
            ForEach(CanvasMode.allCases, id: \.self) { mode in
                Button(action: {
                    viewModel.setCanvasMode(mode)
                }) {
                    Image(systemName: mode.icon)
                        .font(.system(size: 20))
                        .foregroundColor(viewModel.canvasMode == mode ? mode.color : .gray)
                        .frame(width: 50, height: 45)
                        .background(
                            Group {
                                if viewModel.canvasMode == mode {
                                    if mode == .draw {
                                        UnevenRoundedRectangle(
                                            topLeadingRadius: 25,
                                            bottomLeadingRadius: 0,
                                            bottomTrailingRadius: 0,
                                            topTrailingRadius: 25
                                        )
                                        .fill(mode.color.opacity(0.15))
                                    } else if mode == .erase {
                                        UnevenRoundedRectangle(
                                            topLeadingRadius: 0,
                                            bottomLeadingRadius: 25,
                                            bottomTrailingRadius: 25,
                                            topTrailingRadius: 0
                                        )
                                        .fill(mode.color.opacity(0.15))
                                    } else {
                                        Rectangle().fill(mode.color.opacity(0.15))
                                    }
                                }
                            }
                        )
                }
                
                if mode != .erase {
                    Divider().frame(height: 1).background(Color.gray.opacity(0.3))
                }
            }
        }
        .frame(width: 50)
        .background(RoundedRectangle(cornerRadius: 25).fill(Color.white).shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 4))
        .clipShape(RoundedRectangle(cornerRadius: 25))
    }
    
    // MARK: - Drawing Functions
    private func drawArrow(context: GraphicsContext, arrow: Arrow, size: CGSize) {
        let screenStart = viewModel.canvasToScreen(arrow.startPoint, screenSize: size)
        let screenEnd = viewModel.canvasToScreen(arrow.endPoint, screenSize: size)
        
        var path = Path()
        path.move(to: screenStart)
        path.addLine(to: screenEnd)
        
        context.stroke(path, with: .color(arrow.color), lineWidth: 2)
        
        drawArrowhead(context: context, from: screenStart, to: screenEnd)
        
        if arrow.isBidirectional {
            drawArrowhead(context: context, from: screenEnd, to: screenStart)
        }
    }
    
    private func drawArrowhead(context: GraphicsContext, from start: CGPoint, to end: CGPoint) {
        let angle = atan2(end.y - start.y, end.x - start.x)
        let arrowLength: CGFloat = 15
        let arrowAngle: CGFloat = .pi / 6
        
        let point1 = CGPoint(
            x: end.x - arrowLength * cos(angle - arrowAngle),
            y: end.y - arrowLength * sin(angle - arrowAngle)
        )
        let point2 = CGPoint(
            x: end.x - arrowLength * cos(angle + arrowAngle),
            y: end.y - arrowLength * sin(angle + arrowAngle)
        )
        
        var arrowPath = Path()
        arrowPath.move(to: point1)
        arrowPath.addLine(to: end)
        arrowPath.addLine(to: point2)
        
        context.stroke(arrowPath, with: .color(.black), lineWidth: 2)
    }
    
    private func drawSymbol(context: GraphicsContext, symbol: FlowSymbol, size: CGSize) {
        let screenPos = viewModel.canvasToScreen(symbol.position, screenSize: size)
        
        // Calculate screen bounding box
        let screenBox = CGRect(
            x: screenPos.x - symbol.size.width / 2,
            y: screenPos.y - symbol.size.height / 2,
            width: symbol.size.width,
            height: symbol.size.height
        )
        
        // Draw bounding box
        var boxPath = Path(screenBox)
        context.stroke(boxPath, with: .color(.red.opacity(0.5)), style: StrokeStyle(lineWidth: 2, dash: [5, 3]))
        
        // Draw corner markers
        let corners = [
            CGPoint(x: screenBox.minX, y: screenBox.minY),
            CGPoint(x: screenBox.maxX, y: screenBox.minY),
            CGPoint(x: screenBox.minX, y: screenBox.maxY),
            CGPoint(x: screenBox.maxX, y: screenBox.maxY)
        ]
        
        for corner in corners {
            var cornerPath = Path()
            cornerPath.addEllipse(in: CGRect(x: corner.x - 3, y: corner.y - 3, width: 6, height: 6))
            context.fill(cornerPath, with: .color(.red))
        }
        
        // Draw symbol paths
        for drawingPath in symbol.paths {
            if drawingPath.points.count > 1 {
                var swiftUIPath = Path()
                let firstPoint = CGPoint(
                    x: screenPos.x + drawingPath.points[0].x,
                    y: screenPos.y + drawingPath.points[0].y
                )
                swiftUIPath.move(to: firstPoint)
                
                for point in drawingPath.points.dropFirst() {
                    let screenPoint = CGPoint(
                        x: screenPos.x + point.x,
                        y: screenPos.y + point.y
                    )
                    swiftUIPath.addLine(to: screenPoint)
                }
                
                context.stroke(swiftUIPath, with: .color(drawingPath.color), lineWidth: drawingPath.lineWidth)
            }
        }
        
        // Draw assignment badge
        if let key = symbol.assignedKey {
            let badgeCenter = CGPoint(
                x: screenBox.minX + 15,
                y: screenBox.minY + 15
            )
            let badgeRadius: CGFloat = 15
            
            var badgePath = Path()
            badgePath.addEllipse(in: CGRect(
                x: badgeCenter.x - badgeRadius,
                y: badgeCenter.y - badgeRadius,
                width: badgeRadius * 2,
                height: badgeRadius * 2
            ))
            
            context.fill(badgePath, with: .color(.blue))
            
            let text = Text(key.uppercased())
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)
            
            context.draw(text, at: badgeCenter, anchor: .center)
        }
    }
    
    private func drawPath(context: GraphicsContext, path: DrawingPath, size: CGSize) {
        guard path.points.count > 1 else { return }
        
        var swiftUIPath = Path()
        let firstScreen = viewModel.canvasToScreen(path.points[0], screenSize: size)
        swiftUIPath.move(to: firstScreen)
        
        for point in path.points.dropFirst() {
            let screenPoint = viewModel.canvasToScreen(point, screenSize: size)
            swiftUIPath.addLine(to: screenPoint)
        }
        
        context.stroke(swiftUIPath, with: .color(path.color), lineWidth: path.lineWidth)
    }
    
    // MARK: - UI Components (keeping existing implementations)
    private var leftToolbar: some View {
        VStack(spacing: 0) {
            ToolbarButton(icon: "arrow.uturn.backward", isActive: false, color: .gray, isFirst: true) {
                viewModel.undo()
            }
            .disabled(!viewModel.historyManager.canUndo)
            .opacity(viewModel.historyManager.canUndo ? 1.0 : 0.3)
            
            Divider().frame(height: 1).background(Color.gray.opacity(0.3))
            
            ToolbarButton(icon: "arrow.uturn.forward", isActive: false, color: .gray) {
                viewModel.redo()
            }
            .disabled(!viewModel.historyManager.canRedo)
            .opacity(viewModel.historyManager.canRedo ? 1.0 : 0.3)
            
            Divider().frame(height: 1).background(Color.gray.opacity(0.3))
            
            ToolbarButton(icon: "hand.tap.fill", isActive: viewModel.isAssignModeActive, color: .purple) {
                viewModel.toggleAssignMode()
            }
            
            Divider().frame(height: 1).background(Color.gray.opacity(0.3))
            
            ToolbarButton(icon: "pencil.tip.crop.circle.fill", isActive: viewModel.isSymbolModeToggled, color: .blue) {
                viewModel.toggleSymbolMode()
            }
            
            Divider().frame(height: 1).background(Color.gray.opacity(0.3))
            
            ToolbarButton(icon: "arrow.left.arrow.right", isActive: viewModel.modifierKeys.isShiftPressed, color: .orange, onPressChanged: { isPressing in
                if(isPressing) {
                    viewModel.toggleBothArrow()
                }
            })
            
            Divider().frame(height: 1).background(Color.gray.opacity(0.3))
            
            ToolbarButton(icon: "applepencil", isActive: viewModel.isPencilOnlyMode, color: .cyan, onPressChanged: { isPressing in
                if(isPressing) {
                    viewModel.togglePencilOnlyMode()
                }
            })
            
            Divider().frame(height: 1).background(Color.gray.opacity(0.3))
            
            ForEach(0..<10, id: \.self) { number in
                let key = "\(number)"
                let hasSymbol = viewModel.symbolKeyMap[key] != nil
                
                ToolbarNumberButton(
                    number: number,
                    hasSymbol: hasSymbol,
                    isPlacing: {
                        if case .placingSymbol(let k) = viewModel.drawingMode {
                            return k == key
                        }
                        return false
                    }(),
                    isLast: number == 9
                ) {
                    viewModel.placeSymbolFromKey(key)
                }
                
                if number < 9 {
                    Divider().frame(height: 1).background(Color.gray.opacity(0.3))
                }
            }
        }
        .frame(width: 50)
        .background(RoundedRectangle(cornerRadius: 25).fill(Color.white).shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 4))
        .clipShape(RoundedRectangle(cornerRadius: 25))
    }
    
    private var statusIndicator: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Circle().fill(currentModeColor).frame(width: 12, height: 12)
                Text(currentModeText).font(.headline).fontWeight(.bold)
            }
            .padding(.horizontal, 16).padding(.vertical, 10)
            .background(currentModeColor.opacity(0.15)).cornerRadius(12)
        }
    }
    
    private var currentModeText: String {
        if case .assigningSymbol = viewModel.drawingMode { return "🎯 Assigning Key" }
        else if case .placingSymbol(let key) = viewModel.drawingMode { return "📍 Placing Symbol (\(key.uppercased()))" }
        else if viewModel.isDrawingSymbol { return "✏️ Drawing Symbol" }
        else if viewModel.modifierKeys.isCommandPressed { return "🔷 Symbol Mode" }
        else if viewModel.modifierKeys.isOptionPressed { return "🎯 Select to Assign" }
        else { return "➡️ Arrow Mode" }
    }
    
    private var currentModeColor: Color {
        if case .assigningSymbol = viewModel.drawingMode { return .purple }
        else if case .placingSymbol = viewModel.drawingMode { return .green }
        else if viewModel.isDrawingSymbol { return .blue }
        else if viewModel.modifierKeys.isCommandPressed { return .blue }
        else if viewModel.modifierKeys.isOptionPressed { return .purple }
        else { return .gray }
    }
    
    private var controlButtons: some View {
        HStack(spacing: 6) {
            Button(action: { viewModel.updateCanvasScale(viewModel.canvasScale / 1.2) }) {
                Image(systemName: "minus.magnifyingglass")
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
            }
            .frame(width: 32, height: 32)
            .background(Color.black.opacity(0.005))
            .cornerRadius(6)
            
            Text("\(Int(viewModel.canvasScale * 100))%")
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundColor(.black)
                .frame(minWidth: 42)
            
            Button(action: { viewModel.updateCanvasScale(viewModel.canvasScale * 1.2) }) {
                Image(systemName: "plus.magnifyingglass")
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
            }
            .frame(width: 32, height: 32)
            .background(Color.black.opacity(0.005))
            .cornerRadius(6)
            
            Button(action: { viewModel.resetCanvasTransform() }) {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
            }
            .frame(width: 32, height: 32)
            .background(Color.black.opacity(0.005))
            .cornerRadius(6)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.95))
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)
        )
    }
    
    private var helpText: some View {
        HStack(spacing: 20) {
            // Drawing section
            HStack(spacing: 16) {
                HStack(spacing: 6) {
                    Image(systemName: "hand.draw")
                        .font(.system(size: 14))
                        .foregroundColor(.blue)
                    Text("1 finger draw")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.black)
                }
                
                HStack(spacing: 6) {
                    Image(systemName: "hand.pinch")
                        .font(.system(size: 14))
                        .foregroundColor(.purple)
                    Text("2 fingers zoom/pan")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.black)
                }
            }
            
            Divider()
                .frame(height: 20)
            
            // Modifier keys section
            HStack(spacing: 16) {
                HStack(spacing: 6) {
                    Text("⌘")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 20, height: 20)
                        .background(Color.orange)
                        .cornerRadius(4)
                    Text("Symbol")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.black)
                }
                
                HStack(spacing: 6) {
                    Text("⌥")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 20, height: 20)
                        .background(Color.green)
                        .cornerRadius(4)
                    Text("Assign")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.black)
                }
                
                HStack(spacing: 6) {
                    Text("⇧")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 20, height: 20)
                        .background(Color.pink)
                        .cornerRadius(4)
                    Text("Bidirectional")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.black)
                }
            }
            
            Divider()
                .frame(height: 20)
            
            // Shortcuts section
            HStack(spacing: 16) {
                HStack(spacing: 4) {
                    Text("Z")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                        .frame(width: 20, height: 20)
                        .background(Color.gray.opacity(0.7))
                        .cornerRadius(4)
                    Text("Undo")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.black)
                }
                
                HStack(spacing: 4) {
                    Text("Y")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                        .frame(width: 20, height: 20)
                        .background(Color.gray.opacity(0.7))
                        .cornerRadius(4)
                    Text("Redo")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.black)
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.95))
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)
        )
    }
    
    private var assignmentPromptOverlay: some View {
        ZStack {
            Color.black.opacity(0.5)
                .edgesIgnoringSafeArea(.all)
                .onTapGesture {
                    // Close on background tap
                    viewModel.handleKeyPress("ESC")
                }
            
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 12) {
                    HStack {
                        Image(systemName: "keyboard")
                            .font(.system(size: 28))
                            .foregroundColor(.blue)
                        
                        Text("Assign Shortcut Key")
                            .font(.system(size: 24, weight: .semibold))
                    }
                    
                    Text("Choose a key to quickly place this symbol")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 32)
                .padding(.bottom, 24)
                
                Divider()
                
                // Number grid
                VStack(spacing: 16) {
                    Text("NUMBER KEYS")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    VStack(spacing: 12) {
                        HStack(spacing: 12) {
                            ForEach(0..<5) { n in
                                assignmentKeyButton(for: n)
                            }
                        }
                        HStack(spacing: 12) {
                            ForEach(5..<10) { n in
                                assignmentKeyButton(for: n)
                            }
                        }
                    }
                }
                .padding(.vertical, 24)
                .padding(.horizontal, 32)
                
                Divider()
                
                // Current assignment status
                if let symbol = viewModel.selectedSymbolForAssignment {
                    HStack(spacing: 12) {
                        if let key = symbol.assignedKey {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("Currently assigned to")
                                    .foregroundColor(.secondary)
                                Text(key.uppercased())
                                    .font(.system(.body, design: .monospaced))
                                    .fontWeight(.bold)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.blue.opacity(0.1))
                                    .cornerRadius(6)
                            }
                            
                            Button(action: {
                                viewModel.handleKeyPress("BACKSPACE")
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "xmark.circle.fill")
                                    Text("Unassign")
                                }
                                .font(.caption)
                                .foregroundColor(.red)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.red.opacity(0.1))
                                .cornerRadius(6)
                            }
                        } else {
                            HStack(spacing: 8) {
                                Image(systemName: "info.circle.fill")
                                    .foregroundColor(.blue)
                                Text("No key assigned yet")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(.vertical, 16)
                    .frame(maxWidth: .infinity)
                    .background(Color.gray.opacity(0.05))
                }
                
                Divider()
                
                // Footer with instructions
                VStack(spacing: 8) {
                    HStack(spacing: 20) {
                        HStack(spacing: 6) {
                            Image(systemName: "keyboard")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("Press any key")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        HStack(spacing: 6) {
                            Image(systemName: "delete.left")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("Unassign")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        HStack(spacing: 6) {
                            Image(systemName: "escape")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("Cancel")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Text("Reserved: Z (undo), Y (redo)")
                        .font(.caption2)
                        .foregroundColor(.orange.opacity(0.8))
                }
                .padding(.vertical, 16)
                .padding(.horizontal, 24)
            }
            .frame(width: 500)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.white)
                    .shadow(color: .black.opacity(0.2), radius: 30, x: 0, y: 10)
            )
        }
    }
    
    private func assignmentKeyButton(for number: Int) -> some View {
        let isAssigned = viewModel.selectedSymbolForAssignment?.assignedKey == "\(number)"
        
        return Button(action: {
            viewModel.handleKeyPress("\(number)")
        }) {
            VStack(spacing: 4) {
                Text("\(number)")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundColor(isAssigned ? .white : .primary)
                
                if isAssigned {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(.white)
                }
            }
            .frame(width: 60, height: 60)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isAssigned ? Color.blue : Color.gray.opacity(0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(isAssigned ? Color.blue : Color.gray.opacity(0.3), lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Component Views
struct StatusBadge: View {
    let text: String
    let color: Color
    var body: some View {
        Text(text).font(.caption).fontWeight(.semibold)
            .padding(.horizontal, 12).padding(.vertical, 6)
            .background(color.opacity(0.2)).foregroundColor(color).cornerRadius(8)
    }
}

struct ToolbarButton: View {
    let icon: String
    let isActive: Bool
    let color: Color
    var isFirst: Bool = false
    var isLast: Bool = false
    var action: (() -> Void)? = nil
    var onPressChanged: ((Bool) -> Void)? = nil
    
    var body: some View {
        Group {
            if let onPressChanged = onPressChanged {
                Image(systemName: icon).font(.system(size: 20))
                    .foregroundColor(isActive ? color : .gray).frame(width: 50, height: 45)
                    .background(backgroundShape).gesture(DragGesture(minimumDistance: 0)
                        .onChanged { _ in onPressChanged(true) }
                        .onEnded { _ in onPressChanged(false) })
            } else {
                Button(action: { action?() }) {
                    Image(systemName: icon).font(.system(size: 20))
                        .foregroundColor(isActive ? color : .gray).frame(width: 50, height: 45)
                        .background(backgroundShape)
                }
            }
        }
    }
    
    @ViewBuilder
    private var backgroundShape: some View {
        if isActive {
            if isFirst {
                UnevenRoundedRectangle(topLeadingRadius: 25, bottomLeadingRadius: 0, bottomTrailingRadius: 0, topTrailingRadius: 25)
                    .fill(color.opacity(0.15))
            } else if isLast {
                UnevenRoundedRectangle(topLeadingRadius: 0, bottomLeadingRadius: 25, bottomTrailingRadius: 25, topTrailingRadius: 0)
                    .fill(color.opacity(0.15))
            } else {
                Rectangle().fill(color.opacity(0.15))
            }
        }
    }
}

struct ToolbarNumberButton: View {
    let number: Int
    let hasSymbol: Bool
    let isPlacing: Bool
    let isLast: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ZStack {
                Text("\(number)").font(.system(size: 18, weight: .bold))
                    .foregroundColor(isPlacing ? .green : (hasSymbol ? .blue : .gray))
                    .frame(width: 50, height: 45).background(backgroundShape)
                if hasSymbol {
                    Circle().fill(Color.blue).frame(width: 6, height: 6).offset(x: 12, y: -10)
                }
            }
        }
        .disabled(!hasSymbol)
    }
    
    @ViewBuilder
    private var backgroundShape: some View {
        if isPlacing {
            if isLast {
                UnevenRoundedRectangle(topLeadingRadius: 0, bottomLeadingRadius: 25, bottomTrailingRadius: 25, topTrailingRadius: 0)
                    .fill(Color.green.opacity(0.15))
            } else {
                Rectangle().fill(Color.green.opacity(0.15))
            }
        }
    }
}

#Preview {
    FlowchartCanvasView()
}
