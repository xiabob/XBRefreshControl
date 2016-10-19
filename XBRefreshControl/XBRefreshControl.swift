//
//  XBRefreshControl.swift
//  XBRefreshControlDemo
//
//  Created by xiabob on 16/6/14.
//  Copyright © 2016年 xiabob. All rights reserved.
//

import UIKit

public typealias XBRefreshAction = (_ refreshControl: XBRefreshControl)->()

public protocol XBRefreshControlDelegate: NSObjectProtocol {
    func onRefresh(_ refreshControl: XBRefreshControl)
}

open class XBRefreshControl: UIControl {
    //keyPath
    fileprivate let kContentOffset = "contentOffset"
    fileprivate let kContentInset = "contentInset"
    
    //数值常量参数
    fileprivate let kTotalViewHeight: CGFloat   = 400
    fileprivate let kOpenedViewHeight: CGFloat  = 44
    fileprivate let kMinTopPadding: CGFloat     = 9
    fileprivate let kMaxTopPadding: CGFloat     = 5
    fileprivate let kMinTopRadius: CGFloat      = 12.5
    fileprivate let kMaxTopRadius: CGFloat      = 16
    fileprivate let kMinBottomRadius: CGFloat   = 3
    fileprivate let kMaxBottomRadius: CGFloat   = 16
    fileprivate let kMinBottomPadding: CGFloat  = 4
    fileprivate let kMaxBottomPadding: CGFloat  = 6
    fileprivate let kMinArrowSize: CGFloat      = 2
    fileprivate let kMaxArrowSize: CGFloat      = 3
    fileprivate let kMinArrowRadius: CGFloat    = 5
    fileprivate let kMaxArrowRadius: CGFloat    = 7
    fileprivate let kMaxDistance: CGFloat       = 53
    
    //控制状态的bool变量
    fileprivate var refreshing = false
    fileprivate var canRefresh = true
    fileprivate var ignoreInset = false
    fileprivate var ignoreOffset = false
    fileprivate var didSetInset = false
    fileprivate var hasSectionHeaders = false
    
    //视图相关变量
    fileprivate weak var scrollView: UIScrollView? 
    fileprivate var activity: UIView?
    fileprivate var endRefreshView: UIView?
    fileprivate var shapeLayer = CAShapeLayer()
    fileprivate var arrowLayer = CAShapeLayer()
    fileprivate var highlightLayer = CAShapeLayer()
    fileprivate var defaultEndRefreshView: UIView = {
        let label = UILabel()
        label.bounds = CGRect(x: 0, y: 0, width: 100, height: 20)
        label.textColor = UIColor.gray
        label.font = UIFont.systemFont(ofSize: 14)
        label.textAlignment = .center
        label.text = "刷新完成"
        return label
    }()
    
    //储存型变量
    fileprivate var originalContentInset: UIEdgeInsets
    fileprivate var lastOffset: CGFloat = 0
    
    
    open var refreshAction: XBRefreshAction?
    open weak var delegate: XBRefreshControlDelegate?
    open var shouldShowWhenbounced = false
    open var isShowDefaultEndRefreshView = false {
        didSet {
            //没有设置就使用默认
            if endRefreshView == nil && isShowDefaultEndRefreshView {
                endRefreshView = defaultEndRefreshView
            }
        }
    }
    
    //MARK: - init life cycle

    convenience public init(refreshAction: XBRefreshAction?) {
        self.init(activityIndicatorView: nil, delegate: nil, refreshAction: refreshAction)
    }
    
    convenience public init(delegate: XBRefreshControlDelegate?) {
        self.init(activityIndicatorView: nil, delegate: delegate,refreshAction: nil)
    }
    
    public init(activityIndicatorView: UIView?,
         delegate: XBRefreshControlDelegate?,
         refreshAction: XBRefreshAction?) {
        originalContentInset = UIEdgeInsets()
        activity = activityIndicatorView
        self.refreshAction = refreshAction
        self.delegate = delegate
        
        super.init(frame: CGRect.zero)
        commonInit()
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
//        debugPrint("XBRefreshControl deinit")
    }
    
