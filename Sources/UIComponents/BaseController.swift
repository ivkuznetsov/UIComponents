//
//  BaseController.swift
//

import UIKit

open class BaseController: UIViewController {
    
    private var viewLayouted: Bool = false
    
    public static var closeTitle: String?
    
    public init() {
        super.init(nibName: nil, bundle: nil)
    }
    
    public override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }
    
    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    open lazy var loadingPresenter: LoadingPresenter = { LoadingPresenter(view: view) }()
    
    open override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .white
        
        if let nc = navigationController,
            nc.presentingViewController != nil,
            let index = nc.viewControllers.firstIndex(of: self),
            (index == 0 || nc.viewControllers[index - 1].navigationItem.rightBarButtonItem?.action == #selector(closeAction) ) {
            
            createCloseButton()
        }
    }
    
    open func createCloseButton() {
        navigationItem.leftBarButtonItem = UIBarButtonItem(title: type(of: self).closeTitle ?? "Close", style: .plain, target: self, action: #selector(closeAction))
    }
    
    open func previousViewController() -> UIViewController? {
        if let array = self.navigationController?.viewControllers, let index = array.firstIndex(of: self), index != 0 {
            return array[index - 1]
        }
        return nil
    }
    
    @IBAction open func closeAction() {
        if let nc = navigationController {
            if nc.presentingViewController != nil {
                nc.dismiss(animated: true, completion: nil)
            } else if let parentVC = parent, let nc = parentVC.navigationController, nc.presentingViewController != nil {
                nc.dismiss(animated: true, completion: nil)
            } else {
                nc.popViewController(animated: true)
            }
        } else {
            dismiss(animated: true, completion: nil)
        }
    }
    
    open func reloadView(_ animated: Bool) { }
    
    open func performOnFirstLayout() { }
    
    open override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        if !viewLayouted {
            performOnFirstLayout()
            viewLayouted = true
        }
    }
}
