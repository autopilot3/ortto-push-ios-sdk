Pod::Spec.new do |s|
  s.name             = 'OrttoPushMessagingAPNS'
  s.version          = '1.8.4'
  s.summary          = 'OrttoSDK Push Messaging APNS Module'
  s.homepage         = 'https://github.com/autopilot3/ortto-push-ios-sdk'
  s.license          = { :type => 'MIT', :file => 'LICENSE.md' }
  s.author           = { 'Ortto.com Team' => 'help@ortto.com' }
  s.source           = { :git => 'https://github.com/autopilot3/ortto-push-ios-sdk.git', :tag => "v#{s.version}" }
  s.source_files     = 'Sources/PushMessagingAPNS/**/*'
  s.platform         = :ios
  s.ios.deployment_target = '15.0'
  s.swift_version   = '5.10'            
  s.documentation_url = 'https://help.ortto.com/developer/latest/developer-guide/push-sdks/'
  s.dependency "OrttoPushMessaging", "= #{s.version.to_s}"
end
