//
//  InputHelper.swift
//

#if os(iOS)

import UIKit

fileprivate extension UIView.AnimationOptions {
    init(curve: UIView.AnimationCurve) {
        switch curve {
            case .easeIn: self = .curveEaseIn
            case .easeOut: self = .curveEaseOut
            case .easeInOut: self = .curveEaseInOut
            default: self = .curveLinear
        }
    }
}

@objc public protocol Input: AnyObject { }

public protocol ValidatableInput: Input {
    
    func set(failedValidation: Bool)
}

public protocol CustomInput: Input {
    
    var didChange: (()->())? { get set }
    var didSelectNext: (()->())? { get set }
}

extension UITextView: Input { }

extension UITextField: Input { }

public protocol InputHelperDelegate: AnyObject {
    
    func isValid(input: Input) -> Bool
    
    // performed during keyboard animation
    func customInsets(original: UIEdgeInsets) -> UIEdgeInsets
    
    // performed during keyboard animation
    func animateInsetChange(insets: UIEdgeInsets)
    
    // performed when input is not a descendant of scroll view (in table view cell off screen)
    func scrollTo(input: Input)
}

public extension InputHelperDelegate {
    
    func isValid(input: Input) -> Bool { true }
    
    func customInsets(original: UIEdgeInsets) -> UIEdgeInsets { original }
    
    func animateInsetChange(insets: UIEdgeInsets) { }
    
    func scrollTo(input: Input) { }
}

public class InputHelper: NSObject, UIGestureRecognizerDelegate {
    
    // Attach content offset to the bottom of visible area when keyboard appears
    public var attachToBottom: Bool = false
    
