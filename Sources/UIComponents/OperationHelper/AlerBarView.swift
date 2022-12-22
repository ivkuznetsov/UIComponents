//
//  AlerBarView.swift
//

import UIKit

open class AlertBarView: UIView {
    
    @IBOutlet private var textLabel: UILabel!
    open var dismissTime: TimeInterval = 5
    
    open func present(in view: UIView, message: String) {
        translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(self)
        view.leftAnchor.constraint(equalTo: leftAnchor).isActive = true
        view.rightAnchor.constraint(equalTo: rightAnchor).isActive = true
        
        let next = view.next
        if let next = next as? UIViewController {
            next.view.safeAreaLayoutGuide.topAnchor.constraint(equalTo: topAnchor).isActive = true
        } else if next as? UIView != nil {
            view.topAnchor.constraint(equalTo: topAnchor).isActive = true
        }
        
        textLabel.text = message
        alpha = 0
        textLabel.superview?.transform = CGAffineTransform(translationX: 0, y: -bounds.size.height)
        UIView.animate(withDuration: 0.25) {
            self.textLabel.superview?.transform = .identity
            self.alpha = 1
        }
        
        DispatchQueue.main.async {
            DispatchQueue.main.asyncAfter(deadline: .now() + self.dismissTime) {
                self.hide()
            }
        }
    }
    
    open func message() -> String { textLabel.text! }
    
    open override func awakeFromNib() {
        super.awakeFromNib()
        textLabel.superview?.layer.cornerRadius = 8.0
    }
    
    open func hide() {
        UIView.animate(withDuration: 0.2, animations: {
            self.alpha = 0.0
        }) { (_) in
            self.removeFromSuperview()
        }
    }
}
