Pod::Spec.new do |s|
  s.name             = 'AtomicX'
  s.version          = '1.0.0'
  s.summary          = 'A collection of UI components and utilities for AtomicX.'
  s.description      = <<-DESC
  AtomicX provides a set of reusable UI components and utilities designed for modern iOS applications.
                       DESC
  s.homepage         = 'https://trtc.io/'
  s.documentation_url= 'https://trtc.io/document'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.authors          = 'trtc.io'
  s.source           = { :path => './' }
  s.ios.deployment_target = '13.0'

  # Main spec
  s.swift_version    = '5.0'
  s.frameworks       = 'UIKit', 'Foundation'

  s.dependency 'RTCRoomEngine/Professional'
  s.dependency 'SnapKit'
  s.dependency 'RTCCommon'
  s.dependency 'TXLiteAVSDK_Professional', '>= 12.8', '< 13.0'
  s.dependency 'TUICore'
  s.dependency 'Kingfisher'
  s.dependency 'AtomicXCore'
  s.dependency 'TXIMSDK_Plus_iOS_XCFramework', '>= 8.8.7357'
  
  s.static_framework = true

  s.source_files     = [
    'Sources/**/*.{swift,h,m}'
  ]
  s.exclude_files = [
    'Sources/TCEffectPlayerKit/**/*.{swift,h,m}',
    'Sources/TEBeautyKit/**/*.{swift,h,m}',
    'Sources/VideoAdvanceExtension/**/*.{swift,h,m}'
  ]
  s.resource_bundles = {
    'AtomicXBundle' => ['Resources/**/*.{xcassets,json,png,xcstrings,vtt,mp3,json,flac,gif}']
  }
end
