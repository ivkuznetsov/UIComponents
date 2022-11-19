//
//  Table.swift
//

#if os(iOS)

import UIKit
import CommonUtils

public protocol TableDelegate: UITableViewDelegate {
    
    //fade by default
    func animationForAdding(table: Table) -> UITableView.RowAnimation?
    
    //by default it becomes visible when objects array is empty
    func shouldShowNoData(objects: [AnyHashable], table: Table) -> Bool
    
    func action(object: AnyHashable, table: Table) -> Table.Result?
    
    func createCell(object: AnyHashable, table: Table) -> Table.Cell?
    
    func cellHeight(object: AnyHashable, original: CGFloat, table: Table) -> CGFloat
    
    func cellEstimatedHeight(object: AnyHashable, original: CGFloat, table: Table) -> CGFloat
    
    func cellEditor(object: AnyHashable, table: Table) -> Table.Editor?
}

public extension TableDelegate {
    
    func animationForAdding(table: Table) -> UITableView.RowAnimation? { nil }
    
    func shouldShowNoData(objects: [AnyHashable], table: Table) -> Bool { objects.isEmpty }
    
    func action(object: AnyHashable, table: Table) -> Table.Result? { nil }
    
    func createCell(object: AnyHashable, table: Table) -> Table.Cell? { nil }
    
    func cellHeight(object: AnyHashable, original: CGFloat, table: Table) -> CGFloat { 0 }
    
    func cellEstimatedHeight(object: AnyHashable, original: CGFloat, table: Table) -> CGFloat { 0 }
    
    func cellEditor(object: AnyHashable, table: Table) -> Table.Editor? { nil }
}

public protocol TablePrefetch {
    
    func prefetch(object: AnyHashable) -> Table.Cancel?
}

public protocol CellSizeCachable {
    
    var cacheKey: String { get }
}

open class Table: StaticSetupObject {
    
    public enum Result: Int {
        case deselectCell
        case selectCell
    }
    
    public struct Cell {
        
        fileprivate let type: UITableViewCell.Type
        fileprivate let fill: ((UITableViewCell)->())?
        
        public init<T: BaseTableViewCell>(_ type: T.Type, _ fill: ((T)->())? = nil) {
            self.type = type
            if let fill = fill {
                self.fill = { fill($0 as! T) }
            } else {
                self.fill = nil
            }
        }
    }
    
    public enum Editor {
        
        case delete(()->())
        case insert(()->())
        case actions(()->[UIContextualAction])
        
        fileprivate var style: UITableViewCell.EditingStyle {
            switch self {
                case .delete(_): return .delete
                case .insert(_): return .insert
                case .actions(_): return .none
            }
        }
    }
    
    public struct Cancel {
        
        let cancel: ()->()
        
        public init(_ cancel: @escaping ()->()) {
            self.cancel = cancel
        }
    }
    
    private var prefetchTokens: [IndexPath:Cancel] = [:]
    
    //options
    public var containerCellAttachType: UIView.AttachType = .constraints
    public var useEstimatedCellHeights = true {
        didSet { table.estimatedRowHeight = useEstimatedCellHeights ? 150 : 0 }
    }
    public var cacheCellHeights = false
    
    private var deferredUpdate: Bool = false
    open var visible: Bool = true { // defer reload when view is not visible
        didSet {
            if visible && (visible != oldValue) && deferredUpdate {
                set(objects: objects, animated: false)
            }
        }
    }
    
    public static var defaultDelegate: TableDelegate?
    public let table: UITableView
    public private(set) var objects: [AnyHashable] = []
    
    //adds edit/done button to navigation item
    public weak var navigationItem: UINavigationItem?
    public var processEditing: ((@escaping ()->())->())?
    
    private lazy var editButton: UIBarButtonItem = {
        UIBarButtonItem(barButtonSystemItem: .edit, target: self, action: #selector(editAction))
    }()
    private lazy var doneButton: UIBarButtonItem = {
        UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(editAction))
    }()
    
    open var noObjectsView: NoObjectsView = NoObjectsView.loadFromNib()
    
    weak var delegate: TableDelegate?
    fileprivate var cachedHeights: [NSValue:CGFloat] = [:]
    
    public init(table: UITableView, delegate: TableDelegate) {
        self.table = table
        self.delegate = delegate
        super.init()
        setup()
    }
    
    private static func createTable(style: UITableView.Style) -> UITableView {
        let table = UITableView(frame: CGRect.zero, style: style)
        table.backgroundColor = .clear
        table.rowHeight = UITableView.automaticDimension
        table.estimatedRowHeight = 150
        
        table.subviews.forEach {
            if let view = $0 as? UIScrollView {
                view.delaysContentTouches = false
            }
        }
        return table
    }
    
    //this method creates UITableView, by default tableView fills view, if you need something else use customAdd
    public init(view: UIView, style: UITableView.Style = .plain, delegate: TableDelegate) {
        self.delegate = delegate
        table = type(of: self).createTable(style: style)
        super.init()
        view.attach(table)
        setup()
    }
    