    fileprivate func commonInit() {
        autoresizingMask = .flexibleWidth
        tintColor = UIColor(red: 155.0/255, green: 162.0/255, blue: 172.0/255, alpha: 1.0)
        
        configScrollView()
        configActivity()
        configShapeLayer()
        configArrowLayer()
        configHighlightLayer()
    }
    
    //MARK: - config views
    fileprivate func configScrollView() {
        scrollView?.addSubview(self)
        addObserver()
    }
    
    fileprivate func configActivity() {
        if activity == nil {
            activity = UIActivityIndicatorView(activityIndicatorStyle: .gray)
        }
        let mask = UIViewAutoresizing.flexibleLeftMargin.union(.flexibleRightMargin)
        activity!.autoresizingMask = mask
        activity!.center = CGPoint(x: floor(frame.size.width / 2), y: floor(frame.size.height / 2)) 
        activity!.alpha = 0 
        if let view = activity as? UIActivityIndicatorView {
            view.startAnimating()
        }
        addSubview(activity!)
    }
    
    fileprivate func configShapeLayer() {
        shapeLayer.fillColor = tintColor.cgColor
        shapeLayer.strokeColor = UIColor.darkGray.withAlphaComponent(0.5).cgColor
        shapeLayer.lineWidth = 0.5
        shapeLayer.shadowColor = UIColor.black.cgColor
        shapeLayer.shadowOffset = CGSize(width: 0, height: 1)
        shapeLayer.shadowOpacity = 0.4
        shapeLayer.shadowRadius = 0.5
        layer.addSublayer(shapeLayer)
    }
    
    fileprivate func configArrowLayer() {
        arrowLayer.strokeColor = UIColor.darkGray.withAlphaComponent(0.5).cgColor
        arrowLayer.lineWidth = 0.5 
        arrowLayer.fillColor = UIColor.white.cgColor
        shapeLayer.addSublayer(arrowLayer)
    }
    
    fileprivate func configHighlightLayer() {
        highlightLayer.fillColor = UIColor.white.withAlphaComponent(0.2).cgColor
        shapeLayer.addSublayer(highlightLayer)
    }
    
    //MARK: - add or remove refresh control
    
    open override func willMove(toSuperview newSuperview: UIView?) {
        super.willMove(toSuperview: newSuperview)
        
        //handel UIScrollView
        if newSuperview != nil && !(newSuperview is UIScrollView) { return }

        removeObserver()
        if newSuperview != nil {
            scrollView = newSuperview as? UIScrollView
            originalContentInset = scrollView!.contentInset
            frame = CGRect(x: 0, y: -(kTotalViewHeight + scrollView!.contentInset.top), width: scrollView!.frame.size.width, height: kTotalViewHeight)
            addObserver()
        }
    }
    
    //MARK: - add or remove observer
    fileprivate func addObserver() {
        scrollView?.addObserver(self, forKeyPath: kContentOffset, options: .new, context: nil)
        scrollView?.addObserver(self, forKeyPath: kContentInset, options: .new, context: nil)
    }
    
    fileprivate func removeObserver() {
        //不使用scrollView，因为在deinit阶段，scrollView为nil
        superview?.removeObserver(self, forKeyPath: kContentOffset)
        superview?.removeObserver(self, forKeyPath: kContentInset)
    }
    
    //MARK: - handle observer event
     override open func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        var offset: CGFloat = 0
        guard let scrollView = self.scrollView else {return}
        
        if keyPath == kContentInset {
            if !ignoreInset {
                //设置inset
                guard let ch = change else {return}
                guard let value = (ch[.newKey] as AnyObject?)?.uiEdgeInsetsValue else {return}
                originalContentInset = value
                frame = CGRect(x: 0, y: -(kTotalViewHeight + scrollView.contentInset.top), width: scrollView.frame.size.width, height: kTotalViewHeight)
            }
            return
        }
        
        if !isEnabled || ignoreOffset {
            return
        }
        
        guard let ch = change else {return}
        guard let value = (ch[.newKey] as AnyObject?)?.cgPointValue else {return}
        
        offset = value.y + originalContentInset.top
        
