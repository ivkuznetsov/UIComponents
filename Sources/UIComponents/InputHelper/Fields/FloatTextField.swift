//
//  FloatTextField.swift
//

import UIKit

public class FloatTextField: ValidatableField {
    
    private var originalValue: Double = 0
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
    
    public func setup() {
        keyboardType = .numbersAndPunctuation
        addTarget(self, action: #selector(didStartEditing), for: .editingDidBegin)
        addTarget(self, action: #selector(didEndEditing), for: .editingDidEnd)
    }
    
    @objc public func didStartEditing() {
        originalValue = doubleValue()
        var text = self.text?.replacingOccurrences(of: ",", with: ".")
        text = text?.components(separatedBy: CharacterSet(charactersIn: "0123456789.").inverted).joined(separator: "")
        if let text = text, let value = Double(text) {
            if value == 0 {
                self.text = ""
            } else {
                self.text = "\(value)".replacingOccurrences(of: ",", with: ".").replacingOccurrences(of: " ", with: "")
            }
        }
    }
    
    public var customizeValue: ((Double)->(Double))?
    public var precision: Int = 1
    public var formatValue: ((String)->(String))?
    
    @objc public func didEndEditing() {
        var value = doubleValue()
        if let customize = customizeValue {
            value = customize(value)
        }
        let result = String(format: "%.\(precision)f", value)
        
        text = formatValue?(result) ?? result
    }
    
    public func doubleValue() -> Double {
        var text = self.text?.replacingOccurrences(of: ",", with: ".") ?? ""
        text = text.components(separatedBy: CharacterSet(charactersIn: "0123456789.").inverted).joined(separator: "")
        
        if !text.isEmpty, let value = Double(text) {
            return value
        } else {
            return originalValue
        }
    }
    
    public func set(doubleValue: Double) {
        let result = String(format: "%.\(precision)f", doubleValue)
        text = formatValue?(result) ?? result
    }
}
