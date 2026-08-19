require "json"

package = JSON.parse(File.read(File.join(__dir__, "..", "package.json")))

Pod::Spec.new do |s|
  s.name         = "SkiaGlassSurface"
  s.version      = package["version"]
  s.summary      = "Skia glass surface Fabric component (background capture + onSnapshot)"
  s.homepage     = "https://example.com"
  s.license      = { :type => "MIT" }
  s.authors      = { "DietClient" => "dev@example.com" }
  s.platforms    = { :ios => min_ios_version_supported }
  s.source       = { :path => "." }

  s.source_files = "SkiaGlassSurface/**/*.{h,m,mm}"

  install_modules_dependencies(s)

  s.pod_target_xcconfig = {
    "CLANG_CXX_LANGUAGE_STANDARD" => "c++20",
    "HEADER_SEARCH_PATHS" => "$(inherited)",
  }
end