        if refreshing {
            if offset != 0 {
                // Keep thing pinned at the top
                CATransaction.begin()
                //取消隐式动画
                CATransaction.setDisableActions(true)
                shapeLayer.position = CGPoint(x: 0, y: kMaxDistance + offset + kOpenedViewHeight) 
                CATransaction.commit()
                
                activity!.center = CGPoint(x: floor(frame.size.width / 2),
                                               y: min(offset + frame.size.height + floor(kOpenedViewHeight / 2), frame.size.height - kOpenedViewHeight / 2))
                
                //scrollView回弹过程，在这个过程中的(offset >= -kOpenedViewHeight)阶段我们改变scrollView的contentInset，但在这里不需要监听contentInset的变化
                ignoreInset = true
                ignoreOffset = true
                
                if offset < 0 {
                    // Set the inset depending on the situation
                    if offset >= -kOpenedViewHeight {
                        if !scrollView.isDragging {
                            if !didSetInset {
                                didSetInset = true
                                hasSectionHeaders = false
                                if let tableView = scrollView as? UITableView {
                                    for i in 0 ..< tableView.numberOfSections {
                                        let height = tableView.rectForHeader(inSection: i).size.height
                                        if height != 0 {
                                            hasSectionHeaders = true
                                            break
                                        }
                                    }
                                }
                            }
                            
                            if hasSectionHeaders {
                                scrollView.contentInset = UIEdgeInsetsMake(min(-offset, kOpenedViewHeight) + originalContentInset.top,originalContentInset.left, originalContentInset.bottom,                                                         originalContentInset.right)
                            } else {
                                scrollView.contentInset = UIEdgeInsetsMake(kOpenedViewHeight + originalContentInset.top, originalContentInset.left,originalContentInset.bottom, originalContentInset.right)
                            }
                            
                        } else if hasSectionHeaders && didSetInset {
                                scrollView.contentInset = UIEdgeInsetsMake(-offset + originalContentInset.top, originalContentInset.left,originalContentInset.bottom, originalContentInset.right)
                        }
                    }
                } else if hasSectionHeaders {
                    scrollView.contentInset = originalContentInset
                }
                
                ignoreInset = false
                ignoreOffset = false
            }
            
            return
            
        } else {
            // Check if we can trigger a new refresh and if we can draw the control
            var dontDraw = false
            if !canRefresh {
                if offset >= 0 {
                    // We can refresh again after the control is scrolled out of view
                    canRefresh = true
                    didSetInset = false
                } else {
                    dontDraw = true
                }
            } else {
                if offset >= 0 {
                    // Don't draw if the control is not visible
                    dontDraw = true
                }
            }

            if !shouldShowWhenbounced {
                if offset > 0 && lastOffset > offset && !scrollView.isTracking {
                    // If we are scrolling too fast, don't draw, and don't trigger unless the scrollView bounced back
                    canRefresh = false
                    dontDraw = true
                }
            }
            
            if dontDraw {
                shapeLayer.path = nil
                shapeLayer.shadowPath = nil
                arrowLayer.path = nil
                highlightLayer.path = nil
                lastOffset = offset
                return
            }
        }
        
        lastOffset = offset
        
        var triggered = false
        
        //You don't need to release CF objects in Swift,
        //http://stackoverflow.com/questions/24176481/cannot-release-path-created-by-cgpathcreatemutable-in-swift
        let path = CGMutablePath()
        
        //Calculate some useful points and values
        let verticalShift = max(0, -((kMaxTopRadius + kMaxBottomRadius + kMaxTopPadding + kMaxBottomPadding) + offset))
        let distance = min(kMaxDistance, fabs(verticalShift))
        let percentage = 1 - (distance / kMaxDistance)
        
        let currentTopPadding = lerp(kMinTopPadding, kMaxTopPadding, percentage)
        let currentTopRadius = lerp(kMinTopRadius, kMaxTopRadius, percentage)
        let currentBottomRadius = lerp(kMinBottomRadius, kMaxBottomRadius, percentage)
        let currentBottomPadding =  lerp(kMinBottomPadding, kMaxBottomPadding, percentage)
     
        var bottomOrigin = CGPoint(x: floor(bounds.size.width / 2), y: bounds.size.height - currentBottomPadding - currentBottomRadius)
        var topOrigin = CGPoint.zero
        if distance == 0 {
            topOrigin = CGPoint(x: floor(bounds.size.width / 2), y: bottomOrigin.y)
        } else {
            topOrigin = CGPoint(x: floor(bounds.size.width / 2), y: bounds.size.height + offset + currentTopPadding + currentTopRadius)
            if percentage == 0 {
                bottomOrigin.y -= (fabs(verticalShift) - kMaxDistance)
                triggered = true
            }
        }
        