    public init(customAdd: (UITableView)->(), style: UITableView.Style = .plain, delegate: TableDelegate) {
        self.delegate = delegate
        table = type(of: self).createTable(style: style)
        super.init()
        customAdd(table)
        setup()
    }
    
    func setup() {
        table.delegate = self
        table.dataSource = self
        table.prefetchDataSource = delegate is TablePrefetch ? self : nil
        table.tableFooterView = UIView()
        table.register(ContainerTableCell.self, forCellReuseIdentifier: "ContainerTableCell")
    }
    
    public func clearHeightCache(_ object: AnyHashable) {
        cachedHeights[cachedHeightKeyFor(object: object)] = nil
    }
    
    open func set(objects: [AnyHashable], animated: Bool) {
        guard let delegate = delegate else { return }
        
        let oldObjects = self.objects
        
        if !visible && oldObjects.count == objects.count {
            self.objects = objects
            deferredUpdate = true
            return
        }
        
        // remove missed estimated heights
        var set = Set(cachedHeights.keys)
        objects.forEach { set.remove(cachedHeightKeyFor(object: $0)) }
        set.forEach { cachedHeights[$0] = nil }
        
        if !deferredUpdate && (animated && oldObjects.count > 0) {
            table.reload(oldData: oldObjects, newData: objects, deferred: { [weak self] in
                
                self?.reloadVisibleCells()
            }, updateObjects: { [weak self] in
                
                self?.objects = objects
                
            }, addAnimation: delegate.animationForAdding(table: self) ??
                    (type(of: self).defaultDelegate?.animationForAdding(table: self) ?? .fade))
        } else {
            self.objects = objects
            table.reloadData()
            deferredUpdate = false
        }
        
        if delegate.shouldShowNoData(objects: objects, table: self) {
            table.attach(noObjectsView, type: .safeArea)
        } else {
            noObjectsView.removeFromSuperview()
        }
        reloadEditButton(animated: animated)
    }
    
    public func scrollTo(object: AnyHashable, animated: Bool) {
        if let index = objects.firstIndex(of: object) {
            table.scrollToRow(at: IndexPath(row: index, section:0), at: .none, animated: animated)
        }
    }
    
    public func reloadVisibleCells() {
        table.visibleCells.forEach {
            var resIndex: Int?
            
            if let cell = $0 as? ObjectHolder {
                if let object = cell.object, let index = objects.firstIndex(of: object) {
                    resIndex = index
                    
                    let createCell = self.delegate?.createCell(object: object, table: self) ??
                        Self.defaultDelegate?.createCell(object: object, table: self)
                    
                    createCell?.fill?($0)
                }
            } else {
                resIndex = objects.firstIndex(of: $0)
            }
            if let index = resIndex {
                $0.separatorHidden = index == objects.count - 1 && self.table.tableFooterView != nil
            }
        }
    }
    
    public func setNeedUpdateHeights() {
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(updateHeights), object: nil)
        perform(#selector(updateHeights), with: nil, afterDelay: 0)
    }
    
    @objc private func updateHeights() {
        if visible {
            if delegate != nil {
                table.beginUpdates()
                table.endUpdates()
            }
        } else {
            deferredUpdate = true
        }
    }
    
    @objc public func editAction() {
        let complete = { [weak self] in
            if let wSelf = self {
                wSelf.table.setEditing(!wSelf.table.isEditing, animated: true)
                wSelf.reloadEditButton(animated: true)
            }
        }
        if let block = processEditing {
            block(complete)
        } else {
            complete()
        }
    }
    
    private func reloadEditButton(animated: Bool) {
        if let navigationItem = navigationItem {
            if noObjectsView.superview == nil {
                navigationItem.setRightBarButton(table.isEditing ? doneButton : editButton, animated: animated)
            } else {
                navigationItem.setRightBarButton(nil, animated: animated)
                table.setEditing(false, animated: animated)
            }
        }
    }
    
    fileprivate func cachedHeightKeyFor(object: AnyHashable) -> NSValue {
        if let object = object as? CellSizeCachable {
            return NSNumber(integerLiteral: object.cacheKey.hash)
        }
        return NSValue(nonretainedObject: object)
    }
    
    open override func responds(to aSelector: Selector!) -> Bool {
        if !super.responds(to: aSelector) {
            return delegate?.responds(to: aSelector) ?? false
        }
        return true
    }
    
    open override func forwardingTarget(for aSelector: Selector!) -> Any? {
        if !super.responds(to: aSelector) {
            return delegate
        }
        return self
    }
    
    deinit {
        prefetchTokens.values.forEach { $0.cancel() }
        table.delegate = nil
        table.dataSource = nil
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(updateHeights), object: nil)
    }
}

extension Table: UITableViewDataSource {
    
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { objects.count }
    
    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let object = objects[indexPath.row]
        let cell: UITableViewCell
        
