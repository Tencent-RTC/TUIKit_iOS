Pod::Spec.new do |spec|
  spec.name = 'TUILiveKit'
  spec.version = '1.0.0'
  spec.summary = 'UIKit live streaming components powered by AtomicXCore.'
  spec.homepage = 'https://github.com/Tencent-RTC'
  spec.license = { :type => 'MIT' }
  spec.author = 'Tencent RTC'
  spec.source = {
    :git => 'https://github.com/Tencent-RTC/TUIKit_iOS.git',
    :tag => spec.version.to_s
  }

  spec.platform = :ios, '14.0'
  spec.swift_version = '5.0'
  spec.static_framework = true

  spec.source_files = 'Sources/TUILiveKit/**/*.swift'
  spec.resource_bundles = {
    'TUILiveKitBundle' => ['Resources/**/*']
  }

  spec.dependency 'AtomicXCore', '5.2.0'
  spec.dependency 'TXLiteAVSDK_Professional'
  spec.dependency 'SnapKit', '~> 5.7'
  spec.dependency 'TXIMSDK_Plus_iOS_XCFramework'
  spec.dependency 'YTCommonXMagic', '1.3.1'
  spec.dependency 'TCMediaX'
  spec.dependency 'TCEffectPlayer'
  spec.dependency 'Kingfisher'
end
