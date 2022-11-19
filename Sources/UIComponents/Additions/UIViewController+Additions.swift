//
//  UIViewController+Additions.swift
//

#if os(iOS)

import UIKit

public extension UIViewController {
    
    static var topViewController: UIViewController? {
        var topVC: UIViewController?
        
        if let shared = UIApplication.value(forKey: "sharedApplication") as? UIApplication {
            topVC = shared.keyWindow?.rootViewController ?? shared.delegate?.window??.rootViewController
        }
        while topVC?.presentedViewController != nil {
            topVC = topVC?.presentedViewController
        }
        return topVC
    }
    
    static var currentViewController: UIViewController? {
        var topViewController = self.topViewController
        
        if let tabbarController = topViewController as? UITabBarController {
            topViewController = tabbarController.selectedViewController
        }
        if let nc = topViewController as? UINavigationController {
            topViewController = nc.viewControllers.last
        }
        return topViewController
    }
}

#endif
