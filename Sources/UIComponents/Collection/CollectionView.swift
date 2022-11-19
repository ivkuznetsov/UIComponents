//
//  CollectionView.swift
//

#if os(iOS)

import UIKit

open class CollectionView: UICollectionView {
    
    private var registeredCells: Set<String> = Set()
    open var didChangeBounds: (()->())?
    
    public override init(frame: CGRect, collectionViewLayout layout: UICollectionViewLayout) {
        super.init(frame: frame, collectionViewLayout: layout)
    }
    
    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.canCancelContentTouches = true
        self.delaysContentTouches = false
    }
    
    open func createCell<T: UICollectionViewCell>(for type: T.Type, at indexPath: IndexPath) -> T {
        let identifier = String(describing: type)
        
        if !registeredCells.contains(identifier) {
            register(UINib(nibName: identifier, bundle: Bundle(for: type)), forCellWithReuseIdentifier: identifier)
            registeredCells.insert(identifier)
        }
        return dequeueReusableCell(withReuseIdentifier: identifier, for: indexPath) as! T
    }
    
    open override func touchesShouldCancel(in view: UIView) -> Bool {
        if view is UIControl {
            return true
        }
        return super.touchesShouldCancel(in: view)
    }
    
    open override var frame: CGRect {
        didSet {
            if needRelayoutFor(size: frame.size, oldSize: oldValue.size) {
                didChangeBounds?()
                collectionViewLayout.invalidateLayout()
            }
        }
    }
    
    open override var bounds: CGRect {
        didSet {
            if needRelayoutFor(size: bounds.size, oldSize: oldValue.size) {
                didChangeBounds?()
                self.layoutIfNeeded()
                self.collectionViewLayout.invalidateLayout()
            }
        }
    }
    
    private func needRelayoutFor(size: CGSize, oldSize: CGSize) -> Bool {
        if let layout = collectionViewLayout as? UICollectionViewFlowLayout {
            if layout.scrollDirection == .horizontal {
                return size.height != oldSize.height
            } else {
                return size.width != oldSize.width
            }
        }
        return size != oldSize
    }
}

#endif
