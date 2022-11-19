//
//  ContainerCollectionCell.swift
//

#if os(iOS)

import UIKit

public class ContainerCollectionCell: UICollectionViewCell {
    
    open var untouchable = false
    open var attachedView: UIView? { contentView.subviews.last }
    
    func attach(view: UIView) {
        if view == attachedView { return }
        
        contentView.subviews.forEach { $0.removeFromSuperview() }
        contentView.frame = bounds
        contentView.attach(view)
    }
    
    override open func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if let view = super.hitTest(point, with: event) {
            return (untouchable && (view == self || view == contentView)) ? nil : view
        }
        return nil
    }
}

#endif
