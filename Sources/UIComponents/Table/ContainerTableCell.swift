//
//  ContainerTableCell.swift
//

#if os(iOS)

import UIKit

public class ContainerTableCell: BaseTableViewCell {
    
    override open func prepareForReuse() {
        super.prepareForReuse()
        contentView.subviews.forEach { $0.removeFromSuperview() }
    }
    
    func attach(view: UIView, type: UIView.AttachType) {
        if contentView.subviews.last == view { return }
        
        backgroundColor = .clear
        selectionStyle = .none
        contentView.attach(view, type: type)
    }
}

#endif
