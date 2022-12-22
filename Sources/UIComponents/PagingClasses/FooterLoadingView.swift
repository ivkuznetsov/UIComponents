//
//  FooterLoadingView.swift
//

import UIKit

public enum FooterState {
    case stop
    case loading
    case failed
}

open class FooterLoadingView: UIView {
    
    open override func awakeFromNib() {
        super.awakeFromNib()
        retryButton.isHidden = true
    }
    
    open var state: FooterState = .stop {
        didSet {
            if state != oldValue {
                switch state {
                case .stop:
                    indicatorView.stopAnimating()
                    retryButton.isHidden = true
                case .loading:
                    indicatorView.startAnimating()
                    retryButton.isHidden = true
                case .failed:
                    indicatorView.stopAnimating()
                    retryButton.isHidden = false
                }
            }
        }
    }
    
    open var retry: (()->())?
    
    @IBOutlet open var indicatorView: UIActivityIndicatorView!
    @IBOutlet open var retryButton: UIButton!
    
    @IBAction private func retryAction(_ sender: UIButton) {
        retry?()
    }
}
