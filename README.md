# XBRefreshControl
下拉刷新控件，纯swift框架，inspired by [ODRefreshControl](https://github.com/Sephiroth87/ODRefreshControl)

![](https://github.com/xiabob/XBRefreshControl/blob/master/screenshots/sam.gif)

#要求
* iOS7.0+
* Xcode 7.3+ 

#安装
将Class目录下的XBRefreshControl.swift、XBScrollViewExtension.swift导入到工程即可

#使用
具体使用参看demo工程
* 第一种使用方法：addTarget


<pre>
let refresh = XBRefreshControl(scrollView: tableView, activityIndicatorView: UIActivityIndicatorView(activityIndicatorStyle: .Gray), delegate: nil, refreshAction: nil)
refresh.addTarget(self, action: #selector(dropViewDidBeginRefreshing), forControlEvents: .ValueChanged)
</pre>

* 第二种使用方法：闭包回调
<pre>
let _ = XBRefreshControl(scrollView: tableView, refreshAction: { [unowned self](refreshControl) in
       self.dropViewDidBeginRefreshing(refreshControl)
    })
</pre>

*  第三种使用方法：代理
 
<pre>
let _ = XBRefreshControl(scrollView: tableView, delegate: self)

//XBRefreshControlDelegate
func onRefresh(refreshControl: XBRefreshControl) {
     dropViewDidBeginRefreshing(refreshControl)
}
</pre>
