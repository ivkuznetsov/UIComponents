//
//  Collection.swift
//

#if os(iOS)

import UIKit
import CommonUtils

public protocol CollectionDelegate: UICollectionViewDelegate {
    
    func shouldShowNoData(_ objects: [AnyHashable], collection: Collection) -> Bool
    
    func viewSizeFor(view: UIView, defaultSize: CGSize, collection: Collection) -> CGSize?
    
    func action(object: AnyHashable, collection: Collection) -> Collection.Result?
    
    func createCell(object: AnyHashable, collection: Collection) -> Collection.Cell?
    
    func cellSizeFor(object: AnyHashable, collection: Collection) -> CGSize?
    
    func move(object: AnyHashable) -> ((_ source: IndexPath, _ target: IndexPath)->())?
    
    func proposeMoving(object: AnyHashable, toIndexPath: IndexPath) -> IndexPath
}

public extension CollectionDelegate {
    
    func shouldShowNoData(_ objects: [AnyHashable], collection: Collection) -> Bool { objects.isEmpty }
    
    func viewSizeFor(view: UIView, defaultSize: CGSize, collection: Collection) -> CGSize? { nil }
    
    func action(object: AnyHashable, collection: Collection) -> Collection.Result? { nil }
    
    func createCell(object: AnyHashable, collection: Collection) -> Collection.Cell? { nil }
    
    func cellSizeFor(object: AnyHashable, collection: Collection) -> CGSize? { nil }
    
    func move(object: AnyHashable) -> ((_ source: IndexPath, _ target: IndexPath)->())? { nil }
    
    func proposeMoving(object: AnyHashable, toIndexPath: IndexPath) -> IndexPath { toIndexPath }
}

open class Collection: StaticSetupObject {
    
    public enum Result: Int {
        case deselectCell
        case selectCell
    }
    
    public struct Cell {
        
        fileprivate let type: UICollectionViewCell.Type
        fileprivate let fill: (UICollectionViewCell)->()
        
        public init<T: UICollectionViewCell>(_ type: T.Type, _ fill: ((T)->())? = nil) {
            self.type = type
            self.fill = { fill?($0 as! T) }
        }
    }
    
    public static var defaultDelegate: CollectionDelegate?
    public let collection: CollectionView
    weak var delegate: CollectionDelegate?
    
    public var animationFix: Bool = false //fixes animation for insert/delete but duplicates reloading
    public var staticCellSize: CGSize? {
        didSet { layout?.itemSize = staticCellSize ?? .zero }
    }
    // defer reload when view is not visible
    var visible = true {
        didSet {
            if visible && visible != oldValue && deferredUpdate {
                if !updatingDatasource {
                    let objects = lazyObjects ?? []
                    lazyObjects = nil
                    set(objects: objects, animated: false, completion: deferredCompletion)
                }
            }
        }
    }
    
    public var layout: UICollectionViewFlowLayout? {
        collection.collectionViewLayout as? UICollectionViewFlowLayout
    }
    
    public var noObjectsView = NoObjectsView.loadFromNib()
    
    public private(set) var objects: [AnyHashable] = []
    private var deferredUpdate: Bool = false
    private var updatingDatasource: Bool = false
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
    
    public init(customAdd: (CollectionView)->(), delegate: CollectionDelegate) {
        self.delegate = delegate
        collection = Self.createCollectionView()
        super.init()
        customAdd(collection)
        setup()
    }
    
    private static func createCollectionView() -> CollectionView {
        let layout = CollectionViewLeftAlignedLayout()
        layout.minimumLineSpacing = 0
        layout.minimumInteritemSpacing = 0
        
        let collection = CollectionView(frame: .zero, collectionViewLayout: layout)
        collection.backgroundColor = .clear
        collection.alwaysBounceVertical = true
        return collection
    }
    
    func setup() {
        collection.delegate = self
        collection.dataSource = self
    }
    
    private var deferredCompletion: (()->())?
    
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
    
