Pod::Spec.new do |spec|
  spec.name = 'TUIRoomKit'
  spec.version = '0.1.0'
  spec.summary = 'UIKit meeting room components powered by AtomicXCore.'
  spec.homepage = 'https://github.com/Tencent-RTC'
  spec.license = { :type => 'MIT' }
  spec.author = 'Tencent RTC'
  spec.source = {
    :git => 'git@git.woa.com:crdc/tuikit/atomic_uikit.git',
    :tag => spec.version.to_s
  }

  spec.platform = :ios, '14.0'
  spec.swift_version = '5.0'
  spec.static_framework = true
  # 屏幕分享要用 RPSystemBroadcastPickerView 拉起系统广播面板。
  spec.frameworks = 'ReplayKit'

  spec.source_files = 'Sources/**/*.swift'
  spec.dependency 'AtomicXCore'
  spec.dependency 'SnapKit', '~> 5.7'
  spec.resource_bundles = {
    'TUIRoomKitBundle' => ['Resources/TUIRoomKitIcons.xcassets', 'Resources/**/*.lproj']
  }

  spec.dependency 'SnapKit'
  spec.dependency 'AtomicXCore'
end
