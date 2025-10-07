//
//  FlowchartViewModel.swift
//  botherless
//
//  Created by Yeonjun Lee on 10/17/25.
//

import SwiftUI
import Combine

class FlowchartViewModel: ObservableObject {
    @Published var arrows: [Arrow] = []
    @Published var symbols: [FlowSymbol] = []
    @Published var currentPath: DrawingPath = DrawingPath()
    @Published var modifierKeys = ModifierKeys()
    @Published var drawingMode: DrawingMode = .none
    @Published var symbolKeyMap: [String: FlowSymbol] = [:]
    @Published var showAssignmentPrompt: Bool = false
    @Published var selectedSymbolForAssignment: FlowSymbol?
    @Published var symbolPathsInProgress: [DrawingPath] = []
    @Published var isSymbolModeToggled: Bool = false
    @Published var isAssignModeActive: Bool = false
    @Published var historyManager = HistoryManager()
    @Published var isPencilOnlyMode: Bool = true  // Apple Pencil only mode
    @Published var canvasMode: CanvasMode = .draw  // Current canvas mode
    @Published var isBidirectionalMode: Bool = false  // Bidirectional arrow mode
    
    // Canvas transform
    @Published var canvasScale: CGFloat = 1.0
    @Published var canvasOffset: CGPoint = .zero
    
    private var baseScale: CGFloat = 1.0
    
    // Public state for UI
    var isDrawingSymbol: Bool {
        return symbolDrawingStartedWithCommand
    }
    
    // Temporary storage
    private var currentArrowStart: CGPoint?
    private var symbolDrawingStartedWithCommand: Bool = false
    private var symbolStartPoint: CGPoint?
    private var commandReleasedDuringSymbolDrawing: Bool = false
    
    // MARK: - Modifier Key Handlers
    func handleKeyPress(_ key: String) {
        print("🔑 Key pressed: '\(key)'")
        
        // Handle ESC key
        if key == "ESC" {
            if showAssignmentPrompt {
                cancelAssignment()
            }
            return
        }
        
        // Handle Backspace key
        if key == "BACKSPACE" {
            if case .assigningSymbol(let symbol) = drawingMode {
                unassignSymbol(symbol)
            }
            return
        }
        
        // Check for undo/redo first (Z and Y are reserved)
        let lowerKey = key.lowercased()
        if lowerKey == "z" {
            print("⏪ Undo triggered")
            undo()
            return
        }
        if lowerKey == "y" {
            print("⏩ Redo triggered")
            redo()
            return
        }
        
        // Check if we're in assigning mode
        if case .assigningSymbol(let symbol) = drawingMode {
            print("📍 In assigning mode, calling assignSymbolToKey")
            assignSymbolToKey(symbol: symbol, key: key)
            return
        }
        
        // Check if a symbol is assigned to this key
        let normalizedKey = lowerKey
        if let _ = symbolKeyMap[normalizedKey] {
            print("✅ Found symbol for key: '\(normalizedKey)'")
            startPlacingSymbol(key: normalizedKey)
        } else {
            print("❌ No symbol found for key: '\(normalizedKey)'")
        }
    }
    
    func handleKeyRelease(_ key: String) {
        switch key.lowercased() {
        case "command", "cmd":
            // Command를 뗐을 때, 심볼 드로잉 중이었고 현재 그리는 중이 아니라면 심볼 완성
            if symbolDrawingStartedWithCommand && currentPath.points.isEmpty && !symbolPathsInProgress.isEmpty {
                // Toggle mode가 아닐 때만 자동 완성
                if !isSymbolModeToggled {
                    createSymbol(paths: symbolPathsInProgress)
                    symbolPathsInProgress = []
                    symbolDrawingStartedWithCommand = false
                    commandReleasedDuringSymbolDrawing = false
                    symbolStartPoint = nil
                }
            } else if symbolDrawingStartedWithCommand && !isSymbolModeToggled {
                // 드로잉 중이면 표시만 해둠
                commandReleasedDuringSymbolDrawing = true
            }
        default:
            break
        }
    }
    
