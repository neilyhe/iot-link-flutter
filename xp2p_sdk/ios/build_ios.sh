#!/bin/bash

# flutter 构建脚本

set -e

#### 2. 清理 Flutter 构建缓存
rm -rf ios/Pods ios/Podfile.lock ios/.symlinks

# 2. 清理 Flutter 构建缓存
#cd ..
/Users/eaglechan/Desktop/tencent/flutter_project/SDK/flutter/bin/flutter clean

# 3. 重新获取依赖
/Users/eaglechan/Desktop/tencent/flutter_project/SDK/flutter/bin/flutter pub get

# 4. 重新安装 Pods
cd ios && pod install && cd ..

# 5. 返回项目根目录并运行

/Users/eaglechan/Desktop/tencent/flutter_project/SDK/flutter/bin/flutter run
/Users/eaglechan/Desktop/tencent/flutter_project/SDK/flutter/bin/flutter build ios --debug

nm build/ios/Debug-iphoneos/xp2p_sdk/xp2p_sdk.framework/xp2p_sdk | grep -E "(setLogEnable|xp2p_force_link)"
nm build/ios/Debug-iphoneos/xp2p_sdk/xp2p_sdk.framework/xp2p_sdk | grep -E "(setLogEnable|xp2p_force_link)" | head -5


rm -rf ios/Pods ios/Podfile.lock ios/.symlinks && /Users/eaglechan/Desktop/tencent/flutter_project/SDK/flutter/bin/flutter clean && /Users/eaglechan/Desktop/tencent/flutter_project/SDK/flutter/bin/flutter pub get && cd ios && pod install && cd .. && /Users/eaglechan/Desktop/tencent/flutter_project/SDK/flutter/bin/flutter build ios --debug