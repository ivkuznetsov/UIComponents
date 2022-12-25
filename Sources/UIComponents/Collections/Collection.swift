//
//  Collection.swift
//

import UIKit
import CommonUtils

open class CollectionView: UICollectionView {
    
    public override init(frame: CGRect, collectionViewLayout layout: UICollectionViewLayout) {
        super.init(frame: frame, collectionViewLayout: layout)
        setup()
    }
    
    private func setup() {
        canCancelContentTouches = true
        delaysContentTouches = false
        backgroundColor = .clear
        alwaysBounceVertical = true
        contentInsetAdjustmentBehavior = .always
    }
    
    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setup()
    }
    
    open override func touchesShouldCancel(in view: UIView) -> Bool {
        view is UIControl ? true : super.touchesShouldCancel(in: view)
    }
}

public protocol CollectionDelegate: UICollectionViewDelegate {
    
    func shouldShowNoData(_ objects: [AnyHashable], collection: Collection) -> Bool
    
    func viewSizeFor(view: UIView, defaultSize: CGSize, collection: Collection) -> CGSize?
    
    func action(object: AnyHashable, collection: Collection) -> Collection.Result?
    
    func createCell(object: AnyHashable, collection: Collection) -> UICollectionView.Cell?
    
    func cellSizeFor(object: AnyHashable, collection: Collection) -> CGSize?
    
    func move(object: AnyHashable) -> ((_ source: IndexPath, _ target: IndexPath)->())?
    
    func proposeMoving(object: AnyHashable, toIndexPath: IndexPath) -> IndexPath
}

public extension CollectionDelegate {
    
    func shouldShowNoData(_ objects: [AnyHashable], collection: Collection) -> Bool { objects.isEmpty }
    
    func viewSizeFor(view: UIView, defaultSize: CGSize, collection: Collection) -> CGSize? { nil }
    
    func action(object: AnyHashable, collection: Collection) -> Collection.Result? { nil }
    
    func createCell(object: AnyHashable, collection: Collection) -> UICollectionView.Cell? { nil }
    
    func cellSizeFor(object: AnyHashable, collection: Collection) -> CGSize? { nil }
    
    func move(object: AnyHashable) -> ((_ source: IndexPath, _ target: IndexPath)->())? { nil }
    
    func proposeMoving(object: AnyHashable, toIndexPath: IndexPath) -> IndexPath { toIndexPath }
}

open class Collection: BaseList<CollectionView, CollectionDelegate, CGSize, ContainerCollectionItem> {
    
    public typealias Result = SelectionResult
    
    public var staticCellSize: CGSize? {
        didSet { list.flowLayout?.itemSize = staticCellSize ?? .zero }
    }
    
    public override init(list: CollectionView, delegate: CollectionDelegate) {
        super.init(list: list, delegate: delegate)
        list.delegate = self
        list.dataSource = self
        noObjectsView = NoObjectsView.loadFromNib(bundle: Bundle.module)
    }
    
    open override class func createList(in view: PlatformView) -> CollectionView {
        let collection = CollectionView(frame: .zero, collectionViewLayout: VerticalLeftAlignedLayout())
        view.attach(collection)
        return collection
    }
    
    open override func reloadVisibleCells(excepting: Set<Int> = Set()) {
        list.visibleCells.forEach { item in
            if let indexPath = list.indexPath(for: item), !excepting.contains(indexPath.item) {
                let object = objects[indexPath.item]
                
                if object as? UIView == nil {
                    delegate?.createCell(object: object, collection: self)?.fill(item)
                }
            }
        }
    }
    
    open override func updateList(_ objects: [AnyHashable], animated: Bool, updateObjects: (Set<Int>) -> (), completion: @escaping () -> ()) {
        list.reload(animated: animated,
                    expandBottom: false,
                    oldData: self.objects,
                    newData: objects,
                    updateObjects: updateObjects,
                    completion: completion)
    }
    