    // MARK: - Toolbar Actions
    func toggleSymbolMode() {
        isSymbolModeToggled.toggle()
        
        // 토글 끄면서 심볼 그리기 중이었으면 완성
        if !isSymbolModeToggled && symbolDrawingStartedWithCommand && !symbolPathsInProgress.isEmpty {
            createSymbol(paths: symbolPathsInProgress)
            symbolPathsInProgress = []
            symbolDrawingStartedWithCommand = false
            commandReleasedDuringSymbolDrawing = false
            symbolStartPoint = nil
        }
    }
    
    func toggleAssignMode() {
        isAssignModeActive.toggle()
    }
    
    func toggleBothArrow() {
        modifierKeys.isShiftPressed.toggle();
    }
    
    func togglePencilOnlyMode() {
        isPencilOnlyMode.toggle()
    }
    
    func cycleCanvasMode() {
        canvasMode = canvasMode.next()
        print("🔄 Canvas mode changed to: \(canvasMode.name)")
    }
    
    func setCanvasMode(_ mode: CanvasMode) {
        canvasMode = mode
    }
    
    private func eraseAt(point: CGPoint) {
        saveCurrentState()
        
        // Check if point hits any symbol
        if let symbol = findSymbol(at: point) {
            symbols.removeAll { $0.id == symbol.id }
            // Remove from keyMap if assigned
            if let key = symbol.assignedKey {
                symbolKeyMap.removeValue(forKey: key)
            }
            print("🗑️ Erased symbol")
            return
        }
        
        // Check if point hits any arrow
        if let arrow = findArrow(at: point) {
            arrows.removeAll { $0.id == arrow.id }
            print("🗑️ Erased arrow")
        }
    }
    
    func placeSymbolFromKey(_ key: String) {
        if let _ = symbolKeyMap[key] {
            startPlacingSymbol(key: key)
        }
    }
    
    // MARK: - Drawing Handlers
    func startDrawing(at point: CGPoint) {
        // Erase mode - find and delete objects at point
        if canvasMode == .erase {
            eraseAt(point: point)
            return
        }
        
        // Move mode - start dragging symbol or arrow
        if canvasMode == .move {
            // Check symbols first
            if let symbol = findSymbol(at: point) {
                drawingMode = .draggingSymbol(symbol.id)
                return
            }
            
            // Check arrows
            if let arrow = findArrow(at: point) {
                let offset = CGPoint(
                    x: point.x - arrow.centerPoint.x,
                    y: point.y - arrow.centerPoint.y
                )
                drawingMode = .draggingArrow(arrow.id, offset)
                return
            }
            return
        }
        
        // Draw mode continues below...
        
        // Assign mode - select symbol to assign
        if isAssignModeActive {
            if let symbol = findSymbol(at: point) {
                enterAssignmentMode(for: symbol)
            }
            return
        }
        
        // Option + tap on symbol = assign mode (keyboard shortcut)
        if modifierKeys.isOptionPressed {
            if let symbol = findSymbol(at: point) {
                enterAssignmentMode(for: symbol)
                return
            }
        }
        
        // Placing a symbol from assigned key
        if case .placingSymbol(let key) = drawingMode {
            if let template = symbolKeyMap[key] {
                placeSymbol(template: template, at: point)
            }
            return
        }
        
        // Symbol mode (toggled or Command key)
        if isSymbolModeToggled || modifierKeys.isCommandPressed {
            symbolDrawingStartedWithCommand = true
            symbolStartPoint = point
            currentPath = DrawingPath(points: [point])
            commandReleasedDuringSymbolDrawing = false
        }
        // Arrow mode (default)
        else {
            currentArrowStart = point
            currentPath = DrawingPath(points: [point])
        }
    }
    
