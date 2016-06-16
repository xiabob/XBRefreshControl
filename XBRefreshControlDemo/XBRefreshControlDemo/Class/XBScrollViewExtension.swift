//
//  XBScrollViewExtension.swift
//  XBRefreshControlDemo
//
//  Created by xiabob on 16/6/15.
//  Copyright © 2016年 xiabob. All rights reserved.
//

import UIKit


public typealias XBUIScrollViewObserverClosure = (keyPath: String?,  object: AnyObject?, change: [String : AnyObject]?, context: UnsafeMutablePointer<Void>) -> ()

//将closure封装成一个对象
private class XBClosureObject<T> {
    let closure: T?
    init (closure: T?) {
        self.closure = closure
    }
}

private var xb_observerClosureKey = "xb_observerClosureKey"
private var xb_observerKeyPathKey = "xb_observerKeyPathKey"

public extension UIScrollView {
    
    private var xb_observerClosure: XBUIScrollViewObserverClosure? {
        set {
            let object = XBClosureObject<XBUIScrollViewObserverClosure>(closure: newValue)
            objc_setAssociatedObject(self, &xb_observerClosureKey, object, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
        
        get {
            guard let object = objc_getAssociatedObject(self, &xb_observerClosureKey) as? XBClosureObject<XBUIScrollViewObserverClosure> else {return nil}
            
            return object.closure
        }
    }
    
    private var xb_observerKeyPaths: [String] {
        set {
            objc_setAssociatedObject(self, &xb_observerKeyPathKey, newValue, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
        
        get {
            guard let paths = objc_getAssociatedObject(self, &xb_observerKeyPathKey) as? [String] else {return []}
            
            return paths
        }
    }
    
    ///通过本方法添加属性观察，在UIScrollView被释放前会自动remove观察者
    public func xb_addObserver(forKeyPath keyPath: String, options: NSKeyValueObservingOptions, context: UnsafeMutablePointer<Void>, closure: XBUIScrollViewObserverClosure?) {
        xb_observerClosure = closure
        xb_observerKeyPaths.append(keyPath)
        addObserver(self, forKeyPath: keyPath, options: options, context: context)
    }
    
    public func xb_removeObserver(forKeyPath keyPath: String) {
        removeKeyPath(keyPath)
        removeObserver(self, forKeyPath: keyPath)
    }
    
    public override func observeValueForKeyPath(keyPath: String?, ofObject object: AnyObject?, change: [String : AnyObject]?, context: UnsafeMutablePointer<Void>) {
        if xb_observerClosure != nil {
            xb_observerClosure!(keyPath: keyPath, object: object, change: change, context: context)
        }
    }
    
    public override func willMoveToSuperview(newSuperview: UIView?) {
        super.willMoveToSuperview(newSuperview)
        
        if newSuperview == nil && xb_observerKeyPaths.count > 0 {
            let paths = xb_observerKeyPaths
            for keyPath in paths {
                xb_removeObserver(forKeyPath: keyPath)
            }
        }
    }
    
    private func removeKeyPath(keyPath: String) {
        guard let index = xb_observerKeyPaths.indexOf(keyPath) else {return}
        xb_observerKeyPaths.removeAtIndex(index)
    }
}
