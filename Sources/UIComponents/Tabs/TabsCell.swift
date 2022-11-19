//
//  TabsCell.swift
//

#if os(iOS)

import UIKit

@objc open class TabsCell: UIView {
    
    public enum Layout {
        case fillWidth
        case centerEqually
        case scrollable
    }
    
    @IBOutlet private var scrollView: UIScrollView!
    
    private var layout: Layout = .centerEqually
    public private(set) var tabsView: TabsView! {
        didSet {
            tabsView.translatesAutoresizingMaskIntoConstraints = false
            scrollView.insertSubview(tabsView, at: 0)
            
            tabsView.topAnchor.constraint(equalTo: topAnchor).isActive = true
            let bottom = tabsView.bottomAnchor.constraint(equalTo: bottomAnchor)
            bottom.priority = UILayoutPriority(900)
            bottom.isActive = true
            
            if layout == .fillWidth {
                tabsView.leftAnchor.constraint(equalTo: leftAnchor).isActive = true
                let right = tabsView.rightAnchor.constraint(equalTo: rightAnchor)
                right.priority = UILayoutPriority(900)
                right.isActive = true
            } else if layout == .centerEqually {
                self.addConstraint(NSLayoutConstraint(item: tabsView!, attribute: .centerX, relatedBy: .equal, toItem: self, attribute: .centerX, multiplier: 1, constant: 0))
            } else if layout == .scrollable {
                tabsView.leftAnchor.constraint(equalTo: scrollView.leftAnchor, constant: 15).isActive = true
                tabsView.rightAnchor.constraint(equalTo: scrollView.rightAnchor, constant: -15).isActive = true
                tabsView.stackView.distribution = .equalSpacing
                tabsView.stackView.spacing = 15
            }
        }
    }
    
    open class func make(titles: [String], style: ((TabsViewButton)->())? = nil, layout: Layout = .centerEqually, action: @escaping (Int)->()) -> Self {
        let view = self.loadFromNib()
        view.layout = layout
        view.tabsView = TabsView(titles: titles, style: style, didSelect: { (button, animated) in
            action(button.tag)
        })
        return view
    }
}

#endif
