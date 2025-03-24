# Uncomment the next line to define a global platform for your project
 platform :ios, '13.0'

source 'https://github.com/Garenge/pengpengSpecs.git'
source 'https://github.com/CocoaPods/Specs.git'

target 'GCDSocketDemo' do
  # Comment the next line if you don't want to use dynamic frameworks
  use_frameworks!

  # Pods for GCDSocketDemo
  pod 'SnapKit'
  pod 'PPCatalystTool'
  pod 'PPToolKit' #, :git => 'https://github.com/Garenge/PPToolKit.git'
  # pod 'PPSocket'
  pod 'PPSocket', :path => '../../SDK/PPSocket'
  pod 'PPCustomAsyncOperation', :path => '../../SDK/PPCustomAsyncOperation'

  post_install do |installer|
    installer.pods_project.targets.each do |target|
      target.build_configurations.each do |config|
        config.build_settings["EXCLUDED_ARCHS[sdk=iphonesimulator*]"] = "arm64"
      end
    end
  end
end


