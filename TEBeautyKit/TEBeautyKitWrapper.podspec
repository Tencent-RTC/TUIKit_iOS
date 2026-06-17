Pod::Spec.new do |spec|
  spec.name                    = 'TEBeautyKitWrapper'
  spec.version                 = '1.0.0'
  spec.homepage                = 'https://trtc.io/'
  spec.documentation_url       = 'https://trtc.io/document'
  spec.license                 = { :type => 'MIT', :file => 'LICENSE' }
  spec.authors                 = 'trtc.io'
  spec.summary                 = 'TUIBeautyKit wrapper for TUICore-based beauty panel integration.'

  spec.platform                = :ios
  spec.ios.deployment_target   = '13.0'
  spec.static_framework        = true
  spec.swift_version           = '5.0'

  spec.source                  = { :path => './' }

  spec.dependency 'TUICore'
  spec.dependency 'SnapKit'

  spec.default_subspec = 'Package'

  spec.subspec 'Package' do |ss|
    ss.source_files = '*.swift'
    ss.dependency 'TEBeautyKit'
  end

  spec.subspec 'Game' do |ss|
    ss.source_files = '*.swift'
    ss.dependency 'TEBeautyKit/Game'
  end
end
