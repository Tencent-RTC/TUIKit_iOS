Pod::Spec.new do |s|
  s.name             = 'TXKTVScore'
  s.version          = '1.0.0'
  s.summary          = 'KTV Score dynamic library for copyrighted music scoring.'
  s.homepage         = 'https://trtc.io/'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = 'trtc.io'
  s.source           = { :path => './' }

  s.platform         = :ios
  s.ios.deployment_target = '13.0'

  s.vendored_frameworks = ['txktvscore.xcframework']
  s.pod_target_xcconfig = { 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'arm64' }
end
