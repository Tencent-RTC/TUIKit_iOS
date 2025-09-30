
Pod::Spec.new do |s|
    s.name             = 'ChatUIKit'
    s.version          = '1.0.0'
    s.summary          = 'AtomicX Chat Component'
    s.description      = 'Chat streaming component for AtomicX'
    s.homepage         = 'https://example.com'
    s.license          = { :type => 'MIT', :file => 'LICENSE' }
    s.author           = { 'Your Name' => 'your.email@example.com' }
    s.source           = { :git => 'https://github.com/your-repo/atomic-x-chat.git', :tag => s.version.to_s }
    s.ios.deployment_target = '14.0'
    s.swift_version    = '5.0'

    s.dependency 'Kingfisher'
    s.dependency 'AtomicXCore'
    s.dependency 'Masonry'
    s.dependency 'AtomicX/Chat'

    s.source_files     = '*.{swift,h,m}'
    # s.resources = [
    #     'Resources/assets/chat/**/*.{xcassets,json,png}',
    #     'Resources/strings/ChatLocalizable.bundle',
    #     'Resources/strings/EmojiFace.bundle'
    # ]
    # s.resource_bundles = {        
    #     'AtomicXBundle' => [
    #         'Resources/assets/**/*.{xcassets,json,png,bundle}',
    #         'Resources/strings/ChatLocalizable.bundle',
    #         'Resources/strings/EmojiFace.bundle',
    #         'Resources/strings/VideoRecorderLocalizable.bundle',
    #     ]
    # }

end