        if let object = object as? UITableViewCell {
            cell = object
        } else if let object = object as? UIView {
            let tableCell = table.dequeueReusableCell(withIdentifier: "ContainerTableCell") as! ContainerTableCell
            tableCell.attach(view: object, type: containerCellAttachType)
            cell = tableCell
        } else {
            guard let createCell = (delegate?.createCell(object: object, table: self) ?? Self.defaultDelegate?.createCell(object: object, table: self)) else {
                fatalError("Please specify cell for \(object)")
            }
            
            cell = tableView.dequeueReusableCell(withIdentifier: String(describing: createCell.type)) ?? createCell.type.loadFromNib()
            createCell.fill?(cell)
            
            if let cell = cell as? ObjectHolder {
                cell.object = object
            }
        }
        
        cell.width = tableView.width
        cell.layoutIfNeeded()
        cell.separatorHidden = (indexPath.row == objects.count - 1) && table.tableFooterView != nil
        return cell
    }
    
    public func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        var resultHeight = UITableView.automaticDimension
        let object = objects[indexPath.row]
        
        var height: CGFloat?
        
        if cacheCellHeights {
            height = cachedHeights[cachedHeightKeyFor(object: object)]
        }
        if height == nil {
            height = delegate?.cellHeight(object: object, original: resultHeight, table: self)
        }
        if height == nil || height! == 0 {
            height = type(of: self).defaultDelegate?.cellHeight(object: object, original: resultHeight, table: self)
        }
        if let height = height, height > 0 {
            resultHeight = height
        }
        if cacheCellHeights {
            cachedHeights[cachedHeightKeyFor(object: object)] = resultHeight
        }
        return resultHeight
    }
    
    public func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        if !useEstimatedCellHeights {
            return self.tableView(tableView, heightForRowAt: indexPath)
        }
        
        let object = objects[indexPath.row]
        if let cell = object as? UITableViewCell {
            return cell.bounds.size.height
        } else if let cell = object as? UIView {
            return cell.systemLayoutSizeFitting(CGSize(width: tableView.width, height: CGFloat.greatestFiniteMagnitude)).height
        } else if let value = cachedHeights[cachedHeightKeyFor(object: object)] {
            return value
        } else if let value = (delegate?.cellEstimatedHeight(object: object, original: tableView.estimatedRowHeight, table: self) ??
            type(of: self).defaultDelegate?.cellEstimatedHeight(object: object, original: tableView.estimatedRowHeight, table: self)) {
            return value
        }
        return 150
    }
    
    public func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        let object = objects[indexPath.row]
        
        if let editor = delegate?.cellEditor(object: object, table: self) ?? type(of: self).defaultDelegate?.cellEditor(object: object, table: self) {
            
            return editor.style != .none
        }
        return false
    }
}

extension Table: UITableViewDelegate {
    
    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let object = objects[indexPath.row]
        
        switch delegate?.action(object: object, table: self) {
        case .deselectCell:
            tableView.deselectRow(at: indexPath, animated: true)
        case .selectCell: break
        case .none:
            switch type(of: self).defaultDelegate?.action(object: object, table: self) {
            case .deselectCell:
                tableView.deselectRow(at: indexPath, animated: true)
            default: break
            }
        }
    }
    
    public func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        if useEstimatedCellHeights, let cell = cell as? UITableViewCell & ObjectHolder, let object = cell.object {
            cachedHeights[cachedHeightKeyFor(object: object)] = cell.bounds.size.height
        }
        delegate?.tableView?(tableView, willDisplay: cell, forRowAt: indexPath)
    }
    
    public func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        let object = objects[indexPath.row]
        
        if let editor = delegate?.cellEditor(object: object, table: self) ?? type(of: self).defaultDelegate?.cellEditor(object: object, table: self) {
            
            switch editor {
            case .delete(let action): action()
            case .insert(let action): action()
            default: break
            }
        }
    }
    
    public func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let object = objects[indexPath.row]
        
        if let editor = delegate?.cellEditor(object: object, table: self) ?? type(of: self).defaultDelegate?.cellEditor(object: object, table: self),
           case .actions(let actions) = editor {
            
            let configuration = UISwipeActionsConfiguration(actions: actions())
            configuration.performsFirstActionWithFullSwipe = false
            return configuration
        }
        return nil
    }
    
    public func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
        let object = objects[indexPath.row]
        
        if let editor = delegate?.cellEditor(object: object, table: self) ?? type(of: self).defaultDelegate?.cellEditor(object: object, table: self) {
            return editor.style
        }
        return .none
    }
}

extension Table: UITableViewDataSourcePrefetching {
    
    public func tableView(_ tableView: UITableView, prefetchRowsAt indexPaths: [IndexPath]) {
        if let delegate = delegate as? TablePrefetch {
            indexPaths.forEach {
                if let cancel = delegate.prefetch(object: objects[$0.row]) {
                    prefetchTokens[$0] = cancel
                }
            }
        }
    }
    
    public func tableView(_ tableView: UITableView, cancelPrefetchingForRowsAt indexPaths: [IndexPath]) {
        indexPaths.forEach {
            prefetchTokens[$0]?.cancel()
            prefetchTokens[$0] = nil
        }
    }
}

#endif
