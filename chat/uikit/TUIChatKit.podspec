
Pod::Spec.new do |s|
    s.name             = 'TUIChatKit'
    s.version          = '9.1.7821'
    s.summary          = 'AtomicX Chat Component'
    s.description      = 'Chat streaming component for AtomicX'
    s.homepage         = 'https://cloud.tencent.com/document/product/269'
    s.license          = { :type => 'MIT', :file => 'LICENSE' }
    s.author           = { 'Tencent Cloud' => 'im@tencent.com' }
    s.source           = { :git => 'https://github.com/Tencent-RTC/TUIKit_iOS.git', :tag => s.version.to_s }
    s.ios.deployment_target = '14.0'
    s.swift_version    = '5.0'
    s.static_framework = true
    s.frameworks       = 'UIKit', 'Foundation', 'AudioToolbox', 'AVFoundation', 'AVKit', 'SwiftUI', 'SafariServices'

    s.dependency 'Kingfisher'
    s.dependency 'TXLiteAVSDK_VoiceAI_iOS', '13.6.0.255'
    s.dependency 'AtomicXCore', '>= 3.0.0', '< 5.0'
    s.dependency 'SnapKit'
    s.dependency 'AlbumPicker', '~> 1.0.0'
    s.dependency 'tui-cmark-gfm', '0.29.0.15'

    s.source_files     = '**/*.{swift,h,m}'
    s.resource_bundles = {
        'TUIChatKitBundle' => [
            'resources/strings/**/*.{bundle,xcstrings}',
            'resources/assets/chat/**/*.{xcassets,json,png,bundle}'
        ]
    }

end
