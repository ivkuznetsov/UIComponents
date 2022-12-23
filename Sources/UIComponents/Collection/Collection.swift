//
//  Collection.swift
//

import UIKit
import CommonUtils

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

open class Collection: StaticSetupObject {
    
    public typealias Result = SelectionResult
    
    public let collection: CollectionView
    weak var delegate: CollectionDelegate?
    
    public var staticCellSize: CGSize? {
        didSet { layout?.itemSize = staticCellSize ?? .zero }
    }
    // defer reload when view is not visible
    var visible = true {
        didSet {
            if visible && visible != oldValue && !updatingData && deferredReload {
                reloadVisibleCells()
            }
        }
    }
    
    public var layout: UICollectionViewFlowLayout? {
        collection.collectionViewLayout as? UICollectionViewFlowLayout
    }
    
    public var noObjectsView = NoObjectsView.loadFromNib()
    
    public private(set) var objects: [AnyHashable] = []
    private var deferredReload: Bool = false
    private var updatingData: Bool = false
    private var lazyObjects: [AnyHashable]?
    
    open var setupViewContainer: ((ContainerCollectionCell)->())?
    
    public init(collection: CollectionView, delegate: CollectionDelegate) {
        self.delegate = delegate
        self.collection = collection
        super.init()
        setup()
    }
    
    public init(view: UIView, delegate: CollectionDelegate) {
        self.delegate = delegate
        collection = Self.createCollectionView()
        super.init()
        view.attach(collection)
        setup()
    }
    
    private static func createCollectionView() -> CollectionView {
        let layout = CollectionViewLeftAlignedLayout()
        layout.minimumLineSpacing = 0
        layout.minimumInteritemSpacing = 0
        
        let collection = CollectionView(frame: .zero, collectionViewLayout: layout)
        collection.backgroundColor = .clear
        collection.alwaysBounceVertical = true
        collection.contentInsetAdjustmentBehavior = .always
        return collection
    }
    
    func setup() {
        collection.delegate = self
        collection.dataSource = self
    }
    
    private var deferredCompletion: (()->())?
    
    public func reloadVisibleCells() {
        if visible {
            deferredReload = false
            collection.visibleCells.forEach { item in
                if let indexPath = collection.indexPath(for: item) {
                    let object = objects[indexPath.item]
                    
                    if object as? UIView == nil {
                        delegate?.createCell(object: object, collection: self)?.fill(item)
                    }
                }
            }
        } else {
            deferredReload = true
        }
    }
    
    public func set(cellsPadding: CGFloat) {
        layout?.sectionInset = .init(top: cellsPadding, left: cellsPadding, bottom: cellsPadding, right: cellsPadding)
        layout?.minimumInteritemSpacing = cellsPadding
        layout?.minimumLineSpacing = cellsPadding
    }
    
    public var availableCellWidth: CGFloat {
        var width = collection.width
        if let layout = layout {
            width -= layout.sectionInset.left + layout.sectionInset.right + collection.safeAreaInsets.left + collection.safeAreaInsets.right
        }
        return width
    }
    
    open func set(objects: [AnyHashable], animated: Bool, completion: (()->())? = nil) {
        let resultCompletion = { [weak self] in
            guard let wSelf = self else { return }
            
            let deferred = wSelf.deferredCompletion
            wSelf.deferredCompletion = nil
            wSelf.updatingData = false
            
            if wSelf.delegate?.shouldShowNoData(objects, collection: wSelf) == true {
                wSelf.collection.attach(wSelf.noObjectsView, type: .safeArea)
            } else {
                wSelf.noObjectsView.removeFromSuperview()
            }
            deferred?()
        }
        deferredCompletion = completion
        
        if updatingData {
            lazyObjects = objects
        } else {
            updatingData = true
            
            internalSet(objects, animated: animated) { [weak self] in
                guard let wSelf = self else { return }
                
                if let objects = wSelf.lazyObjects {
                    wSelf.lazyObjects = nil
                    wSelf.internalSet(objects, animated: false, completion: resultCompletion)
                } else {
                    resultCompletion()
                }
            }
        }
    }
    
    private func internalSet(_ objects: [AnyHashable], animated: Bool, completion: @escaping ()->()) {
        collection.reload(animated: animated,
                          expandBottom: false,
                          oldData: self.objects,
                          newData: objects,
                          updateObjects: {
                            reloadVisibleCells()
                            self.objects = objects
                          },
                          completion: completion)
    }
    
    open override func responds(to aSelector: Selector!) -> Bool {
        super.responds(to: aSelector) ? true : (delegate?.responds(to: aSelector) ?? false)
    }
    
    open override func forwardingTarget(for aSelector: Selector!) -> Any? {
        super.responds(to: aSelector) ? self : delegate
    }
    
    deinit {
        collection.delegate = nil
        collection.dataSource = nil
    }
}

extension Collection: UICollectionViewDataSource {
    
    public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int { objects.count }
    
    public func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let object = objects[indexPath.item]
        
        if let view = object as? UIView {
            let cell = collection.createCell(for: ContainerCollectionCell.self, identifier: "\(view.hash)", source: .code, at: indexPath)
            cell.attach(view: view)
            setupViewContainer?(cell)
            return cell
        } else {
            guard let createCell = delegate?.createCell(object: object, collection: self) else {
                fatalError("Please specify cell for \(object)")
            }
            
            let cell = collection.createCell(for: createCell.type, at: indexPath)
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
            objects.remove(at: sourceIndexPath.item)
            objects.insert(object, at: destinationIndexPath.item)
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
            
            let insets = self.layout?.sectionInset
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
            guard let size = delegate?.cellSizeFor(object: object, collection: self) else {
                fatalError("Please specify cell size")
            }
            return size
        }
    }
}
