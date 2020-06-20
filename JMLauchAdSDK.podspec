
Pod::Spec.new do |spec|

  spec.name         = "JMLauchAdSDK"
  spec.version      = "0.0.2"
  spec.summary      = "A short description of JMLauchAdSDK"
  spec.description  = "A short description of JMLauchAdSDK use app to launched"

  spec.homepage     = "https://github.com/lishuhui038/JMLauchAdSDK"

  spec.license      = "MIT"

  spec.author             = { "2973452128@qq.com" => "2973452128@qq.com" }
 

  spec.platform     = :ios, "10.0"


  spec.source       = { :git => "https://github.com/lishuhui038/JMLauchAdSDK.git", :tag => "0.0.2" }

  spec.source_files = "JMLauchAdSDK/*"
  spec.requires_arc = true


end
