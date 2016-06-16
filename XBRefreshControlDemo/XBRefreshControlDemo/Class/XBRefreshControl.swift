//
//  XBRefreshControl.swift
//  XBRefreshControlDemo
//
//  Created by xiabob on 16/6/14.
//  Copyright © 2016年 xiabob. All rights reserved.
//

import UIKit

public typealias XBRefreshAction = (refreshControl: XBRefreshControl)->()

public protocol XBRefreshControlDelegate: NSObjectProtocol {
    func onRefresh(refreshControl: XBRefreshControl)
}

public class XBRefreshControl: UIControl {
    //keyPath
    private let kContentOffset = "contentOffset"
    private let kContentInset = "contentInset"
    
    //数值常量参数
    private let kTotalViewHeight: CGFloat   = 400
    private let kOpenedViewHeight: CGFloat  = 44
    private let kMinTopPadding: CGFloat     = 9
    private let kMaxTopPadding: CGFloat     = 5
    private let kMinTopRadius: CGFloat      = 12.5
    private let kMaxTopRadius: CGFloat      = 16
    private let kMinBottomRadius: CGFloat   = 3
    private let kMaxBottomRadius: CGFloat   = 16
    private let kMinBottomPadding: CGFloat  = 4
    private let kMaxBottomPadding: CGFloat  = 6
    private let kMinArrowSize: CGFloat      = 2
    private let kMaxArrowSize: CGFloat      = 3
    private let kMinArrowRadius: CGFloat    = 5
    private let kMaxArrowRadius: CGFloat    = 7
    private let kMaxDistance: CGFloat       = 53
    
    //控制状态的bool变量
    private var refreshing = false
    private var canRefresh = true
    private var ignoreInset = false
    private var ignoreOffset = false
    private var didSetInset = false
    private var hasSectionHeaders = false
    
    //视图相关变量
    private weak var scrollView: UIScrollView? 
    private var activity: UIView?
    private var endRefreshView: UIView?
    private var shapeLayer = CAShapeLayer()
    private var arrowLayer = CAShapeLayer()
    private var highlightLayer = CAShapeLayer()
    
    
    //储存型变量
    private var originalContentInset: UIEdgeInsets
    private var lastOffset: CGFloat = 0
    
    
    public var refreshAction: XBRefreshAction?
    public weak var delegate: XBRefreshControlDelegate?
    
    //MARK: - init life cycle
    convenience init(scrollView: UIScrollView) {
        self.init(scrollView: scrollView, activityIndicatorView: nil, delegate: nil, refreshAction: nil)
    }
    
    convenience init(scrollView: UIScrollView, refreshAction: XBRefreshAction?) {
        self.init(scrollView: scrollView, activityIndicatorView: nil, delegate: nil, refreshAction: refreshAction)
    }
    
    convenience init(scrollView: UIScrollView, delegate: XBRefreshControlDelegate?) {
        self.init(scrollView: scrollView, activityIndicatorView: nil, delegate: delegate,refreshAction: nil)
    }
    
    init(scrollView: UIScrollView,
         activityIndicatorView: UIView?,
         delegate: XBRefreshControlDelegate?,
         refreshAction: XBRefreshAction?) {
        
        self.scrollView = scrollView
        originalContentInset = scrollView.contentInset
        activity = activityIndicatorView
        self.refreshAction = refreshAction
        self.delegate = delegate
        
        super.init(frame: CGRectMake(0, -(kTotalViewHeight + scrollView.contentInset.top), scrollView.frame.size.width, kTotalViewHeight))
        
        commonInit()
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        debugPrint("XBRefreshControl deinit")
    }
    
    private func commonInit() {
        autoresizingMask = .FlexibleWidth
        tintColor = UIColor(red: 155.0/255, green: 162.0/255, blue: 172.0/255, alpha: 1.0)
        
        configScrollView()
        configActivity()
        configShapeLayer()
        configArrowLayer()
        configHighlightLayer()
    }
    
