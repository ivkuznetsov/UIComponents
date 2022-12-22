//
//  BaseTabsViewController.swift
//

import UIKit

open class BaseTabsViewController: BaseController {
    
    open var viewControllers: [UIViewController] = []
    open private(set) var currentViewController: UIViewController?
    
    @IBOutlet open var containerView: UIView!
    @IBOutlet open var tabsContainerView: UIView? // if nil tabsView will be set in navigationItem.titleView
    private var tabsWidthConstraint: NSLayoutConstraint?
    
    open var tabsView: TabsView!
    
    required public override init() {
        super.init()
    }
    
    public init(viewControllers: [UIViewController]) {
        self.viewControllers = viewControllers
        super.init()
    }
    
    public init?(coder aDecoder: NSCoder, viewControllers: [UIViewController]) {
        self.viewControllers = viewControllers
        super.init(coder: aDecoder)
    }
    
    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    open override func performOnFirstLayout() {
        super.performOnFirstLayout()
        
        if tabsContainerView != nil {
            attachTabsViewToContainer()
        } else {
            navigationItem.titleView = tabsView
            
            let insets = navigationController!.navigationBar.layoutMargins
            let rect = navigationController!.navigationBar.frame
            
            let width = screenWidth - insets.right - insets.left
            
            tabsView.translatesAutoresizingMaskIntoConstraints = false
            tabsView.frame = CGRect(x: insets.left, y: 0, width: width, height: rect.size.height)
            
            let constraint = tabsView.heightAnchor.constraint(equalToConstant: 44)
            constraint.priority = UILayoutPriority(900)
            constraint.isActive = true
        }
        
        if currentViewController == nil {
            _ = selectController(at: 0, animated: false)
        } else {
            if let vc = currentViewController, let index = viewControllers.firstIndex(of: vc) {
                tabsView.selectTab(index: index, animated: false)
            }
        }
    }
    
    open override func viewDidLoad() {
        super.viewDidLoad()
        
        tabsView = TabsView(titles: viewControllers.map{ $0.title! }, didSelect: { [unowned self] (button, animated) in
            _ = self.selectController(at: button.tag, animated: animated)
        })
        
        let swipeLeft = UISwipeGestureRecognizer(target: self, action: #selector(swipeAction(gr:)))
        swipeLeft.direction = .left
        swipeLeft.delegate = self
        self.view.addGestureRecognizer(swipeLeft)
        
        let swipeRight = UISwipeGestureRecognizer(target: self, action: #selector(swipeAction(gr:)))
        swipeRight.direction = .right
        swipeRight.delegate = self
        self.view.addGestureRecognizer(swipeRight)
    }
    
    open override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if tabsFillWidth && tabsContainerView == nil {
            tabsWidthConstraint = tabsView.widthAnchor.constraint(equalTo: navigationController!.navigationBar.widthAnchor, multiplier: 1)
            tabsView.wasAddedToSuperview = { [weak self] in
                self?.tabsWidthConstraint?.isActive = true
            }
            if tabsView.superview != nil {
                tabsWidthConstraint?.isActive = true
            }
        }
    }
    
    @objc open func swipeAction(gr: UISwipeGestureRecognizer) {
        if gr.direction == .left {
            if let index = tabsView.selectNext(animated: true) {
                _ = selectController(at: index, animated: true)
            }
        } else if gr.direction == .right {
            if let index = tabsView.selectPrevious(animated: true) {
                _ = selectController(at: index, animated: true)
            }
        }
    }
    
    private func attachTabsViewToContainer() {
        if let tabsContainer = tabsContainerView {
            tabsView.translatesAutoresizingMaskIntoConstraints = false
            tabsContainer.addSubview(tabsView)
            tabsContainer.topAnchor.constraint(equalTo: tabsView.topAnchor).isActive = true
            tabsContainer.bottomAnchor.constraint(equalTo: tabsView.bottomAnchor).isActive = true
            
            if tabsFillWidth {
                tabsContainer.leftAnchor.constraint(equalTo: tabsView.leftAnchor).isActive = true
                tabsContainer.rightAnchor.constraint(equalTo: tabsView.rightAnchor).isActive = true
            } else {
                tabsContainer.centerXAnchor.constraint(equalTo: tabsView.centerXAnchor).isActive = true
            }
        }
    }
    
    open func selectController(at index: Int) -> UIViewController {
        tabsView.selectTab(index: index, animated: false)
        return selectController(at: index, animated: false)
    }
    
    open func selectController(at index: Int, animated: Bool) -> UIViewController {
        if tabsView.hiddenTabs.contains(index) { return currentViewController! }
        
        let vc = viewControllers[index]
        if vc == currentViewController { return vc }

        if let currentViewController = currentViewController, animated {
            if viewControllers.firstIndex(of: currentViewController)! < viewControllers.firstIndex(of: vc)! {
                containerView.addPushTransition()
            } else {
                containerView.addPopTransition()
            }
        }
        
        currentViewController?.removeFromParent()
        currentViewController?.view.removeFromSuperview()
        currentViewController = vc
        self.addChild(vc)
        containerView.attach(vc.view)
        return currentViewController!
    }
    
    open var screenWidth: CGFloat { min(view.width, view.height) }
    
    open var tabsFillWidth: Bool { false }
}

extension BaseTabsViewController: UIGestureRecognizerDelegate { }