        //Top semicircle，顶部半圆
        path.addArc(center: topOrigin, radius: currentTopRadius, startAngle: 0, endAngle: CGFloat.pi, clockwise: true)
        
        //Left curve，左侧贝塞尔曲线
        let leftCp1 = CGPoint(x: lerp((topOrigin.x - currentTopRadius), (bottomOrigin.x - currentBottomRadius), 0.1), y: lerp(topOrigin.y, bottomOrigin.y, 0.2))
        let leftCp2 = CGPoint(x: lerp((topOrigin.x - currentTopRadius), (bottomOrigin.x - currentBottomRadius), 0.9), y: lerp(topOrigin.y, bottomOrigin.y, 0.2))
        let leftDestination = CGPoint(x: bottomOrigin.x - currentBottomRadius, y: bottomOrigin.y)
        path.addCurve(to: leftDestination, control1: leftCp1, control2: leftCp2)
        
        //Bottom semicircle，底部半圆
        path.addArc(center: bottomOrigin, radius: currentBottomRadius, startAngle: CGFloat.pi, endAngle: 0, clockwise: true)
        
        //Right curve，右侧贝塞尔曲线
        let rightCp2 = CGPoint(x: lerp((topOrigin.x + currentTopRadius), (bottomOrigin.x + currentBottomRadius), 0.1), y: lerp(topOrigin.y, bottomOrigin.y, 0.2))
        let rightCp1 = CGPoint(x: lerp((topOrigin.x + currentTopRadius), (bottomOrigin.x + currentBottomRadius), 0.9), y: lerp(topOrigin.y, bottomOrigin.y, 0.2))
        let rightDestination = CGPoint(x: topOrigin.x + currentTopRadius, y: topOrigin.y)
        path.addCurve(to: rightDestination, control1: rightCp1, control2: rightCp2)

        path.closeSubpath()
        