    func continueDrawing(at point: CGPoint) {
        // Move mode - drag symbol or arrow
        if canvasMode == .move {
            if case .draggingSymbol(let symbolId) = drawingMode,
               let index = symbols.firstIndex(where: { $0.id == symbolId }) {
                symbols[index].position = point
            } else if case .draggingArrow(let arrowId, let offset) = drawingMode,
                      let index = arrows.firstIndex(where: { $0.id == arrowId }) {
                let adjustedPoint = CGPoint(x: point.x - offset.x, y: point.y - offset.y)
                let oldCenter = arrows[index].centerPoint
                let dx = adjustedPoint.x - oldCenter.x
                let dy = adjustedPoint.y - oldCenter.y
                
                arrows[index].startPoint.x += dx
                arrows[index].startPoint.y += dy
                arrows[index].endPoint.x += dx
                arrows[index].endPoint.y += dy
            }
            return
        }
        
        // Erase mode - continue erasing
        if canvasMode == .erase {
            eraseAt(point: point)
            return
        }
        
        // Draw mode
        currentPath.points.append(point)
    }
    
    func endDrawing(at point: CGPoint) {
        // Move mode - end dragging
        if canvasMode == .move {
            drawingMode = .none
            return
        }
        
        // Erase mode - do nothing on end
        if canvasMode == .erase {
            return
        }
        
        // Draw mode
        currentPath.points.append(point)
        
        // 심볼 드로잉 중이었는지 확인
        if symbolDrawingStartedWithCommand {
            // 현재 패스를 심볼 패스에 추가
            if !currentPath.points.isEmpty {
                symbolPathsInProgress.append(currentPath)
            }
            
            // Toggle 모드가 아니고 Command도 안 눌려있으면 심볼 완성
            if !isSymbolModeToggled && !modifierKeys.isCommandPressed {
                createSymbol(paths: symbolPathsInProgress)
                symbolPathsInProgress = []
                symbolDrawingStartedWithCommand = false
                commandReleasedDuringSymbolDrawing = false
                symbolStartPoint = nil
            }
            // Toggle 모드이거나 Command가 눌려있으면 다음 획 대기
        }
        // 화살표 모드였다면
        else if let start = currentArrowStart {
            // Save state before creating arrow
            saveCurrentState()
            
            let arrow = Arrow(
                startPoint: start,
                endPoint: point,
                isBidirectional: modifierKeys.isShiftPressed
            )
            arrows.append(arrow)
            currentArrowStart = nil
        }
        
        currentPath = DrawingPath()
    }
    
    // MARK: - Symbol Management
    private func createSymbol(paths: [DrawingPath]) {
        guard !paths.isEmpty else { return }
        
        // Save state before creating symbol
        saveCurrentState()
        
        // 모든 패스의 점들을 기준으로 중심점 계산
        var allPoints: [CGPoint] = []
        for path in paths {
            allPoints.append(contentsOf: path.points)
        }
        
        guard !allPoints.isEmpty else { return }
        
        // 바운딩 박스 계산
        let minX = allPoints.map { $0.x }.min() ?? 0
        let minY = allPoints.map { $0.y }.min() ?? 0
        let maxX = allPoints.map { $0.x }.max() ?? 0
        let maxY = allPoints.map { $0.y }.max() ?? 0
        
        let width = maxX - minX
        let height = maxY - minY
        
        // 정사각형의 중심점
        let centerX = minX + width / 2
        let centerY = minY + height / 2
        
        // 패스들을 중심점 기준으로 변환 (원점이 중심이 되도록)
        let normalizedPaths = paths.map { path -> DrawingPath in
            var newPath = path
            newPath.points = path.points.map { point in
                CGPoint(x: point.x - centerX, y: point.y - centerY)
            }
            return newPath
        }
        
        // 심볼의 position을 바운딩 박스의 중심으로 설정
        let symbol = FlowSymbol(
            position: CGPoint(x: centerX, y: centerY),
            paths: normalizedPaths
        )
        symbols.append(symbol)
    }
    
