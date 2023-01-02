//
//  FailedView.swift
//

import UIKit

open class FailedView: UIView {
    
    @IBOutlet open var textLabel: UILabel!
    @IBOutlet open var retryButton: BorderedButton!
    
    private var retry: (()->())? {
        didSet {
            if retryButton != nil {
                retryButton.isHidden = retry == nil
            }
        }
    }
    
    open func present(in view: UIView, text: String, retry: (()->())?) {
        if superview == view { return }
        
        frame = view.bounds
        textLabel.text = text
        self.retry = retry
        view.attach(self)
        configure()
    }
    
    open func configure() { }
    
    @IBAction private func retryAction(_ sender: UIButton) {
        retry?()
    }
}
