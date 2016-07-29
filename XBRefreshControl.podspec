Pod::Spec.new do |s|
  s.name         = 'XBRefreshControl'
  s.version      = '0.9'
  s.summary      = 'A pull down RefreshControl by swift.'
  s.description  = <<-DESC
		    RefreshControl by swift
                   DESC

  s.homepage     = 'https://github.com/xiabob/XBRefreshControl'
  s.license      = 'MIT'
  # s.license      = { :type => "MIT", :file => "FILE_LICENSE" }
  s.authors       = { 'xiabob' => 'xiabob@yeah.net' }
  s.platform     = :ios, '7.0'
  s.ios.deployment_target = '7.0'
  s.source       = { :git => 'https://github.com/xiabob/XBRefreshControl.git', :tag => '0.9' }
  s.source_files = 'XBRefreshControl/*.swift’
  s.requires_arc = true


end
