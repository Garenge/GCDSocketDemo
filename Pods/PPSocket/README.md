# PPSocket

[![CI Status](https://img.shields.io/travis/Garenge/PPSocket.svg?style=flat)](https://travis-ci.org/Garenge/PPSocket)
[![Version](https://img.shields.io/cocoapods/v/PPSocket.svg?style=flat)](https://cocoapods.org/pods/PPSocket)
[![License](https://img.shields.io/cocoapods/l/PPSocket.svg?style=flat)](https://cocoapods.org/pods/PPSocket)
[![Platform](https://img.shields.io/cocoapods/p/PPSocket.svg?style=flat)](https://cocoapods.org/pods/PPSocket)

## Example

To run the example project, clone the repo, and run `pod install` from the Example directory first.

## Requirements

## Installation

PPSocket is available through [CocoaPods](https://cocoapods.org). To install
it, simply add the following line to your Podfile:

*add source*

```
source 'https://github.com/Garenge/pengpengSpecs.git'
source 'https://github.com/CocoaPods/Specs.git'
```

```ruby
pod 'PPSocket'
```
```
# 可能需要加
post_install do |installer|
	installer.pods_project.targets.each do |target|
	  target.build_configurations.each do |config|
	    config.build_settings["EXCLUDED_ARCHS[sdk=iphonesimulator*]"] = "arm64"
	  end
	end
end
```
## Author

Garenge, garenge@outlook.com

## License

PPSocket is available under the MIT license. See the LICENSE file for more info.
