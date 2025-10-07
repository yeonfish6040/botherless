//
//  KeyAwareCanvasView.swift
//  botherless
//
//  Created by Yeonjun Lee on 10/17/25.
//

import UIKit
import Combine
import SwiftUI

// MARK: - Interactive Canvas View with Gestures
final class InteractiveCanvasView: UIView, UIPencilInteractionDelegate {
    var onModifierChanged: ((UIKeyModifierFlags) -> Void)?
    var onKeyPressed: ((String) -> Void)?
    var onKeyReleased: ((String) -> Void)?
    
    var onTouchBegan: ((CGPoint) -> Void)?
    var onTouchMoved: ((CGPoint) -> Void)?
    var onTouchEnded: ((CGPoint) -> Void)?
    
    var onPinchChanged: ((CGFloat) -> Void)?
    var onPinchEnded: ((CGFloat) -> Void)?
    
    var onPanChanged: ((CGPoint) -> Void)?
    var onPanEnded: (() -> Void)?
    var onDoubleTap: (() -> Void)?
    
    var isPencilOnlyMode: Bool = true
    
    private var activeModifiers: UIKeyModifierFlags = []
    private var initialPinchScale: CGFloat = 1.0
    private var isDrawing = false
    
    override var canBecomeFirstResponder: Bool { true }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupGestures()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupGestures()
    }
    
    private func setupGestures() {
        // Pinch gesture for zoom
        let pinchGesture = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        pinchGesture.delegate = self
        addGestureRecognizer(pinchGesture)
        
        // Pan gesture for panning (two fingers)
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        panGesture.minimumNumberOfTouches = 2
        panGesture.maximumNumberOfTouches = 2
        panGesture.delegate = self
        addGestureRecognizer(panGesture)
        
        let pencilInteraction = UIPencilInteraction()
        pencilInteraction.delegate = self
        addInteraction(pencilInteraction)
    }
    
    @objc private func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
        if gesture.state == .recognized {
            onDoubleTap?()
        }
    }
    
    @objc private func handlePinch(_ gesture: UIPinchGestureRecognizer) {
        switch gesture.state {
        case .began:
            initialPinchScale = gesture.scale
        case .changed:
            onPinchChanged?(gesture.scale)
        case .ended, .cancelled:
            onPinchEnded?(gesture.scale)
            initialPinchScale = 1.0
        default:
            break
        }
    }
    
    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        let translation = gesture.translation(in: self)
        
        switch gesture.state {
        case .changed:
            onPanChanged?(translation)
            gesture.setTranslation(.zero, in: self)
        case .ended, .cancelled:
            onPanEnded?()
        default:
            break
        }
    }
    

    // MARK: - UIPencilInteractionDelegate
    func pencilInteractionDidTap(_ interaction: UIPencilInteraction) {
        onDoubleTap?()
    }
    
    // MARK: - Touch Handling for Drawing
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        
        // Check if Pencil-only mode is enabled
        if isPencilOnlyMode && touch.type != .pencil {
            return
        }
        
        let location = touch.location(in: self)
        
        // Check if this is a single finger touch (for drawing)
        if touches.count == 1 && event?.allTouches?.count == 1 {
            isDrawing = true
            onTouchBegan?(location)
        }
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard isDrawing, let touch = touches.first else { return }
        
        // Check if Pencil-only mode is enabled
        if isPencilOnlyMode && touch.type != .pencil {
            return
        }
        
        let location = touch.location(in: self)
        onTouchMoved?(location)
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard isDrawing, let touch = touches.first else { return }
        
        // Check if Pencil-only mode is enabled
        if isPencilOnlyMode && touch.type != .pencil {
            return
        }
        
        let location = touch.location(in: self)
        isDrawing = false
        onTouchEnded?(location)
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        isDrawing = false
    }
    
    // MARK: - Keyboard Handling
    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        for press in presses {
            if let key = press.key {
                // Handle ESC key
                if key.keyCode == .keyboardEscape {
                    onKeyPressed?("ESC")
                }
                // Handle Backspace/Delete key
                else if key.keyCode == .keyboardDeleteOrBackspace {
                    onKeyPressed?("BACKSPACE")
                }
                // Handle modifier keys
                else if !key.modifierFlags.isEmpty {
                    activeModifiers.formUnion(key.modifierFlags)
                    onModifierChanged?(activeModifiers)
                }
                // Handle regular keys
                else {
                    let chars = key.charactersIgnoringModifiers ?? ""
                    let filtered = chars.filter { char in
                        return (char >= "a" && char <= "z") ||
                               (char >= "A" && char <= "Z") ||
                               (char >= "0" && char <= "9")
                    }
                    if !filtered.isEmpty {
                        onKeyPressed?(String(filtered))
                    }
                }
            }
        }
        super.pressesBegan(presses, with: event)
    }
    
    override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        for press in presses {
            if let key = press.key {
                if !key.modifierFlags.isEmpty {
                    activeModifiers.subtract(key.modifierFlags)
                    onModifierChanged?(activeModifiers)
                } else {
                    let chars = key.charactersIgnoringModifiers ?? ""
                    let filtered = chars.filter { char in
                        return (char >= "a" && char <= "z") ||
                               (char >= "A" && char <= "Z") ||
                               (char >= "0" && char <= "9")
                    }
                    if !filtered.isEmpty {
                        onKeyReleased?(String(filtered))
                    }
                }
            }
        }
        super.pressesEnded(presses, with: event)
    }
    
    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil {
            becomeFirstResponder()
        }
    }
}

