//
//  FlowchartHistory.swift
//  botherless
//
//  Created by Yeonjun Lee on 10/17/25.
//

import Foundation

// MARK: - Canvas State
struct CanvasState: Codable {
    var arrows: [Arrow]
    var symbols: [FlowSymbol]
    var symbolKeyMap: [String: FlowSymbol]
    
    init(arrows: [Arrow], symbols: [FlowSymbol], symbolKeyMap: [String: FlowSymbol]) {
        self.arrows = arrows
        self.symbols = symbols
        self.symbolKeyMap = symbolKeyMap
    }
}

// MARK: - History Manager
class HistoryManager: ObservableObject {
    @Published var canUndo: Bool = false
    @Published var canRedo: Bool = false
    
    private var undoStack: [CanvasState] = []
    private var redoStack: [CanvasState] = []
    private let maxHistorySize = 50
    
    func saveState(_ state: CanvasState) {
        // Clear redo stack when new action is performed
        redoStack.removeAll()
        
        // Add current state to undo stack
        undoStack.append(state)
        
        // Limit history size
        if undoStack.count > maxHistorySize {
            undoStack.removeFirst()
        }
        
        updateFlags()
    }
    
    func undo(currentState: CanvasState) -> CanvasState? {
        guard !undoStack.isEmpty else { return nil }
        
        // Save current state to redo stack
        redoStack.append(currentState)
        
        // Get previous state
        let previousState = undoStack.removeLast()
        
        updateFlags()
        return previousState
    }
    
    func redo(currentState: CanvasState) -> CanvasState? {
        guard !redoStack.isEmpty else { return nil }
        
        // Save current state to undo stack
        undoStack.append(currentState)
        
        // Get next state
        let nextState = redoStack.removeLast()
        
        updateFlags()
        return nextState
    }
    
    func clear() {
        undoStack.removeAll()
        redoStack.removeAll()
        updateFlags()
    }
    
    private func updateFlags() {
        canUndo = !undoStack.isEmpty
        canRedo = !redoStack.isEmpty
    }
}
