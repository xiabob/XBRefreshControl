Pod::Spec.new do |s|
  s.name         = 'XBRefreshControl'
  s.version      = ‘1.0’
  s.authors      = { 'xiabob' => 'xiabob@yeah.net' }
  s.homepage     = 'https://github.com/xiabob/XBRefreshControl'
  s.summary      = 'A pull down RefreshControl by swift.'
  s.license      = 'MIT'
  s.source       = { :git => 'https://github.com/xiabob/XBRefreshControl.git', :tag => ‘1.0’ }
  s.source_files = 'XBRefreshControl/*.swift'

  s.requires_arc = true

  s.platform     = :ios, '8.0'
  s.ios.deployment_target = '8.0'

end
