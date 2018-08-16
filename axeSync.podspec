#
# Run the following command to validate the podspec
# pod lib lint AxeSync.podspec --no-clean --verbose --allow-warnings
#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'AxeSync'
  s.version          = '0.1.0'
  s.summary          = 'Axe Sync is a light and configurable blockchain client that you can embed into your iOS Application.'
  s.description      = 'Axe Sync is a light blockchain client that you can embed into your iOS Application.  It is fully customizable to make the type of node you are interested in.'

  s.homepage         = 'https://github.com/axerunners/axesync-ios.git'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'quantumexplorer' => 'quantum@axe.org' }
  s.source           = { :git => 'https://github.com/axerunners/axesync-iOS.git', :tag => s.version.to_s }

  s.platform = :ios
  s.ios.deployment_target = '10.0'

  s.source_files = "AxeSync/**/*.{h,m}"
  s.public_header_files = 'AxeSync/**/*.h'
  s.libraries = 'bz2', 'sqlite3'
  s.requires_arc = true

  s.resource_bundles = {'AxeSync' => ['AxeSync/*.xcdatamodeld', 'AxeSync/*.plist', 'AxeSync/*.lproj/*.plist']}
  
  s.framework = 'Foundation', 'UIKit', 'SystemConfiguration', 'CoreData'
  s.compiler_flags = '-Wno-comma'
  s.dependency 'secp256k1_axe', '0.1.0'
  
end

