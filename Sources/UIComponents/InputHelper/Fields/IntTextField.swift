//
//  IntTextField.swift
//

import UIKit

public class IntTextField: ValidatableField {

    private var originalValue: Int = 0
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
    
    public func setup() {
        keyboardType = .numberPad
        addTarget(self, action: #selector(didStartEditing), for: .editingDidBegin)
        addTarget(self, action: #selector(didEndEditing), for: .editingDidEnd)
    }
    
    @objc public func didStartEditing() {
        originalValue = intValue()
        if originalValue == 0 {
            self.text = ""
        } else {
            self.text = "\(originalValue)".replacingOccurrences(of: " ", with: "")
        }
    }
    
    public var customizeValue: ((Int)->(Int))?
    public var formatValue: ((String)->(String))?
    
    @objc public func didEndEditing() {
        if text?.isEmpty ?? true == true {
            originalValue = 0
            return
        }
        
        var value = intValue()
        if let customize = customizeValue {
            value = customize(value)
        }
        let result = "\(value)"
        
        text = formatValue?(result) ?? result
    }
    
    public func intValue() -> Int {
        if let text = self.text?.components(separatedBy: CharacterSet(charactersIn: "0123456789").inverted).joined(separator: ""), !text.isEmpty, let value = Int(text) {
            return value
        } else {
            return originalValue
        }
    }
    
    public func set(intValue: Int) {
        let result = "\(intValue)"
        text = formatValue?(result) ?? result
    }
}
