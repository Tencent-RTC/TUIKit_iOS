Pod::Spec.new do |spec|
  spec.name = 'TUICallKit_Swift'
  spec.version = '1.0.0'
  spec.summary = 'UIKit call components powered by AtomicXCore.'
  spec.homepage = 'https://github.com/Tencent-RTC'
  spec.license = { :type => 'MIT' }
  spec.author = 'Tencent RTC'
  spec.source = {
    :git => 'git@git.woa.com:crdc/tuikit/atomic_uikit.git',
    :tag => spec.version.to_s
  }

  spec.platform = :ios, '15.0'
  spec.swift_version = '5.0'
  spec.static_framework = true

  spec.source_files = 'Sources/TUICallKit_Swift/**/*.swift'
  spec.resource_bundles = {
    'TUICallKitBundle' => ['Resources/**/*']
  }

  spec.dependency 'AtomicXCore'
  spec.dependency 'SnapKit'
end