    private func enterAssignmentMode(for symbol: FlowSymbol) {
        drawingMode = .assigningSymbol(symbol)
        selectedSymbolForAssignment = symbol
        showAssignmentPrompt = true
    }
    
    private func cancelAssignment() {
        drawingMode = .none
        showAssignmentPrompt = false
        selectedSymbolForAssignment = nil
        isAssignModeActive = false
    }
    
    private func unassignSymbol(_ symbol: FlowSymbol) {
        let symbolId = symbol.id
        
        // Remove from keyMap
        if let oldKey = symbol.assignedKey {
            symbolKeyMap.removeValue(forKey: oldKey)
        }
        
        // Update all symbols with the same ID
        for index in symbols.indices {
            if symbols[index].id == symbolId {
                symbols[index].assignedKey = nil
            }
        }
        
        // Close assignment prompt
        cancelAssignment()
        
        print("✅ Symbol unassigned")
    }
    
    private func assignSymbolToKey(symbol: FlowSymbol, key: String) {
        let normalizedKey = key.lowercased()
        
        // Z and Y are reserved for undo/redo
        if normalizedKey == "z" || normalizedKey == "y" {
            print("❌ Key '\(normalizedKey)' is reserved for undo/redo")
            return
        }
        
        // Check if key is alphanumeric (allow both lowercase and uppercase)
        let alphanumericSet = CharacterSet.alphanumerics
        guard normalizedKey.count == 1,
              let scalar = normalizedKey.unicodeScalars.first,
              alphanumericSet.contains(scalar) else {
            print("❌ Invalid key: '\(key)' - must be a single alphanumeric character")
            return
        }
        
        print("✅ Assigning symbol to key: '\(normalizedKey)'")
        
        // Remove old key mapping if this symbol had a different key assigned
        if let oldKey = symbol.assignedKey {
            symbolKeyMap.removeValue(forKey: oldKey)
        }
        
        // Update ALL symbols with the same ID
        let symbolId = symbol.id
        var updatedSymbol: FlowSymbol?
        
        for index in symbols.indices {
            if symbols[index].id == symbolId {
                symbols[index].assignedKey = normalizedKey
                updatedSymbol = symbols[index]
                print("✅ Updated symbol at index \(index)")
            }
        }
        
        // Store the updated symbol as template
        if let updated = updatedSymbol {
            symbolKeyMap[normalizedKey] = updated
            print("✅ Symbol assigned! KeyMap now has: \(symbolKeyMap.keys)")
        }
        
        // Turn off assign mode if it was toggled
        isAssignModeActive = false
        
        drawingMode = .none
        showAssignmentPrompt = false
        selectedSymbolForAssignment = nil
    }
    
    private func startPlacingSymbol(key: String) {
        drawingMode = .placingSymbol(key)
    }
    
    private func placeSymbol(template: FlowSymbol, at point: CGPoint) {
        // Save state before placing symbol
        saveCurrentState()
        
        // Create a new symbol with the same ID as the template
        let newSymbol = FlowSymbol(
            id: template.id,  // Use the same ID
            position: point,
            paths: template.paths,
            assignedKey: template.assignedKey
        )
        symbols.append(newSymbol)
        drawingMode = .none
    }
    
    private func findSymbol(at point: CGPoint) -> FlowSymbol? {
        // Find symbols in reverse order (top to bottom)
        return symbols.reversed().first { symbol in
            symbol.contains(point: point)
        }
    }
    
    private func findArrow(at point: CGPoint) -> Arrow? {
        return arrows.reversed().first { arrow in
            arrow.contains(point: point)
        }
    }
    
    // MARK: - Symbol Dragging
    func startDraggingSymbol(at point: CGPoint) {
        if let symbol = findSymbol(at: point) {
            drawingMode = .draggingSymbol(symbol.id)
        }
    }
    
