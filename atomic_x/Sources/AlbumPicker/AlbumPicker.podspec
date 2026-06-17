Pod::Spec.new do |s|
  s.name             = 'AlbumPicker'
  s.version          = '1.0.0'
  s.summary          = 'UI layer for AlbumPicker.'
  s.description      = <<-DESC
  AlbumPicker provides the main AlbumPicker view and public API for integrating album picking functionality.
                       DESC
  s.homepage         = 'https://trtc.io/'
  s.documentation_url= 'https://trtc.io/document'
  s.license          = { :type => 'MIT' }
  s.authors          = 'trtc.io'
  s.source           = { :path => './' }
  s.ios.deployment_target = '13.0'

  s.swift_version    = '5.0'
  s.frameworks       = 'UIKit', 'Foundation', 'Photos'

  s.dependency 'AlbumPickerCore'

  s.source_files     = [
    '**/*.{swift,h,m}'
  ]

  s.resource_bundles = {
    'AlbumPickerBundle' => [
      'Resources/**/*.{xcstrings,xcassets,json,png,svg}'
    ]
  }
end