        //未触发刷新显示菊花转
        if !triggered {
            // Set paths
            
            shapeLayer.path = path
            shapeLayer.shadowPath = path
            
            // Add the arrow shape，绘制环形箭头
            //重新设置arrowLayer的position
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            arrowLayer.position = topOrigin
            CATransaction.commit()
            
            let currentArrowSize = lerp(kMinArrowSize, kMaxArrowSize, percentage)
            let currentArrowRadius = lerp(kMinArrowRadius, kMaxArrowRadius, percentage)
            let arrowBigRadius = currentArrowRadius + (currentArrowSize / 2)
            let arrowSmallRadius = currentArrowRadius - (currentArrowSize / 2)
            let arrowPath = CGMutablePath()
            
            arrowPath.addArc(center: CGPoint.zero, radius: arrowBigRadius, startAngle: 0, endAngle: CGFloat.pi*1.5, clockwise: false)
            arrowPath.addLine(to: CGPoint(x: 0, y: 0 - arrowBigRadius - currentArrowSize))
            arrowPath.addLine(to: CGPoint(x: 0 + (2 * currentArrowSize), y: 0 - arrowBigRadius + (currentArrowSize / 2)))
            arrowPath.addLine(to: CGPoint(x: 0, y: 0 - arrowBigRadius + (2 * currentArrowSize)))
            arrowPath.addLine(to: CGPoint(x: 0, y: 0 - arrowBigRadius + currentArrowSize))
            arrowPath.addArc(center: CGPoint.zero, radius: arrowSmallRadius, startAngle: CGFloat.pi*1.5, endAngle: 0, clockwise: true)
            
            arrowPath.closeSubpath()
            arrowLayer.path = arrowPath
            arrowLayer.fillRule = kCAFillRuleEvenOdd
            
            //随着下拉，旋转arrowLayer
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            arrowLayer.transform = CATransform3DIdentity
            arrowLayer.transform = CATransform3DMakeRotation(percentage*CGFloat(M_PI*2), 0, 0, -1)
            CATransaction.commit()
            
            // Add the highlight shape
            let highlightPath = CGMutablePath()
            highlightPath.addArc(center: topOrigin, radius: currentTopRadius, startAngle: 0, endAngle: CGFloat.pi, clockwise: true)
            highlightPath.addArc(center: CGPoint(x: topOrigin.x, y: topOrigin.y + 1.25), radius: currentTopRadius, startAngle: CGFloat.pi, endAngle: 0, clockwise: false)
            
            highlightLayer.path = highlightPath
            highlightLayer.fillRule = kCAFillRuleNonZero
            
        } else {
            // Start the shape disappearance animation，隐藏shape layer，显示activity
            
            let radius = lerp(kMinBottomRadius, kMaxBottomRadius, 0.2)
            let pathMorph = CABasicAnimation(keyPath: "path")
            pathMorph.duration = 0.15
            pathMorph.fillMode = kCAFillModeForwards
            pathMorph.isRemovedOnCompletion = false
            
            let toPath = CGMutablePath()
            toPath.addArc(center: topOrigin, radius: radius, startAngle: 0, endAngle: CGFloat.pi, clockwise: true)
            toPath.addCurve(to: CGPoint(x: topOrigin.x - radius, y: topOrigin.y), control1: CGPoint(x: topOrigin.x - radius, y: topOrigin.y), control2: CGPoint(x: topOrigin.x - radius, y: topOrigin.y))
            toPath.addArc(center: topOrigin, radius: radius, startAngle: CGFloat.pi, endAngle: 0, clockwise: true)
            toPath.addCurve(to: CGPoint(x: topOrigin.x + radius, y: topOrigin.y), control1: CGPoint(x: topOrigin.x + radius, y: topOrigin.y), control2: CGPoint(x: topOrigin.x + radius, y: topOrigin.y))
            
            toPath.closeSubpath()
            pathMorph.toValue = toPath
            shapeLayer.add(pathMorph, forKey: nil)
            
            let shadowPathMorph = CABasicAnimation(keyPath:"shadowPath")
            shadowPathMorph.duration = 0.15
            shadowPathMorph.fillMode = kCAFillModeForwards
            shadowPathMorph.isRemovedOnCompletion = false
            shadowPathMorph.toValue = toPath
            shapeLayer.add(shadowPathMorph, forKey: nil)
            
           let shapeAlphaAnimation = CABasicAnimation(keyPath:"opacity")
            shapeAlphaAnimation.duration = 0.1
            shapeAlphaAnimation.beginTime = CACurrentMediaTime() + 0.1
            shapeAlphaAnimation.toValue = NSNumber(value: 0 as Float)
            shapeAlphaAnimation.fillMode = kCAFillModeForwards
            shapeAlphaAnimation.isRemovedOnCompletion = false
            shapeLayer.add(shapeAlphaAnimation, forKey:nil)
            
            let alphaAnimation = CABasicAnimation(keyPath:"opacity")
            alphaAnimation.duration = 0.1
            alphaAnimation.toValue = NSNumber(value: 0 as Float)
            alphaAnimation.fillMode = kCAFillModeForwards
            alphaAnimation.isRemovedOnCompletion = false
            arrowLayer.add(alphaAnimation, forKey:nil)
            highlightLayer.add(alphaAnimation, forKey:nil)
            
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            activity!.layer.transform = CATransform3DMakeScale(0.1, 0.1, 1)
            CATransaction.commit()
            UIView.animate(withDuration: 0.2, delay: 0.15, options: .curveLinear, animations: { [unowned self] in
                self.activity!.alpha = 1
                self.activity!.layer.transform = CATransform3DMakeScale(1, 1, 1)
                }, completion: nil)
            
            refreshing = true
            canRefresh = false
            
            //刷新过程中，处理相关操作
            //默认方式
            self.sendActions(for: .valueChanged)
            //闭包方式
            if let refreshAction = self.refreshAction {
                refreshAction(self)
            }
            //代理回调方式
            if let delegate = self.delegate {
                delegate.onRefresh(self)
            }
        }
        
    }
    
    
    //MARK: - utils method
    
    //求插值
    fileprivate func lerp(_ a: CGFloat, _ b: CGFloat, _ p: CGFloat) -> CGFloat {
        return a + (b - a) * p
    }
    
    @objc fileprivate func hideRefreshControl() {
        UIView.animate(withDuration: 0.4, animations: { [weak self] in
            if self != nil {
                self!.ignoreInset = false
                self!.scrollView?.contentInset = self!.originalContentInset
                self!.ignoreInset = false
                self!.activity!.alpha = 0
                self!.activity!.layer.transform = CATransform3DMakeScale(0.1, 0.1, 1)
            }
            
            }, completion: { [weak self](finished) in
                if self != nil {
                    self!.endRefreshView?.removeFromSuperview()
                    
                    self!.shapeLayer.removeAllAnimations()
                    self!.shapeLayer.path = nil
                    self!.shapeLayer.shadowPath = nil
                    self!.shapeLayer.position = CGPoint.zero
                    self!.arrowLayer.removeAllAnimations()
                    self!.arrowLayer.path = nil
                    self!.highlightLayer.removeAllAnimations()
                    self!.highlightLayer.path = nil
                    // We need to use the scrollView somehow in the end block,
                    // or it'll get released in the animation block.
                    self!.ignoreInset = true
                    self!.scrollView?.contentInset = self!.originalContentInset
                    self!.ignoreInset = false
                }
            })
    }
    
    //MARK: - api
    
    ///你可以直接调用此方法来手动刷新，一般用不到
    open func beginRefreshing() {
        if (!refreshing) {
            guard let scrollView = self.scrollView else {return}
            
            let alphaAnimation = CABasicAnimation(keyPath:"opacity")
            alphaAnimation.duration = 0.0001 
            alphaAnimation.toValue = NSNumber(value: 0 as Float)
            alphaAnimation.fillMode = kCAFillModeForwards
            alphaAnimation.isRemovedOnCompletion = false
            shapeLayer.add(alphaAnimation, forKey: nil)
            arrowLayer.add(alphaAnimation, forKey: nil)
            highlightLayer.add(alphaAnimation, forKey: nil)
            
            activity!.alpha = 1
            activity!.layer.transform = CATransform3DMakeScale(1, 1, 1)
            
            let offset = scrollView.contentOffset
            ignoreInset = true
            scrollView.contentInset = UIEdgeInsetsMake(kOpenedViewHeight + self.originalContentInset.top, self.originalContentInset.left, self.originalContentInset.bottom, self.originalContentInset.right)
            ignoreInset = false
            scrollView.setContentOffset(offset, animated: false)
            
            refreshing = true
            canRefresh = false
        }
    }
    
    ///结束刷新动作时，需要调用此方法
    open func endRefreshing() {
        if refreshing {
            refreshing = false
            
            var delay: TimeInterval = 0
            if let endRefreshView = self.endRefreshView {
                //show the endRefreshView
                endRefreshView.center = activity!.center
                endRefreshView.alpha = 0
                addSubview(endRefreshView)
                delay = 0.5
            }
            
            if delay > 0 {
                UIView.animate(withDuration: 0.15, animations: { [weak self] in
                    if self != nil {
                        self!.endRefreshView?.alpha = 1
                        self!.activity!.alpha = 0
                        self!.activity!.layer.transform = CATransform3DMakeScale(0.1, 0.1, 1)
                    }
                    })
            }
            
            //hide view with animation, set common mode
            let delayTime = DispatchTime.now() + Double(Int64(delay * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC)
            DispatchQueue.main.asyncAfter(deadline: delayTime) {
                self.hideRefreshControl()
            }
        }
    }
    
    ///判断刷新状态
    open func isRefreshing() -> Bool {
        return refreshing
    }
    
    open func setEndRefreshView(_ view: UIView?) {
        endRefreshView = view
    }
    
    open override var isEnabled: Bool {
        didSet {
            shapeLayer.isHidden = !isEnabled
        }
    }
    
    open override var tintColor: UIColor! {
        didSet {
            shapeLayer.fillColor = tintColor.cgColor
        }
    }
    
    open func setActivityIndicatorViewColor(_ color: UIColor) {
        if let activity = activity as? UIActivityIndicatorView {
            activity.color = color
        }
    }
    
    open func setActivityIndicatorViewStyle(_ style: UIActivityIndicatorViewStyle) {
        if let activity = activity as? UIActivityIndicatorView {
            activity.activityIndicatorViewStyle = style
        }
    }
}

