Pod::Spec.new do |s|
  s.name             = 'OrttoPushMessagingFCM'
  s.version          = '1.2.2'
  s.summary          = 'OrttoSDK Push Messaging Firebase Module'
  s.homepage         = 'https://github.com/autopilot3/ortto-push-ios-sdk'
  s.license          = { :type => 'MIT', :file => 'LICENSE.md' }
  s.author           = { 'Ortto.com Team' => 'help@ortto.com' }
  s.source           = { :git => 'https://github.com/autopilot3/ortto-push-ios-sdk.git', :tag => s.version.to_s }
  s.source_files     = 'Sources/PushMessagingFCM/**/*'
  s.swift_version    = '5.0'
  s.platform         = :ios
  s.ios.deployment_target = '13.0'
  s.documentation_url = 'https://help.ortto.com/developer/latest/developer-guide/push-sdks/'
  s.dependency "OrttoSDKCore", "= #{s.version.to_s}"
  s.dependency "FirebaseMessaging", "~> 8"
end