    open override func shouldShowNoData(_ objects: [AnyHashable]) -> Bool {
        delegate?.shouldShowNoData(objects, collection: self) == true
    }
    
    deinit {
        list.delegate = nil
        list.dataSource = nil
    }
}

extension Collection: UICollectionViewDataSource {
    
    public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int { objects.count }
    
    public func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let object = objects[indexPath.item]
        
        if let view = object as? UIView {
            let cell = list.createCell(for: ContainerCollectionItem.self, identifier: "\(view.hash)", source: .code, at: indexPath)
            cell.attach(view)
            setupViewContainer?(cell)
            return cell
        } else {
            guard let createCell = delegate?.createCell(object: object, collection: self) else {
                fatalError("Please specify cell for \(object)")
            }
            let cell = list.createCell(for: createCell.type, at: indexPath)
            createCell.fill(cell)
            return cell
        }
    }
    
    public func collectionView(_ collectionView: UICollectionView, canMoveItemAt indexPath: IndexPath) -> Bool {
        delegate?.move(object: objects[indexPath.item]) != nil
    }
    
    public func collectionView(_ collectionView: UICollectionView, moveItemAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
        let object = objects[sourceIndexPath.item]
        if let closure = delegate?.move(object: object) {
            closure(sourceIndexPath, destinationIndexPath)
            moveObject(from: sourceIndexPath, to: destinationIndexPath)
        }
    }
    
    public func collectionView(_ collectionView: UICollectionView, targetIndexPathForMoveFromItemAt originalIndexPath: IndexPath, toProposedIndexPath proposedIndexPath: IndexPath) -> IndexPath {
        let object = objects[originalIndexPath.item]
        return delegate?.proposeMoving(object: object, toIndexPath: proposedIndexPath) ?? proposedIndexPath
    }
}

extension Collection: UICollectionViewDelegate {
    
    public func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if delegate?.action(object: objects[indexPath.row], collection: self) == .deselect {
            collectionView.deselectItem(at: indexPath, animated: true)
        }
    }
}

extension Collection: UICollectionViewDelegateFlowLayout {
    
    public func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let object = objects[indexPath.item]
        
        if let view = object as? UIView {
            
            if view.superview == nil { // perfrom initial trait collection set
                collectionView.addSubview(view)
                view.removeFromSuperview()
            }
            
            let insets = list.flowLayout?.sectionInset
            let defaultWidth = collectionView.frame.size.width - (insets?.left ?? 0) - (insets?.right ?? 0)
            
            let targetView = view.superview ?? view
            
            var defaultSize = targetView.systemLayoutSizeFitting(CGSize(width: defaultWidth, height: UIView.layoutFittingCompressedSize.height), withHorizontalFittingPriority: UILayoutPriority(rawValue: 1000), verticalFittingPriority: UILayoutPriority(rawValue: 1))
            defaultSize.width = defaultWidth
            
            let size = delegate?.viewSizeFor(view: view, defaultSize: defaultSize, collection: self)
            
            if let size = size {
                return CGSize(width: floor(size.width), height: ceil(size.height))
            }
            
            var frame = view.frame
            frame.size.width = defaultWidth
            view.frame = frame
            view.setNeedsLayout()
            view.layoutIfNeeded()
            
            let height = view.systemLayoutSizeFitting(CGSize(width: defaultWidth,
                                                             height: UIView.layoutFittingCompressedSize.height),
                                                      withHorizontalFittingPriority: UILayoutPriority(rawValue: 1000),
                                                      verticalFittingPriority: UILayoutPriority(rawValue: 1)).height
            
            return CGSize(width: floor(frame.size.width), height: ceil(height))
        } else {
            var size = cachedSize(for: object)
            
            if size == nil {
                size = delegate?.cellSizeFor(object: object, collection: self)
                cache(size: size, for: object)
            }
            return size ?? .zero
        }
    }
}
