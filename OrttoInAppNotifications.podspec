Pod::Spec.new do |s|
  s.name             = 'OrttoInAppNotifications'
  s.version          = '1.7.0'
  s.summary          = 'OrttoSDK In-App Notifications Module'
  s.homepage         = 'https://github.com/autopilot3/ortto-push-ios-sdk'
  s.license          = { :type => 'MIT', :file => 'LICENSE.md' }
  s.author           = { 'Ortto.com Team' => 'help@ortto.com' }
  s.source           = { :git => 'https://github.com/autopilot3/ortto-push-ios-sdk.git', :tag => "v#{s.version}" }
  s.source_files     = 'Sources/InAppNotifications/**/*'
  s.swift_version    = '5.0'
  s.platform         = :ios
  s.ios.deployment_target = '13.0'
  s.documentation_url = 'https://help.ortto.com/developer/latest/developer-guide/push-sdks/'
  s.dependency "OrttoSDKCore", "= #{s.version.to_s}"
  s.dependency "SwiftSoup", '2.6.0'
  s.resource_bundles = {
    'WebView' => [
      'Sources/InAppNotifications/Resources/WebView.bundle/**/*.{html,js,css}'
    ]
  }
end