    open func set(objects: [AnyHashable], animated: Bool, diffable: Bool = false, completion: (()->())? = nil) {
        let resultCompletion = { [weak self] in
            let deferred = self?.deferredCompletion
            self?.deferredCompletion = nil
            deferred?()
        }
        deferredCompletion = completion
        
        if updatingDatasource || !visible {
            lazyObjects = objects
            deferredUpdate = true
        } else {
            updatingDatasource = true
            
            internalSet(objects, animated: animated, diffable: diffable) { [weak self] in
                guard let wSelf = self else { return }
                
                if let objects = wSelf.lazyObjects {
                    wSelf.internalSet(objects, animated: false, diffable: diffable, completion: resultCompletion)
                    wSelf.lazyObjects = nil
                } else {
                    resultCompletion()
                }
                wSelf.updatingDatasource = false
            }
        }
    }
    
    private func internalSet(_ objects: [AnyHashable], animated: Bool, diffable: Bool, completion: (()->())?) {
        guard let delegate = delegate else { return }
        
        let toReload = collection.reload(animated: !deferredUpdate && animated, oldData: self.objects, newData: objects, diffable: diffable, completion: completion) { [weak self] in
            self?.objects = objects
        }
        deferredUpdate = false
        
        if animated {
            toReload.forEach {
                if let cell = collection.cellForItem(at: $0), cell as? ContainerCollectionCell == nil {
                    let object = objects[$0.item]
                    
                    let fillCell = delegate.createCell(object: object, collection: self) ?? Self.defaultDelegate?.createCell(object: object, collection: self)
                    
                    fillCell?.fill(cell)
                }
            }
        }
        
        if delegate.shouldShowNoData(objects, collection: self) {
            collection.attach(noObjectsView, type: .safeArea)
        } else {
            noObjectsView.removeFromSuperview()
        }
    }
    
    public override func responds(to aSelector: Selector!) -> Bool {
        if aSelector == #selector(collectionView(_:layout:sizeForItemAt:)), staticCellSize != nil {
            return false
        }
        
        if !super.responds(to: aSelector) {
            if let delegate = delegate {
                return delegate.responds(to: aSelector)
            }
            return false
        }
        return true
    }
    
    public override func forwardingTarget(for aSelector: Selector!) -> Any? {
        if !super.responds(to: aSelector) {
            return delegate
        }
        return self
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
            guard let createCell = delegate?.createCell(object: object, collection: self) ??
                    Self.defaultDelegate?.createCell(object: object, collection: self) else {
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
        let object = objects[indexPath.row]
        
        switch delegate?.action(object: object, collection: self) {
        case .deselectCell:
            collectionView.deselectItem(at: indexPath, animated: true)
        case .selectCell: break
        case .none:
            switch Self.defaultDelegate?.action(object: object, collection: self) {
            case .deselectCell:
                collectionView.deselectItem(at: indexPath, animated: true)
            default: break
            }
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
            
            let size = delegate?.viewSizeFor(view: view, defaultSize: defaultSize, collection: self) ?? Self.defaultDelegate?.viewSizeFor(view: view, defaultSize: defaultSize, collection: self)
            
            if let size = size {
                return CGSize(width: floor(size.width), height: ceil(size.height))
            }
            
            var frame = view.frame
            frame.size.width = defaultWidth
            view.frame = frame
            view.setNeedsLayout()
            view.layoutIfNeeded()
            
            let height = view.systemLayoutSizeFitting(CGSize(width: defaultWidth, height: UIView.layoutFittingCompressedSize.height),
                                                      withHorizontalFittingPriority: UILayoutPriority(rawValue: 1000),
                                                      verticalFittingPriority: UILayoutPriority(rawValue: 1)).height
            
            return CGSize(width: floor(frame.size.width), height: ceil(height))
        } else {
            guard let size = delegate?.cellSizeFor(object: object, collection: self) ?? Self.defaultDelegate?.cellSizeFor(object: object, collection: self) else {
                fatalError("Please specify cell size")
            }
            return size
        }
    }
}

#endif
