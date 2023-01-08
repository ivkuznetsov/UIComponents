//
//  OperationHelper.swift
//

import UIKit
import SharedUIComponents
import CommonUtils

@MainActor
public class LoadingPresenter {
    
    public let helper = LoadingHelper()
    public let view: UIView
    
    public var shouldSupplyRetry: (Error)->Bool = { $0 as? RunError == nil }
    
    public var processTranslucentError: (UIView, Error, _ retry: (()->())?)->() = { (_, error, retry) in
        let cancelTitle = retry != nil ? "Cancel" : "OK"
        var otherActions: [(String, (()->())?)] = []
        if let retry = retry {
            otherActions.append(("Retry", { retry() }))
        }
        if let vc = UIViewController.topViewController {
            Alert.present(message: error.localizedDescription, cancel: cancelTitle, other: otherActions, on: vc)
        }
    }
    
    public lazy var loadingView = LoadingView.loadFromNib(bundle: Bundle.module)
    public lazy var loadingBarView = LoadingBarView()
    public lazy var failedView = FailedView.loadFromNib(bundle: Bundle.module)
    public lazy var failedBarView = AlertBarView.loadFromNib(bundle: Bundle.module)
    
    public init(view: UIView) {
        self.view = view
        
        helper.$processing.sink { [weak self] in
            let values = Array($0.values)
            
            self?.reloadView(processing: values)
        }.retained(by: self)
        
        helper.didFail.sink { [weak self] fail in
            guard let wSelf = self else { return }
            
            let retry = wSelf.shouldSupplyRetry(fail.error) ? fail.retry : nil
            
            switch fail.presentation {
            case .opaque:
                wSelf.failedView.present(in: wSelf.view,
                                         text: fail.error.localizedDescription,
                                         retry: retry)
            case .translucent, .alertOnFail:
                wSelf.processTranslucentError(wSelf.view, fail.error, retry)
            case .nonblocking:
                wSelf.failedBarView.present(in: wSelf.view, message: fail.error.localizedDescription)
            case .none: break
            }
        }.retained(by: self)
    }
    
    private var progress: AnyObject?
    private var nonBlockingProgress: AnyObject?
    
    private func reloadView(processing: [LoadingHelper.TaskWrapper]) {
        let value = processing.first { $0.presentation == .opaque } ??
                    processing.first { $0.presentation == .translucent } ??
                    processing.first { $0.presentation == .nonblocking }
        
        if let value = value {
            if value.presentation == .opaque || value.presentation == .translucent {
                loadingBarView.hide(false)
                failedView.removeFromSuperview()
                loadingView.present(in: view, animated: value.presentation == .translucent)
                loadingView.opaqueStyle = value.presentation == .opaque
                loadingView.performLazyLoading(showBackground: value.presentation == .opaque)
                
                progress = value.$progress.sink { [weak loadingView] in
                    loadingView?.progress = $0
                }
            } else {
                loadingView.hide(true)
                loadingBarView.present(in: view, animated: true)
                
                nonBlockingProgress = value.$progress.sink { [weak loadingBarView] in
                    loadingBarView?.progress = $0
                }
            }
        } else {
            loadingBarView.hide(true)
            loadingView.hide(true)
        }
    }
}