    //MARK: - config views
    private func configScrollView() {
        scrollView?.addSubview(self)
        addObserver()
    }
    
    private func configActivity() {
        if activity == nil {
            activity = UIActivityIndicatorView(activityIndicatorStyle: .Gray)
        }
        let mask = UIViewAutoresizing.FlexibleLeftMargin.union(.FlexibleRightMargin)
        activity!.autoresizingMask = mask
        activity!.center = CGPointMake(floor(frame.size.width / 2), floor(frame.size.height / 2)) 
        activity!.alpha = 0 
        if let view = activity as? UIActivityIndicatorView {
            view.startAnimating()
        }
        addSubview(activity!)
    }
    
    private func configShapeLayer() {
        shapeLayer.fillColor = tintColor.CGColor
        shapeLayer.strokeColor = UIColor.darkGrayColor().colorWithAlphaComponent(0.5).CGColor
        shapeLayer.lineWidth = 0.5
        shapeLayer.shadowColor = UIColor.blackColor().CGColor
        shapeLayer.shadowOffset = CGSizeMake(0, 1)
        shapeLayer.shadowOpacity = 0.4
        shapeLayer.shadowRadius = 0.5
        layer.addSublayer(shapeLayer)
    }
    
    private func configArrowLayer() {
        arrowLayer.strokeColor = UIColor.darkGrayColor().colorWithAlphaComponent(0.5).CGColor
        arrowLayer.lineWidth = 0.5 
        arrowLayer.fillColor = UIColor.whiteColor().CGColor
        shapeLayer.addSublayer(arrowLayer)
    }
    
    private func configHighlightLayer() {
        highlightLayer.fillColor = UIColor.whiteColor().colorWithAlphaComponent(0.2).CGColor
        shapeLayer.addSublayer(highlightLayer)
    }
    
    //MARK: - observer method
    
