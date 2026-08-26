
Pod::Spec.new do |s|
    s.name             = 'ChatUIKit'
    s.version          = '1.0.0'
    s.summary          = 'AtomicX Chat Component'
    s.description      = 'Chat streaming component for AtomicX'
    s.homepage         = 'https://example.com'
    s.license          = { :type => 'MIT', :file => 'LICENSE' }
    s.author           = { 'Your Name' => 'your.email@example.com' }
    s.source           = { :git => 'https://github.com/your-repo/atomic-x-chat.git', :tag => s.version.to_s }
    s.ios.deployment_target = '15.0'
    s.swift_version    = '5.0'
    s.frameworks       = 'UIKit', 'Foundation', 'AVFoundation', 'AVKit', 'SwiftUI', 'SafariServices'

    s.dependency 'Kingfisher'
    s.dependency 'AtomicXCore'
    s.dependency 'Masonry'
    s.dependency 'SnapKit'
    s.dependency 'AlbumPicker'
    s.dependency 'TUICallKit_Swift'

    s.source_files     = '**/*.{swift,h,m}'
    s.resource_bundles = {
        'ChatUIKitBundle' => [
            'resources/strings/**/*.{bundle,xcstrings}',
            'resources/assets/chat/**/*.{xcassets,json,png,bundle}'
        ]
    }

end
