Pod::Spec.new do |s|
  s.name             = 'xp2p_sdk'
  s.version          = '2.4.50'
  s.summary          = 'Flutter SDK for Tencent IoT XP2P video streaming'
  s.description      = <<-DESC
Flutter SDK for Tencent IoT XP2P video streaming. This SDK provides P2P connectivity for video devices using Dart FFI.
                       DESC
  s.homepage         = 'https://github.com/tencentyun/iot-link-ios'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Tencent' => 'your-email@example.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.dependency 'Flutter'
#   s.dependency 'TIoTLinkKit_XP2P'
  s.platform = :ios, '13.0'

#   s.vendored_libraries = 'Libraries/*.a'
  s.vendored_frameworks = 'Libraries/TencentENET.framework'
  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 
    'DEFINES_MODULE' => 'YES', 
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386',
    'OTHER_LDFLAGS' => '-Wl,-undefined,dynamic_lookup',
    'CLANG_CXX_LANGUAGE_STANDARD' => 'c++14',
    'CLANG_CXX_LIBRARY' => 'libc++',
    # 以下配置确保在 Release 构建中符号不被剥离
    'STRIP_STYLE' => 'debugging', # 或者 'non-global'，但注意这可能不会完全保留所有符号
    'STRIP_INSTALLED_PRODUCT' => 'NO', # 防止剥离
    'DEPLOYMENT_POSTPROCESSING' => 'NO' # 关闭部署后处理，防止符号被剥离
  }
  
  # 使用静态框架确保符号在主进程中可见
#   s.static_framework = true
  s.frameworks = "NetworkExtension", "CoreGraphics", "SystemConfiguration", "Foundation", "UIKit"
  s.libraries = 'c++', 'sqlite3', 'z'

  # 强制加载所有符号到主应用，供 DynamicLibrary.process() 使用
  s.user_target_xcconfig = {
    'OTHER_LDFLAGS' => '$(inherited) -all_load'
  }
  
  # 确保C++文件被正确编译
  s.preserve_paths = 'Classes/**/*.{h,cpp,c}'
  s.xcconfig = {
    'HEADER_SEARCH_PATHS' => "${PODS_ROOT}/../Classes/include",
    'OTHER_LDFLAGS' => '-ObjC' # 有时需要这个标志来确保所有符号被链接
  }
  s.swift_version = '5.0'
end
