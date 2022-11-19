//
//  CircularProgressView.swift
//

#if os(iOS)

import UIKit

open class CircularProgressView: UIView {
    
    @IBInspectable open var lineWidth: CGFloat = 3 {
        didSet {
            bgLayer.lineWidth = lineWidth
            progressLayer.lineWidth = lineWidth
        }
    }
    
    @IBInspectable open var fillColor: UIColor! {
        didSet { bgLayer.strokeColor = fillColor.cgColor }
    }
    
    open var progress: CGFloat = 0 {
        didSet { progressLayer.strokeEnd = progress }
    }
    
    private lazy var bgLayer: CAShapeLayer = {
        let layer = CAShapeLayer()
        layer.strokeColor = fillColor.cgColor
        layer.lineWidth = lineWidth
        layer.fillColor = UIColor.clear.cgColor
        self.layer.addSublayer(layer)
        return layer
    }()
    
    private lazy var progressLayer: CAShapeLayer = {
        let layer = CAShapeLayer()
        layer.strokeColor = tintColor.cgColor
        layer.lineWidth = lineWidth
        layer.lineCap = .round
        layer.strokeEnd = 0
        layer.fillColor = UIColor.clear.cgColor
        self.layer.addSublayer(layer)
        return layer
    }()
    
    public required override init(frame: CGRect) {
        super.init(frame: frame)
        fillColor = tintColor
    }
    
    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        fillColor = tintColor
    }
    
    open override func layoutSubviews() {
        super.layoutSubviews()
        bgLayer.frame = progressLayer.frame
        progressLayer.frame = CGRect(x: 0, y: 0, width: bounds.size.width, height: bounds.size.height)
        updatePath()
    }
    
    private func updatePath() {
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let radius = min(bounds.width / 2, bounds.height / 2 - progressLayer.lineWidth / 2)
        let startAngle = -(CGFloat.pi / 2)
        let endAngle = 3 * CGFloat.pi / 2
        let path = UIBezierPath(arcCenter: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: true)
        progressLayer.path = path.cgPath
        bgLayer.path = path.cgPath
    }
}

#endif