    private func xb_observeValueForKeyPath(keyPath: String?, ofObject object: AnyObject?, change: [String : AnyObject]?, context: UnsafeMutablePointer<Void>) {
        var offset: CGFloat = 0
        guard let scrollView = self.scrollView else {return}
        
        if keyPath == kContentInset {
            if !ignoreInset {
                //设置inset
                guard let ch = change else {return}
                guard let value = ch["new"]?.UIEdgeInsetsValue() else {return}
                originalContentInset = value
                frame = CGRectMake(0, -(kTotalViewHeight + scrollView.contentInset.top), scrollView.frame.size.width, kTotalViewHeight)
            }
            return
        }
        
        if !enabled || ignoreOffset {
            return
        }
        
        guard let ch = change else {return}
        guard let value = ch["new"]?.CGPointValue() else {return}
        offset = value.y + originalContentInset.top
        
        
        if refreshing {
            if offset != 0 {
                // Keep thing pinned at the top
                CATransaction.begin()
                //取消隐式动画
                CATransaction.setDisableActions(true)
                shapeLayer.position = CGPointMake(0, kMaxDistance + offset + kOpenedViewHeight) 
                CATransaction.commit()
                
                activity!.center = CGPointMake(floor(frame.size.width / 2),
                                               min(offset + frame.size.height + floor(kOpenedViewHeight / 2), frame.size.height - kOpenedViewHeight / 2))
                
                //scrollView回弹过程，在这个过程中的(offset >= -kOpenedViewHeight)阶段我们改变scrollView的contentInset，但在这里不需要监听contentInset的变化
                ignoreInset = true
                ignoreOffset = true
                
                if offset < 0 {
                    // Set the inset depending on the situation
                    if offset >= -kOpenedViewHeight {
                        if !scrollView.dragging {
                            if !didSetInset {
                                didSetInset = true
                                hasSectionHeaders = false
                                if let tableView = scrollView as? UITableView {
                                    for i in 0 ..< tableView.numberOfSections {
                                        let height = tableView.rectForHeaderInSection(i).size.height
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
            
            if offset > 0 && lastOffset > offset && !scrollView.tracking {
                // If we are scrolling too fast, don't draw, and don't trigger unless the scrollView bounced back
                canRefresh = false
                dontDraw = true
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
        let path = CGPathCreateMutable()
        
        //Calculate some useful points and values
        let verticalShift = max(0, -((kMaxTopRadius + kMaxBottomRadius + kMaxTopPadding + kMaxBottomPadding) + offset))
        let distance = min(kMaxDistance, fabs(verticalShift))
        let percentage = 1 - (distance / kMaxDistance)
        
        let currentTopPadding = lerp(kMinTopPadding, kMaxTopPadding, percentage)
        let currentTopRadius = lerp(kMinTopRadius, kMaxTopRadius, percentage)
        let currentBottomRadius = lerp(kMinBottomRadius, kMaxBottomRadius, percentage)
        let currentBottomPadding =  lerp(kMinBottomPadding, kMaxBottomPadding, percentage)
     
        var bottomOrigin = CGPointMake(floor(bounds.size.width / 2), bounds.size.height - currentBottomPadding - currentBottomRadius)
        var topOrigin = CGPoint.zero
        if distance == 0 {
            topOrigin = CGPointMake(floor(bounds.size.width / 2), bottomOrigin.y)
        } else {
            topOrigin = CGPointMake(floor(bounds.size.width / 2), bounds.size.height + offset + currentTopPadding + currentTopRadius)
            if percentage == 0 {
                bottomOrigin.y -= (fabs(verticalShift) - kMaxDistance)
                triggered = true
            }
        }
        
        //Top semicircle，顶部半圆
        CGPathAddArc(path, nil, topOrigin.x, topOrigin.y, currentTopRadius, 0, CGFloat(M_PI), true)
        
        //Left curve，左侧贝塞尔曲线
        let leftCp1 = CGPointMake(lerp((topOrigin.x - currentTopRadius), (bottomOrigin.x - currentBottomRadius), 0.1), lerp(topOrigin.y, bottomOrigin.y, 0.2))
        let leftCp2 = CGPointMake(lerp((topOrigin.x - currentTopRadius), (bottomOrigin.x - currentBottomRadius), 0.9), lerp(topOrigin.y, bottomOrigin.y, 0.2))
        let leftDestination = CGPointMake(bottomOrigin.x - currentBottomRadius, bottomOrigin.y)
        
        CGPathAddCurveToPoint(path, nil, leftCp1.x, leftCp1.y, leftCp2.x, leftCp2.y, leftDestination.x, leftDestination.y)
        
        //Bottom semicircle，底部半圆
        CGPathAddArc(path, nil, bottomOrigin.x, bottomOrigin.y, currentBottomRadius, CGFloat(M_PI), 0, true)
        
        //Right curve，右侧贝塞尔曲线
        let rightCp2 = CGPointMake(lerp((topOrigin.x + currentTopRadius), (bottomOrigin.x + currentBottomRadius), 0.1), lerp(topOrigin.y, bottomOrigin.y, 0.2))
        let rightCp1 = CGPointMake(lerp((topOrigin.x + currentTopRadius), (bottomOrigin.x + currentBottomRadius), 0.9), lerp(topOrigin.y, bottomOrigin.y, 0.2))
        let rightDestination = CGPointMake(topOrigin.x + currentTopRadius, topOrigin.y)
        
        CGPathAddCurveToPoint(path, nil, rightCp1.x, rightCp1.y, rightCp2.x, rightCp2.y, rightDestination.x, rightDestination.y)
        CGPathCloseSubpath(path)
        
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
            let arrowPath = CGPathCreateMutable()
            CGPathAddArc(arrowPath, nil, 0, 0, arrowBigRadius, 0, CGFloat(3 * M_PI_2), false)
            CGPathAddLineToPoint(arrowPath, nil, 0, 0 - arrowBigRadius - currentArrowSize)
            CGPathAddLineToPoint(arrowPath, nil, 0 + (2 * currentArrowSize), 0 - arrowBigRadius + (currentArrowSize / 2))
            CGPathAddLineToPoint(arrowPath, nil, 0, 0 - arrowBigRadius + (2 * currentArrowSize))
            CGPathAddLineToPoint(arrowPath, nil, 0, 0 - arrowBigRadius + currentArrowSize)
            CGPathAddArc(arrowPath, nil, 0, 0, arrowSmallRadius, CGFloat(3 * M_PI_2), 0, true)
            CGPathCloseSubpath(arrowPath)
            arrowLayer.path = arrowPath
            arrowLayer.fillRule = kCAFillRuleEvenOdd
            
            //随着下拉，旋转arrowLayer
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            arrowLayer.transform = CATransform3DIdentity
            arrowLayer.transform = CATransform3DMakeRotation(percentage*CGFloat(M_PI*2), 0, 0, -1)
            CATransaction.commit()
            
            // Add the highlight shape
            let highlightPath = CGPathCreateMutable()
            CGPathAddArc(highlightPath, nil, topOrigin.x, topOrigin.y, currentTopRadius, 0, CGFloat(M_PI), true)
            CGPathAddArc(highlightPath, nil, topOrigin.x, topOrigin.y + 1.25, currentTopRadius, CGFloat(M_PI), 0, false)
            
            highlightLayer.path = highlightPath
            highlightLayer.fillRule = kCAFillRuleNonZero
            
        } else {
            // Start the shape disappearance animation，隐藏shape layer，显示activity
            
            let radius = lerp(kMinBottomRadius, kMaxBottomRadius, 0.2)
            let pathMorph = CABasicAnimation(keyPath: "path")
            pathMorph.duration = 0.15
            pathMorph.fillMode = kCAFillModeForwards
            pathMorph.removedOnCompletion = false
            let toPath = CGPathCreateMutable()
            CGPathAddArc(toPath, nil, topOrigin.x, topOrigin.y, radius, 0, CGFloat(M_PI), true)
            CGPathAddCurveToPoint(toPath, nil, topOrigin.x - radius, topOrigin.y, topOrigin.x - radius, topOrigin.y, topOrigin.x - radius, topOrigin.y)
            CGPathAddArc(toPath, nil, topOrigin.x, topOrigin.y, radius, CGFloat(M_PI), 0, true)
            CGPathAddCurveToPoint(toPath, nil, topOrigin.x + radius, topOrigin.y, topOrigin.x + radius, topOrigin.y, topOrigin.x + radius, topOrigin.y)
            CGPathCloseSubpath(toPath) 
            pathMorph.toValue = toPath
            shapeLayer.addAnimation(pathMorph, forKey: nil)
            
            let shadowPathMorph = CABasicAnimation(keyPath:"shadowPath")
            shadowPathMorph.duration = 0.15
            shadowPathMorph.fillMode = kCAFillModeForwards
            shadowPathMorph.removedOnCompletion = false
            shadowPathMorph.toValue = toPath
            shapeLayer.addAnimation(shadowPathMorph, forKey: nil)
            
           let shapeAlphaAnimation = CABasicAnimation(keyPath:"opacity")
            shapeAlphaAnimation.duration = 0.1
            shapeAlphaAnimation.beginTime = CACurrentMediaTime() + 0.1
            shapeAlphaAnimation.toValue = NSNumber(float: 0)
            shapeAlphaAnimation.fillMode = kCAFillModeForwards
            shapeAlphaAnimation.removedOnCompletion = false
            shapeLayer.addAnimation(shapeAlphaAnimation, forKey:nil)
            
            let alphaAnimation = CABasicAnimation(keyPath:"opacity")
            alphaAnimation.duration = 0.1
            alphaAnimation.toValue = NSNumber(float: 0)
            alphaAnimation.fillMode = kCAFillModeForwards
            alphaAnimation.removedOnCompletion = false
            arrowLayer.addAnimation(alphaAnimation, forKey:nil)
            highlightLayer.addAnimation(alphaAnimation, forKey:nil)
            
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            activity!.layer.transform = CATransform3DMakeScale(0.1, 0.1, 1)
            CATransaction.commit()
            UIView.animateWithDuration(0.2, delay: 0.15, options: .CurveLinear, animations: { [unowned self] in
                self.activity!.alpha = 1
                self.activity!.layer.transform = CATransform3DMakeScale(1, 1, 1)
                }, completion: nil)
            
            refreshing = true
            canRefresh = false
            
            //刷新过程中，处理相关操作
            //默认方式
            self.sendActionsForControlEvents(.ValueChanged)
            //闭包方式
            if let refreshAction = self.refreshAction {
                refreshAction(refreshControl: self)
            }
            //代理回调方式
            if let delegate = self.delegate {
                delegate.onRefresh(self)
            }
        }
        
    }
    
    
    //MARK: - utils method
    
    //求插值
    private func lerp(a: CGFloat, _ b: CGFloat, _ p: CGFloat) -> CGFloat {
        return a + (b - a) * p
    }
    
    private func addObserver() {
        scrollView?.xb_addObserver(forKeyPath: kContentOffset, options: .New, context: nil, closure: { [unowned self](keyPath, object, change, context) in
            self.xb_observeValueForKeyPath(keyPath, ofObject: object, change: change, context: context)
        })
        
        scrollView?.xb_addObserver(forKeyPath: kContentInset, options: .New, context: nil, closure: { [unowned self](keyPath, object, change, context) in
            self.xb_observeValueForKeyPath(keyPath, ofObject: object, change: change, context: context)
        })
    
    }
    
    @objc private func hideRefreshControl() {
        UIView.animateWithDuration(0.4, animations: { [weak self] in
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
                    self!.shapeLayer.position = CGPointZero
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
    public func beginRefreshing() {
        if (!refreshing) {
            guard let scrollView = self.scrollView else {return}
            
            let alphaAnimation = CABasicAnimation(keyPath:"opacity")
            alphaAnimation.duration = 0.0001 
            alphaAnimation.toValue = NSNumber(float: 0)
            alphaAnimation.fillMode = kCAFillModeForwards
            alphaAnimation.removedOnCompletion = false
            shapeLayer.addAnimation(alphaAnimation, forKey: nil)
            arrowLayer.addAnimation(alphaAnimation, forKey: nil)
            highlightLayer.addAnimation(alphaAnimation, forKey: nil)
            
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
    public func endRefreshing() {
        if (refreshing) {
            refreshing = false
            
            var delay: NSTimeInterval = 0
            if let endRefreshView = self.endRefreshView {
                //show the endRefreshView
                endRefreshView.center = activity!.center
                endRefreshView.alpha = 0
                addSubview(endRefreshView)
                delay = 0.5
            }
            
            if delay > 0 {
                UIView.animateWithDuration(0.15, animations: { [weak self] in
                    if self != nil {
                        self!.endRefreshView?.alpha = 1
                        self!.activity!.alpha = 0
                        self!.activity!.layer.transform = CATransform3DMakeScale(0.1, 0.1, 1)
                    }
                })
            }
            
            //hide view with animation
            performSelector(#selector(hideRefreshControl), withObject: nil, afterDelay: delay)
        }
    }
    
    ///判断刷新状态
    public func isRefreshing() -> Bool {
        return refreshing
    }
    
    public func setEndRefreshView(view: UIView?) {
        endRefreshView = view
    }
    
    public override var enabled: Bool {
        didSet {
            shapeLayer.hidden = !enabled
        }
    }
    
    public override var tintColor: UIColor! {
        didSet {
            shapeLayer.fillColor = tintColor.CGColor
        }
    }
    
    public func setActivityIndicatorViewColor(color: UIColor) {
        if let activity = activity as? UIActivityIndicatorView {
            activity.color = color
        }
    }
    
    public func setActivityIndicatorViewStyle(style: UIActivityIndicatorViewStyle) {
        if let activity = activity as? UIActivityIndicatorView {
            activity.activityIndicatorViewStyle = style
        }
    }
}

