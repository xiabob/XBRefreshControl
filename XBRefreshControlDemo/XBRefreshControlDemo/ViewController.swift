//
//  ViewController.swift
//  XBRefreshControlDemo
//
//  Created by xiabob on 16/6/14.
//  Copyright © 2016年 xiabob. All rights reserved.
//

import UIKit

class ViewController: UIViewController, XBRefreshControlDelegate {
    var tableView: UITableView = UITableView()

    override func viewDidLoad() {
        super.viewDidLoad()
        
        //对于ios7+带有导航栏的情况，需要按照下面两种方式之一设置
        //方式一
        automaticallyAdjustsScrollViewInsets = false
        navigationController?.navigationBar.isTranslucent = false
        
        //方式二
//        edgesForExtendedLayout = .None
        
        tableView = UITableView(frame: CGRect(x: 0, y: 0, width: view.bounds.size.width, height: 300))
        tableView.backgroundColor = UIColor.white
        view.addSubview(tableView)
        
        //第一种使用方法：addTarget
        let refresh = XBRefreshControl(activityIndicatorView: UIActivityIndicatorView(activityIndicatorStyle: .gray), delegate: nil, refreshAction: nil)
        refresh.tintColor = UIColor.orange
        refresh.setActivityIndicatorViewStyle(.gray)
        tableView.xb_refreshHeader = refresh
        refresh.addTarget(self, action: #selector(dropViewDidBeginRefreshing), for: .valueChanged)
        
        //第二种使用方法：闭包回调
//        let refresh = XBRefreshControl { [unowned self](refreshControl) in
//            self.dropViewDidBeginRefreshing(refreshControl)
//        }
//        tableView.xb_refreshHeader = refresh
        
        //第三种使用方法：代理
//        let refresh = XBRefreshControl(delegate: self)
//        tableView.xb_refreshHeader = refresh
    }
    
    // XBRefreshControlDelegate
    func onRefresh(_ refreshControl: XBRefreshControl) {
        dropViewDidBeginRefreshing(refreshControl: refreshControl)
    }

    func dropViewDidBeginRefreshing(refreshControl: XBRefreshControl) {
        let popTime = DispatchTime.now() + 2
        DispatchQueue.main.asyncAfter(deadline: popTime) { 
            let label = UILabel()
            label.bounds = CGRect(x: 0, y: 0, width: 100, height: 20)
            label.textColor = UIColor.gray
            label.font = UIFont.systemFont(ofSize: 14)
            label.textAlignment = .center
            label.text = "刷新完成"
            refreshControl.setEndRefreshView(label)
            
            refreshControl.endRefreshing()
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    deinit {
        debugPrint("\(self) deinit")
    }
}