// MARK: - UIGestureRecognizerDelegate
extension InteractiveCanvasView: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
}

// MARK: - SwiftUI Wrapper
struct InteractiveCanvas: UIViewRepresentable {
    let onModifierChanged: ((UIKeyModifierFlags) -> Void)?
    let onKeyPressed: ((String) -> Void)?
    let onKeyReleased: ((String) -> Void)?
    let onTouchBegan: ((CGPoint) -> Void)?
    let onTouchMoved: ((CGPoint) -> Void)?
    let onTouchEnded: ((CGPoint) -> Void)?
    let onPinchChanged: ((CGFloat) -> Void)?
    let onPinchEnded: ((CGFloat) -> Void)?
    let onPanChanged: ((CGPoint) -> Void)?
    let onPanEnded: (() -> Void)?
    let onDoubleTap: (() -> Void)?
    let isPencilOnlyMode: Bool
    
    func makeUIView(context: Context) -> InteractiveCanvasView {
        let view = InteractiveCanvasView()
        view.backgroundColor = .clear
        view.onModifierChanged = onModifierChanged
        view.onKeyPressed = onKeyPressed
        view.onKeyReleased = onKeyReleased
        view.onTouchBegan = onTouchBegan
        view.onTouchMoved = onTouchMoved
        view.onTouchEnded = onTouchEnded
        view.onPinchChanged = onPinchChanged
        view.onPinchEnded = onPinchEnded
        view.onPanChanged = onPanChanged
        view.onPanEnded = onPanEnded
        view.onDoubleTap = onDoubleTap
        view.isPencilOnlyMode = isPencilOnlyMode
        return view
    }
    
    func updateUIView(_ uiView: InteractiveCanvasView, context: Context) {
        uiView.onModifierChanged = onModifierChanged
        uiView.onKeyPressed = onKeyPressed
        uiView.onKeyReleased = onKeyReleased
        uiView.onTouchBegan = onTouchBegan
        uiView.onTouchMoved = onTouchMoved
        uiView.onTouchEnded = onTouchEnded
        uiView.onPinchChanged = onPinchChanged
        uiView.onPinchEnded = onPinchEnded
        uiView.onPanChanged = onPanChanged
        uiView.onPanEnded = onPanEnded
        uiView.onDoubleTap = onDoubleTap
        uiView.isPencilOnlyMode = isPencilOnlyMode
    }
}
