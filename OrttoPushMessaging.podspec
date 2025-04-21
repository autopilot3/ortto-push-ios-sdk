Pod::Spec.new do |s|
  s.name             = 'OrttoPushMessaging'
  s.version          = '1.7.0'
  s.summary          = 'OrttoSDK Push Messaging Core Module'
  s.homepage         = 'https://github.com/autopilot3/ortto-push-ios-sdk'
  s.license          = { :type => 'MIT', :file => 'LICENSE.md' }
  s.author           = { 'Ortto.com Team' => 'help@ortto.com' }
  s.source           = { :git => 'https://github.com/autopilot3/ortto-push-ios-sdk.git', :tag => "v#{s.version}" }
  s.source_files     = 'Sources/PushMessaging/**/*'
  s.swift_version    = '5.0'
  s.platform         = :ios
  s.ios.deployment_target = '13.0'
  s.documentation_url = 'https://help.ortto.com/developer/latest/developer-guide/push-sdks/'
  s.dependency "OrttoSDKCore", "= #{s.version.to_s}"
end
