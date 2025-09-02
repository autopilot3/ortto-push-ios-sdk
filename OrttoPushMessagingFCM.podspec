Pod::Spec.new do |s|
  s.name             = 'OrttoPushMessagingFCM'
  s.version          = '1.8.0'
  s.summary          = 'OrttoSDK Push Messaging Firebase Module'
  s.homepage         = 'https://github.com/autopilot3/ortto-push-ios-sdk'
  s.license          = { :type => 'MIT', :file => 'LICENSE.md' }
  s.author           = { 'Ortto.com Team' => 'help@ortto.com' }
  s.source           = { :git => 'https://github.com/autopilot3/ortto-push-ios-sdk.git', :tag => "v#{s.version}" }
  s.source_files     = 'Sources/PushMessagingFCM/**/*'
  s.swift_version    = '5.10'
  s.platform         = :ios
  s.ios.deployment_target = '13.0'
  s.static_framework = true
  s.documentation_url = 'https://help.ortto.com/developer/latest/developer-guide/push-sdks/'
  s.dependency "OrttoPushMessaging", "= #{s.version.to_s}"
  s.dependency 'FirebaseMessaging',   '~> 11.15.0'
  s.dependency 'FirebaseCore',        '~> 11.0'
  s.dependency 'FirebaseCoreInternal','~> 11.0'
  s.dependency 'FirebaseInstallations','~> 11.0'
end
