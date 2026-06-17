#
# Be sure to run `pod lib lint TEBeautyKit.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |spec|
  spec.name                    = 'VideoAdvanceExtension'
  spec.version                 = '1.0.0'
  spec.homepage                = 'https://github.com/Tencent-RTC/TUILiveKit.git'
  spec.license                 = { :type => 'MIT', :file => 'LICENSE' }
  spec.authors                 = 'trtc.io'
  spec.summary                 = 'trtc.io for Live streaming Solution..'

  spec.platform                = :ios
  spec.ios.deployment_target   = '13.0'
  spec.static_framework        = true
  spec.swift_version           = '5.0'

  spec.source                  = { :path => './' }

  spec.dependency              'TUICore'

  spec.default_subspec         = 'Professional'
  
  spec.subspec 'TRTC' do |trtc|
    trtc.dependency            'RTCRoomEngine/TRTC'
    trtc.source_files          = 'Sources/**/*.{m,h}'
  end

  spec.subspec 'Professional' do |professional|
    professional.dependency    'RTCRoomEngine/Professional'
    professional.source_files  = 'Sources/**/*.{m,h}'
  end
  
end
