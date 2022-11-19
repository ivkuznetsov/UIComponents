//
//  OperationHelper.swift
//

#if os(iOS)

import UIKit
import CommonUtils

public typealias Progress = (Double)->()
public typealias Completion = (Error?)->()

open class OperationHelper: StaticSetupObject {

    public enum Loading {
        
        // fullscreen opaque overlay loading with fullscreen opaque error
        case opaque
        
        // fullscreen semitransparent overlay loading with alert error
        case translucent
        
        // shows loading bar at the top of the screen without blocking the content, error is shown as label at the top for couple of seconds
        case nonblocking
        
        case none
    }
    
    private class OperationToken: Hashable {
        let id: String = UUID().uuidString
        let completion: Completion
        var operation: Cancellable?
        
        func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }
        
        static func ==(lhs: OperationToken, rhs: OperationToken) -> Bool { lhs.hashValue == rhs.hashValue }
        
        init(completion: @escaping Completion) {
            self.completion = completion
        }
    }
    
    //required for using LoadingTypeTranslucent.
    open var processTranslucentError: (UIView, Error, _ retry: (()->())?)->()
    
    //by default retry appears in all operations
    open var shouldSupplyRetry: (Error)->Bool
    
    open lazy var loadingView = LoadingView.loadFromNib()
    open lazy var loadingBarView = LoadingBarView()
    open lazy var failedView = FailedView.loadFromNib()
    open lazy var failedBarView = AlertBarView.loadFromNib()
    
    open weak var view: UIView?
    private var keyedOperations: [String:OperationToken] = [:]
    private var processing = Set<OperationToken>()
    private var loadingCounter = 0
    private var nonblockingLoadingCounter = 0
    
    public init(view: UIView) {
        self.view = view
        
        shouldSupplyRetry = { $0 as? RunError == nil }
        
        processTranslucentError = { (_, error, retry) in
            let cancelTitle = retry != nil ? "Cancel" : "OK"
            var otherActions: [(String, (()->())?)] = []
            if let retry = retry {
                otherActions.append(("Retry", { retry() }))
            }
            if let vc = UIViewController.topViewController {
                Alert.present(message: error.localizedDescription, cancel: cancelTitle, other: otherActions, on: vc)
            }
        }
        super.init()
    }
    
    private func cancel(token: OperationToken) {
        processing.remove(token)
        token.operation?.cancel()
        token.completion(RunError.cancelled)
    }
    
    // progress indicator becomes visible on first Progress block performing
    // 'key' is needed to cancel previous launched operation with the same key
    open func run(_ closure: @escaping (@escaping Completion, @escaping Progress)->Cancellable?, loading: Loading, key: String? = nil) {
        
        increment(loading: loading)
        if let key = key {
            if let token = keyedOperations[key] {
                cancel(token: token)
            }
        }
        
        if loading == .opaque || loading == .translucent {
            failedView.removeFromSuperview()
        }
        
        let token = OperationToken(completion: { [weak self] error in
            guard let wSelf = self else { return }
            
            wSelf.decrement(loading: loading)
            
            if let key = key {
                wSelf.keyedOperations[key] = nil
            }
            
            if let error = error {
                var retry: (()->())?
                
                if wSelf.shouldSupplyRetry(error) {
                    retry = { self?.run(closure, loading: loading, key: key) }
                }
                wSelf.process(error: error, retry: retry, loading: loading)
            }
        })
        processing.insert(token)
        
        if let key = key {
            keyedOperations[key] = token
        }
        
        token.operation = closure({ [weak self] error in
            if let wSelf = self, wSelf.processing.contains(token) {
                wSelf.processing.remove(token)
                token.completion(error)
            }
        }, { [weak self] progress in
            if let wSelf = self, wSelf.processing.contains(token) {
                if loading == .opaque || loading == .translucent {
                    wSelf.loadingView.progress = CGFloat(progress)
                } else if loading == .nonblocking {
                    wSelf.loadingBarView.progress = CGFloat(progress)
                }
            }
        })
    }
    
    private func process(error: Error, retry: (()->())?, loading: Loading) {
        guard error as? RunError != .cancelled, let view = view else { return }
        
        if loading == .translucent {
            processTranslucentError(view, error, retry)
        } else if loading == .opaque {
            failedView.present(in: view, text: error.localizedDescription, retry: retry)
        } else if loading == .nonblocking {
            if failedBarView.message() != error.localizedDescription {
                failedBarView.present(in: view, message: error.localizedDescription)
            }
        }
    }
    
    private func increment(loading: Loading) {
        guard let view = view else { return }
        
        if loading == .translucent || loading == .opaque {
            if loadingCounter == 0 {
                loadingView.present(in: view, animated: (loading == .translucent) && view.window != nil && failedView.superview == nil)
                loadingView.performLazyLoading(showBackground: loading == .opaque)
            }
            if loading == .opaque && loadingView.opaqueStyle == false {
                loadingView.opaqueStyle = true
            }
            loadingCounter += 1
        } else if loading == .nonblocking {
            if nonblockingLoadingCounter == 0 {
                loadingBarView.present(in: view, animated: true)
            }
            nonblockingLoadingCounter += 1
        }
    }
    
    private func decrement(loading: Loading) {
        if loading == .translucent || loading == .opaque {
            loadingCounter -= 1
            if loadingCounter == 0 {
                loadingView.hide(true)
            }
        } else if loading == .nonblocking {
            nonblockingLoadingCounter -= 1
            if nonblockingLoadingCounter == 0 {
                loadingBarView.hide(true)
            }
        }
    }
    
    open func cancelOperations() {
        processing.forEach { cancel(token: $0) }
    }
    
    deinit {
        cancelOperations()
    }
}

#endif
