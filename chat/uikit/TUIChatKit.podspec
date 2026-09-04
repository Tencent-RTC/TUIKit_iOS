
Pod::Spec.new do |s|
    s.name             = 'TUIChatKit'
    s.version          = '1.0.0'
    s.summary          = 'AtomicX Chat Component'
    s.description      = 'Chat streaming component for AtomicX'
    s.homepage         = 'https://cloud.tencent.com/document/product/269'
    s.license          = { :type => 'MIT', :file => 'LICENSE' }
    s.author           = { 'Tencent Cloud' => 'im@tencent.com' }
    s.source           = { :git => 'https://github.com/TencentCloud/chat-uikit-ios.git', :tag => s.version.to_s }
    s.ios.deployment_target = '14.0'
    s.swift_version    = '5.0'
    s.static_framework = true
    s.frameworks       = 'UIKit', 'Foundation', 'AVFoundation', 'AVKit', 'SwiftUI', 'SafariServices'

    s.dependency 'Kingfisher'
    s.dependency 'AtomicXCore'
    s.dependency 'Masonry'
    s.dependency 'SnapKit'
    s.dependency 'AlbumPicker'
    s.dependency 'TUICallKit_Swift'

    s.source_files     = '**/*.{swift,h,m}'
    s.resource_bundles = {
        'TUIChatKitBundle' => [
            'resources/strings/**/*.{bundle,xcstrings}',
            'resources/assets/chat/**/*.{xcassets,json,png,bundle}'
        ]
    }

end
