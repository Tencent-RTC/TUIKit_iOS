Pod::Spec.new do |spec|
  spec.name                  = 'TUIRoomKit'
  spec.version               = '2.0.0'
  spec.platform              = :ios
  spec.ios.deployment_target = '14.0'
  spec.license               = { :type => 'MIT', :file => 'LICENSE' }
  spec.homepage              = 'https://cloud.tencent.com/product/trtc'
  spec.documentation_url     = 'https://cloud.tencent.com/document/product/647'
  spec.authors               = 'Tencent Cloud'
  spec.summary               = 'TUIRoomKit V2 for iOS - Room management UI components based on TRTC and IM SDK'
  spec.description           = <<-DESC
                               TUIRoomKit V2 is a comprehensive room management UI component library built on top of
                               Tencent Cloud Real-Time Communication (TRTC) and Instant Messaging (IM) SDK.
                               It provides complete room creation, joining, and management features with AtomicXCore
                               state-driven architecture.
                               DESC
  
  spec.static_framework = true
  spec.xcconfig      = { 'VALID_ARCHS' => 'armv7 arm64 x86_64' }
  spec.swift_version = '5.0'

  spec.source                = { :path => './' }
  
  # Core dependencies
  spec.dependency 'SnapKit'
  spec.dependency 'Kingfisher'
  spec.dependency 'AtomicX'
  
  spec.default_subspec = 'Professional'
  
  spec.subspec 'Professional' do |professional|
    professional.dependency 'RTCRoomEngine/Professional'
    professional.dependency 'AtomicXCore'
    
    professional.source_files = 'Source/**/*.{swift,h,m}'
    professional.resource_bundles = {
      'TUIRoomKit' => [
        'Resources/*.xcassets',
        'Resources/Localized/*.xcstrings',
        'Resources/**/*.mp3'
      ]
    }
  end
  
  spec.subspec 'TRTC' do |trtc|
    trtc.dependency 'RTCRoomEngine/TRTC'
    trtc.dependency 'AtomicXCore'
    
    trtc.source_files = 'Source/**/*.{swift,h,m}'
    trtc.resource_bundles = {
      'TUIRoomKit' => [
        'Resources/*.xcassets',
        'Resources/Localized/*.xcstrings',
        'Resources/**/*.mp3'
      ]
    }
  end
end
