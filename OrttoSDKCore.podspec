Pod::Spec.new do |s|
  s.name             = 'OrttoSDKCore'
  s.version          = '1.2.0'
  s.summary          = 'OrttoSDK'
  s.homepage         = 'https://github.com/autopilot3/ortto-push-ios-sdk'
  s.license          = { :type => 'MIT', :file => 'LICENSE.md' }
  s.author           = { 'Ortto.com Team' => 'help@ortto.com' }
  s.source           = { :git => 'https://github.com/autopilot3/ortto-push-ios-sdk.git', :tag => s.version.to_s }
  s.swift_version    = '5.0'
  s.source_files     = 'Sources/PushSDKCore/**/*'
  s.ios.deployment_target = '13.0'
  s.documentation_url = 'https://help.ortto.com/developer/latest/developer-guide/push-sdks/'
end