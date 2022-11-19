//
//  ValidatableField.swift
//

#if os(iOS)

import UIKit

open class ValidatableField: UITextField, ValidatableInput {

    public struct Result {
        public let success: Bool
        public let error: String?
        
        public init(success: Bool, error: String?) {
            self.success = success
            self.error = error
        }
    }
    
    public var textLimit: Int?
    
    private var oldColor: UIColor?
    @IBOutlet public weak var failedView: UIView? {
        didSet {
            oldColor = failedView?.backgroundColor
        }
    }
    
    public var validator: ((ValidatableField)->Result)?
    
    public var validationFailed: Bool = false {
        didSet {
            if oldValue != validationFailed {
                failedView?.backgroundColor = validationFailed ? UIColor(red: 1, green: 0, blue: 0, alpha: 0.1) : oldColor
                failedView?.addFadeTransition()
            }
        }
    }
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
        addTarget(self, action: #selector(textDidChange), for: .editingChanged)
    }
    
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    @objc private func textDidChange() {
        if let textLimit = textLimit, let text = text, text.count > textLimit {
            self.text = String(text.prefix(textLimit))
        }
    }
}

#endif