    func dragSymbol(to point: CGPoint) {
        if case .draggingSymbol(let symbolId) = drawingMode,
           let index = symbols.firstIndex(where: { $0.id == symbolId }) {
            symbols[index].position = point
        }
    }
    
    func endDraggingSymbol() {
        drawingMode = .none
    }
    
    // MARK: - Auto-organize (placeholder for future implementation)
    func autoOrganizeFlowchart() {
        // TODO: Implement automatic flowchart organization
        // This will analyze arrow connections and rearrange symbols
        print("Auto-organizing flowchart...")
    }
    
    // MARK: - Clear Canvas
    func clearCanvas() {
        saveCurrentState()
        
        arrows.removeAll()
        symbols.removeAll()
        symbolKeyMap.removeAll()
        currentPath = DrawingPath()
        drawingMode = .none
        symbolPathsInProgress = []
        symbolDrawingStartedWithCommand = false
        commandReleasedDuringSymbolDrawing = false
    }
    
    // MARK: - History Management
    private func saveCurrentState() {
        let state = CanvasState(
            arrows: arrows,
            symbols: symbols,
            symbolKeyMap: symbolKeyMap
        )
        historyManager.saveState(state)
    }
    
    func undo() {
        let currentState = CanvasState(
            arrows: arrows,
            symbols: symbols,
            symbolKeyMap: symbolKeyMap
        )
        
        guard let previousState = historyManager.undo(currentState: currentState) else {
            return
        }
        
        restoreState(previousState)
    }
    
    func redo() {
        let currentState = CanvasState(
            arrows: arrows,
            symbols: symbols,
            symbolKeyMap: symbolKeyMap
        )
        
        guard let nextState = historyManager.redo(currentState: currentState) else {
            return
        }
        
        restoreState(nextState)
    }
    
    private func restoreState(_ state: CanvasState) {
        arrows = state.arrows
        symbols = state.symbols
        symbolKeyMap = state.symbolKeyMap
    }
    
    // MARK: - Canvas Transform
    func updateCanvasScale(_ scale: CGFloat) {
        canvasScale = max(0.5, min(3.0, scale))
    }
    
    func handlePinchChanged(_ scale: CGFloat) {
        let newScale = baseScale * scale
        canvasScale = newScale
    }
    
    func handlePinchEnded(_ scale: CGFloat) {
        baseScale = canvasScale
    }
    
    func updateCanvasOffset(_ translation: CGPoint) {
        canvasOffset.x += translation.x
        canvasOffset.y += translation.y
    }
    
    func resetCanvasTransform() {
        canvasScale = 1.0
        canvasOffset = .zero
        baseScale = 1.0
    }
    
    // Transform screen point to canvas point
    func screenToCanvas(_ screenPoint: CGPoint, screenSize: CGSize) -> CGPoint {
        let centerX = screenSize.width / 2
        let centerY = screenSize.height / 2
        
        // Translate to center
        var x = screenPoint.x - centerX
        var y = screenPoint.y - centerY
        
        // Remove offset
        x -= canvasOffset.x
        y -= canvasOffset.y
        
        // Apply inverse scale
        x /= canvasScale
        y /= canvasScale
        
        // Translate back
        x += centerX
        y += centerY
        
        return CGPoint(x: x, y: y)
    }
    
    // Transform canvas point to screen point
    func canvasToScreen(_ canvasPoint: CGPoint, screenSize: CGSize) -> CGPoint {
        let centerX = screenSize.width / 2
        let centerY = screenSize.height / 2
        
        // Translate to center
        var x = canvasPoint.x - centerX
        var y = canvasPoint.y - centerY
        
        // Apply scale
        x *= canvasScale
        y *= canvasScale
        
        // Apply offset
        x += canvasOffset.x
        y += canvasOffset.y
        
        // Translate back
        x += centerX
        y += centerY
        
        return CGPoint(x: x, y: y)
    }
}