    private weak var delegate: InputHelperDelegate?
    public private(set) weak var scrollView: UIScrollView?
    public lazy var tapGR: UIGestureRecognizer = {
        let tapGR = UITapGestureRecognizer(target: self, action: #selector(tapAction(_:)))
        tapGR.delegate = self
        tapGR.cancelsTouchesInView = false
        tapGR.isEnabled = false
        return tapGR
    }()
    
    public var inputs: [[Input]] = [] {
        didSet {
            oldValue.forEach {
                $0.forEach { unselect(input: $0) }
            }
            inputs.forEach { subInputs in
                subInputs.enumerated().forEach { index, input in
                    select(input: input, last: subInputs.count - 1 == index )
                }
            }
        }
    }
    
    public var additionalBottomInset: CGFloat = 0 {
        didSet {
            guard let scrollView = scrollView else { return }
            
            let offset = oldValue - additionalBottomInset
            
            var contentOffset = scrollView.contentOffset
            contentOffset.y -= offset
            scrollView.contentOffset = contentOffset
            
            var inset = scrollView.contentInset
            inset.bottom -= offset
            scrollView.contentInset = inset
            
            inset = scrollView.verticalScrollIndicatorInsets
            inset.bottom -= offset
            scrollView.verticalScrollIndicatorInsets = inset
        }
    }
    
    public init(scrollView: UIScrollView, delegate: InputHelperDelegate? = nil) {
        self.scrollView = scrollView
        self.delegate = delegate
        super.init()
        scrollView.addGestureRecognizer(tapGR)
        
        NotificationCenter.default.addObserver(self, selector: #selector(willChangeFrame(_:)), name: UIApplication.keyboardWillChangeFrameNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(didChangeTextView(_:)), name: UITextView.textDidChangeNotification, object: nil)
    }
    
    @objc private func willChangeFrame(_ notification: Notification) {
        guard let scrollView = scrollView else { return }
        
        let duration = notification.userInfo?[UIWindow.keyboardAnimationDurationUserInfoKey] as? Double ?? 0
        let curve = notification.userInfo?[UIWindow.keyboardAnimationCurveUserInfoKey] as? UIView.AnimationCurve ?? .linear
        let keyboardFrame = notification.userInfo?[UIWindow.keyboardFrameEndUserInfoKey] as? CGRect ?? .zero
        
        var bottomOffset: CGFloat = 0
        
        if keyboardFrame.minY + keyboardFrame.height >= UIScreen.main.bounds.height, var topView = scrollView.superview {
            bottomOffset = UIScreen.main.bounds.height - keyboardFrame.minY
            
            while topView.superview != nil {
                topView = topView.superview!
            }
            
            let viewRect = scrollView.convert(scrollView.bounds, to: topView)
            let viewBottomOffset = UIScreen.main.bounds.height - (viewRect.minY + viewRect.height) + scrollView.safeAreaInsets.bottom
            
            bottomOffset = max(0, bottomOffset - viewBottomOffset)
            
            UIView.animate(withDuration: duration, delay: 0, options: .init(curve: curve)) {
                
                let insetOffset = bottomOffset + self.additionalBottomInset - scrollView.contentInset.bottom
                
                if insetOffset < 0 { // keyboard hides
                    var point = scrollView.contentOffset
                    
                    if self.attachToBottom {
                        point.y += insetOffset
                    }
                    if point.y != scrollView.contentOffset.y {
                        scrollView.contentOffset = point
                    }
                }
                
                let originalInset = scrollView.contentInset
                var inset = originalInset
                inset.bottom = bottomOffset + self.additionalBottomInset
                scrollView.contentInset = inset
                
                inset = scrollView.verticalScrollIndicatorInsets
                inset.bottom = bottomOffset + self.additionalBottomInset
                scrollView.verticalScrollIndicatorInsets = inset
                
                scrollView.layoutIfNeeded()
                let offset = scrollView.contentOffset
                self.delegate?.animateInsetChange(insets: originalInset)
                scrollView.contentOffset = offset
                
                if insetOffset > 0 { // keyboard shows
                    var point = scrollView.contentOffset
                    
                    if self.attachToBottom {
                        point.y += max(0, insetOffset - max(0, (scrollView.height - scrollView.safeAreaInsets.top - scrollView.safeAreaInsets.bottom - scrollView.contentSize.height - self.additionalBottomInset - scrollView.contentInset.top)))
                    }
                    
                    if point.y != scrollView.contentOffset.y {
                        scrollView.contentOffset = point
                    }
                }
                
                if bottomOffset != 0 {
                    self.tapGR.isEnabled = true
                    
                    if let input = self.currentInput {
                        self.scrollTo(input: input)
                    }
                } else {
                    self.tapGR.isEnabled = false
                }
            }
        }
    }
    
    var currentInput: Input? {
        for array in inputs {
            for input in array {
                if (input as? UIResponder)?.isFirstResponder == true {
                    return input
                }
            }
        }
        return nil
    }
    
    @objc private func didChangeTextView(_ notification: Notification) {
        if let textView = notification.object as? UITextView,
           inputs.contains(where: { $0.contains { $0 as? UITextView == textView } }) {
                inputDidChange(textView)
        }
    }
    
    @objc private func tapAction(_ gr: UITapGestureRecognizer) {
        scrollView?.superview?.endEditing(true)
    }
    
    private func unselect(input: Input) {
        if let input = input as? CustomInput {
            input.didChange = nil
            input.didSelectNext = nil
        } else if let input = input as? UITextField {
            input.removeTarget(self, action: #selector(nextAction(_:)), for: .editingDidEndOnExit)
            input.removeTarget(self, action: #selector(inputDidChange(_:)), for: .editingChanged)
        }
    }
    
    private func select(input: Input, last: Bool) {
        if let input = input as? CustomInput {
            input.didChange = { [weak self, weak input] in
                if let input = input {
                    self?.inputDidChange(input)
                }
            }
            input.didSelectNext = { [weak self, weak input] in
                if let input = input {
                    self?.nextAction(input)
                }
            }
        } else if let input = input as? UITextField {
            input.addTarget(self, action: #selector(nextAction(_:)), for: .editingDidEndOnExit)
            input.addTarget(self, action: #selector(inputDidChange(_:)), for: .editingChanged)
            if last {
                input.returnKeyType = .done
            }
        }
    }
    
    @objc private func nextAction(_ input: Input) {
        for array in inputs {
            if var index = array.firstIndex(where: { $0 === input }) {
                index += 1
                
                if index < array.count, let next = array[index] as? UIResponder {
                    next.becomeFirstResponder()
                    delegate?.scrollTo(input: array[index])
                } else {
                    scrollView?.endEditing(true)
                }
                return
            }
        }
    }
    
    @objc private func inputDidChange(_ input: Input) {
        if let input = input as? ValidatableInput {
            input.set(failedValidation: false)
        }
    }
    
    public func validateInputs(section: Int) -> Bool {
        var result = true
        var firstFailedInput: Input?
        
        inputs[section].forEach {
            let inputResult = delegate?.isValid(input: $0) ?? true
            
            if result {
                result = inputResult
            }
            
            if !inputResult && firstFailedInput == nil {
                firstFailedInput = $0
            }
        }
        
        if let input = firstFailedInput {
            scrollTo(input: input)
        }
        return result
    }
    
    public func validateInputs() -> Bool {
        var result = true
        for index in 0..<inputs.count {
            if !validateInputs(section: index) && result {
                result = false
            }
        }
        return result
    }
    
    private func scrollTo(input: Input) {
        guard let scrollView = scrollView else { return }
        
        if let input = input as? UIView, input.isDescendant(of: scrollView) {
            scrollView.scrollRectToVisible(scrollView.convert(input.bounds, from: input), animated: true)
        } else {
            delegate?.scrollTo(input: input)
        }
    }
    
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        touch.view as? UIControl == nil && touch.view?.isFirstResponder == false
    }
    
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        true
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

#endif
