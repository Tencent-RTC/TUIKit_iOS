Pod::Spec.new do |spec|
  spec.name                  = 'AppAssembly'
  spec.version               = '1.0.0'
  spec.platform              = :ios
  spec.ios.deployment_target = '13.0'
  spec.license               = { :type => 'MIT', :file => 'LICENSE' }
  spec.homepage              = 'https://cloud.tencent.com/document/product/269/3794'
  spec.documentation_url     = 'https://cloud.tencent.com/document/product/269/9147'
  spec.authors               = 'tencent video cloud'
  spec.summary               = 'RT-Cube App Assembly — 业务模块装配层，提供首页场景列表'

  spec.static_framework = true
  spec.xcconfig      = { 'VALID_ARCHS' => 'armv7 arm64 x86_64' }
  spec.swift_version = '5.0'

  spec.source = { :path => './' }

  spec.dependency 'TUICore'
  spec.dependency 'RTCCommon'
  spec.dependency 'Alamofire'
  spec.dependency 'SnapKit'
  spec.dependency 'AtomicX'
  spec.dependency 'AtomicXCore'

  # live
  spec.dependency 'TUILiveKit' # live

  # call
  spec.dependency 'TUICallKit_Swift' # call
  spec.dependency 'JXSegmentedView', '1.3.0' # call
  spec.dependency 'JXPagingView/Paging', '2.1.2' # call
  spec.dependency 'Toast-Swift' # call

  # room
  spec.dependency 'TUIRoomKit' # room

  spec.default_subspecs = 'OpenSource'

  spec.subspec 'OpenSource' do |ss|
    modules = %w[Resource Call Live VoiceRoom Room Interpretation ScenesApplication]

    ss.dependency 'Login/OpenSource'

    ss.source_files = [
      '*.swift',
      'Extension/**/*.{swift,h,m}',
      'Modules/Interface/**/*.{swift,h,m}',
      'Modules/AtomicXCoreLogin.swift',
      *modules.map { |m| "Modules/#{m}/**/*.{swift,h,m}" },
    ]
    ss.resource_bundles = {
      'AppAssemblyBundle' => modules.map { |m| "Modules/#{m}/**/*.{xcassets,strings,json}" },
    }
  end

end
