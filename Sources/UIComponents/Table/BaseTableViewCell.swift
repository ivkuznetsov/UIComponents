//
//  BaseTableViewCell.swift
//

#if os(iOS)

import UIKit

public protocol ObjectHolder: AnyObject {
    
    var object: AnyHashable? { get set }
}

public extension UITableViewCell {
    
    var separatorHidden: Bool {
        set { separatorViews.forEach { $0.isHidden = newValue } }
        get { separatorViews.first?.isHidden ?? true }
    }
    
    private var separatorViews: [UIView] {
        subviews.filter { String(describing: type(of: $0)).contains("SeparatorView") }
    }
}

open class BaseTableViewCell: UITableViewCell, ObjectHolder {
    
    public var object: AnyHashable?
    
    open override func awakeFromNib() {
        super.awakeFromNib()
        selectedBackgroundView = UIView()
        selectedBackgroundView?.backgroundColor = UIColor(white: 0.5, alpha: 0.1)
    }
    
    open override func layoutSubviews() {
        super.layoutSubviews()
        self.separatorHidden = separatorHidden
    }
    
    open override func setHighlighted(_ highlighted: Bool, animated: Bool) {
        super.setHighlighted(highlighted, animated: animated)
        reloadSelection(animated: animated)
    }
    
    open override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        reloadSelection(animated: animated)
    }
    
    open func reloadSelection(animated: Bool) { }
}

#endif
