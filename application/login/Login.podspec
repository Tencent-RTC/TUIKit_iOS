Pod::Spec.new do |spec|
  spec.name                  = 'Login'
  spec.version               = '1.0.0'
  spec.platform              = :ios
  spec.ios.deployment_target = '13.0'
  spec.license               = { :type => 'MIT', :file => 'LICENSE' }
  spec.homepage              = 'https://cloud.tencent.com/document/product/269/3794'
  spec.documentation_url     = 'https://cloud.tencent.com/document/product/269/9147'
  spec.authors               = 'tencent video cloud'
  spec.summary               = 'RT-Cube Login Module — 登录模块，支持手机号/邮箱/iOA/邀请码/Debug 登录'

  spec.static_framework = true
  spec.xcconfig      = { 'VALID_ARCHS' => 'armv7 arm64 x86_64' }
  spec.swift_version = '5.0'

  spec.source = { :path => './' }

  spec.dependency 'TUICore'
  spec.dependency 'Alamofire'
  spec.dependency 'SnapKit'
  spec.dependency 'Kingfisher'
  spec.dependency 'Toast-Swift'
  spec.dependency 'AtomicX'

  spec.default_subspecs = 'OpenSource'

  spec.subspec 'OpenSource' do |ss|
    ss.source_files = '**/*.{swift,h,m}'
    ss.exclude_files = [
      'Frameworks/**/*',
      'IOAAuth/*',
      'IOAAuth/**/*',
    ]
    ss.resource_bundles = {
      'LoginResources' => [
        'Resource/**/*.xcassets',
        'Resource/**/*.strings',
        'Resource/**/*.html',
      ]
    }
  end

end
