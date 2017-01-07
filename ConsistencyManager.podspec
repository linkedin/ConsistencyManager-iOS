Pod::Spec.new do |spec|
  spec.name             = 'ConsistencyManager'
  spec.version          = '5.1.0'
  spec.license          = { :type => 'Apache License, Version 2.0' }
  spec.homepage         = 'https://linkedin.github.io/ConsistencyManager-iOS'
  spec.authors          = 'LinkedIn'
  spec.summary          = 'Manages the consistency of immutable models.' 
  spec.source           = { :git => 'https://github.com/linkedin/ConsistencyManager-iOS.git', :tag => spec.version }
  spec.source_files     = 'ConsistencyManager/**/*.swift'
  
  spec.ios.deployment_target  = '8.0'
  spec.ios.frameworks         = 'Foundation', 'UIKit'

  spec.tvos.deployment_target = '9.0'
  spec.tvos.frameworks        = 'Foundation', 'UIKit'

  spec.osx.deployment_target  = '10.11'
  spec.osx.frameworks         = 'Foundation'
end

