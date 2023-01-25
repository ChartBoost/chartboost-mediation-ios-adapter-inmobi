Pod::Spec.new do |spec|
  spec.name        = 'ChartboostMediationAdapterInMobi'
  spec.version     = '4.10.1.2.0'
  spec.license     = { :type => 'MIT', :file => 'LICENSE.md' }
  spec.homepage    = 'https://github.com/ChartBoost/chartboost-mediation-ios-adapter-inmobi'
  spec.authors     = { 'Chartboost' => 'https://www.chartboost.com/' }
  spec.summary     = 'Chartboost Mediation iOS SDK InMobi adapter.'
  spec.description = 'InMobi Adapters for mediating through Chartboost Mediation. Supported ad formats: Banner, Interstitial, and Rewarded.'

  # Source
  spec.module_name  = 'ChartboostMediationAdapterInMobi'
  spec.source       = { :git => 'https://github.com/ChartBoost/chartboost-mediation-ios-adapter-inmobi.git', :tag => spec.version }
  spec.source_files = 'Source/**/*.{swift}'

  # Minimum supported versions
  spec.swift_version         = '5.0'
  spec.ios.deployment_target = '10.0'

  # System frameworks used
  spec.ios.frameworks = ['Foundation', 'UIKit']
  
  # This adapter is compatible with all Chartboost Mediation 4.X versions of the SDK.
  spec.dependency 'ChartboostMediationSDK', '~> 4.0'

  # Partner network SDK and version that this adapter is certified to work with.
  spec.dependency 'InMobiSDK', '10.1.2'
  
  # The partner network SDK is a static framework which requires the static_framework option.
  spec.static_framework = true
end