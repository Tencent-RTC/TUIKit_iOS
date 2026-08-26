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

  spec.default_subspecs = 'OpenSource'

  spec.subspec 'OpenSource' do |ss|
    ss.source_files = 'Opensource/**/*.{swift,h,m}'
    ss.resource_bundles = {
      'LoginResources' => [
        'Resource/**/*.xcassets',
        'Opensource/Resource/**/*.xcstrings',
      ]
    }
    ss.dependency 'TUICore'
    ss.dependency 'AtomicX'
    ss.dependency 'SnapKit'
    ss.dependency 'Kingfisher'
    ss.dependency 'Toast-Swift'
  end

end
