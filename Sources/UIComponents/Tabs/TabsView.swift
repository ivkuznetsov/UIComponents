//
//  TabsView.swift
//

#if os(iOS)

import UIKit

open class TabsView: UIView {
    
    public let stackView: UIStackView = {
        let view = UIStackView()
        view.axis = .horizontal
        view.distribution = .fillEqually
        return view
    }()
    
    public let backgroundView: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        return view
    }()
    
    private let selectedView = UIView()
    private let didSelect: (UIButton, Bool)->()
    
    var wasAddedToSuperview: (()->())?
    
    open private(set) var selectedIndex: Int = 0
    
    open var selectorHeight: CGFloat = 2 {
        didSet { setNeedsLayout() }
    }
    
    var buttons: [TabsViewButton] { stackView.arrangedSubviews.sorted { $0.tag < $1.tag } as? [TabsViewButton] ?? [] }
    
    open var hiddenTabs = Set<Int>() {
        didSet {
            if hiddenTabs == oldValue { return }
            
            buttons.enumerated().forEach { index, button in
                button.isHidden = hiddenTabs.contains(index)
            }
            
            if hiddenTabs.contains(selectedIndex), let availableButton = buttons.first(where: { !hiddenTabs.contains($0.tag) }) {
                selectTab(index: availableButton.tag, animated: false)
                didSelect(availableButton, false)
            } else {
                layoutIfNeeded()
                selectedView.frame = selectedFrame
            }
        }
    }
    
    open override var frame: CGRect {
        willSet { stackView.layoutMargins = UIEdgeInsets(top: 0, left: -8, bottom: 0, right: -8) }
    }
    
    public init(titles: [String], style: ((TabsViewButton)->())? = nil, didSelect: @escaping (UIButton, _ animated: Bool)->()) {
        self.didSelect = didSelect
        
        super.init(frame: CGRect.zero)
        
        for (index, title) in titles.enumerated() {
            let button = TabsViewButton(type: .system)
            button.setTitle(title, for: .normal)
            button.titleLabel?.font = UIFont.systemFont(ofSize: 16)
            button.contentEdgeInsets = UIEdgeInsets(top: 10, left: 15, bottom: 10, right: 15)
            button.tintColor = .black
            button.addTarget(self, action: #selector(selectAction(_:)), for: .touchUpInside)
            button.tag = index
            style?(button)
            stackView.addArrangedSubview(button)
        }
        addSubview(stackView)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        widthAnchor.constraint(equalTo: stackView.widthAnchor).isActive = true
        heightAnchor.constraint(equalTo: stackView.heightAnchor, constant: 3).isActive = true
        leftAnchor.constraint(equalTo: stackView.leftAnchor).isActive = true
        topAnchor.constraint(equalTo: stackView.topAnchor).isActive = true
        
        addSubview(backgroundView)
        
        selectedView.backgroundColor = tintColor
        backgroundView.addSubview(selectedView)
    }
    
    open override func didMoveToSuperview() {
        super.didMoveToSuperview()
        if superview != nil {
            wasAddedToSuperview?()
        }
    }
    
    open override var tintColor: UIColor! {
        didSet { selectedView.backgroundColor = tintColor }
    }
    
    public required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    open override func layoutSubviews() {
        super.layoutSubviews()
        backgroundView.frame = CGRect(x: stackView.layoutMargins.left,
                                      y: self.bounds.size.height - selectorHeight,
                                      width: stackView.width - stackView.layoutMargins.left - stackView.layoutMargins.right,
                                      height: selectorHeight)
        selectedView.frame = selectedFrame
    }
    
    private var selectedFrame: CGRect {
        let button = buttons[selectedIndex]
        
        if button.isHidden { return .zero }
        
        let filtered = buttons.filter { !$0.isHidden }
        
        let rect = CGRect(x: button.x, y: 0, width: button.width, height: backgroundView.height)
        
        if rect.size.width > 0 {
            return rect
        }
        
        let width = backgroundView.width / CGFloat(filtered.count)
        return CGRect(x: width * CGFloat(filtered.firstIndex(of: button)!), y: 0, width: width, height: backgroundView.height)
    }
    
    @objc private func selectAction(_ sender: UIButton) {
        selectTab(index: sender.tag, animated: true)
        didSelect(sender, true)
    }
    
    open func selectTab(index: Int, animated: Bool) {
        selectedIndex = index
        UIView.animate(withDuration: animated ? 0.2 : 0.0) {
            self.selectedView.frame = self.selectedFrame
        }
    }
    
    open func selectNext(animated: Bool) -> Int? {
        let nextIndex: Int? = (selectedIndex..<buttons.count).first { !hiddenTabs.contains($0) && $0 != selectedIndex && buttons[$0].isEnabled }
        
        if let nextIndex = nextIndex {
            selectTab(index: nextIndex, animated: animated)
        }
        return nextIndex
    }
    
    open func selectPrevious(animated: Bool) -> Int? {
        let prevIndex: Int? = (0...selectedIndex).reversed().first { !hiddenTabs.contains($0) && $0 != selectedIndex && buttons[$0].isEnabled }
        
        if let prevIndex = prevIndex {
            selectTab(index: prevIndex, animated: animated)
        }
        return prevIndex
    }
}

#endif
