//
//  XBScrollViewExtension.swift
//  XBRefreshControlDemo
//
//  Created by xiabob on 16/6/15.
//  Copyright © 2016年 xiabob. All rights reserved.
//

import UIKit


private var xb_observerKeyHeaderKey = "xb_observerKeyHeaderKey"

public extension UIScrollView {
    public var xb_refreshHeader: XBRefreshControl? {
        set {
            if xb_refreshHeader != newValue && newValue != nil {
                //删除旧的，添加新的
                xb_refreshHeader?.removeFromSuperview()
                addSubview(newValue!)

                objc_setAssociatedObject(self, xb_observerKeyHeaderKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            }
        }
        
        get {
            let header = objc_getAssociatedObject(self, xb_observerKeyHeaderKey) as? XBRefreshControl
            return header
        }
    }
}
