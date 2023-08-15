# FPSIndicator

real-time fps indicator for ios games


# 编译指南

1. 缺少Private Frameworks
```shell
ld: framework not found Preferences
clang: error: linker command failed with exit code 1 (use -v to see invocation)
```
新版的iPhoneOS SDK中，Preferences.framework已经被移除，需要从旧版的SDK中拷贝出来，放到`/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS.sdk/System/Library/PrivateFrameworks/`目录下。
- Preferences.framework [下载地址](https://github.com/theos/sdks)
- [参考](https://github.com/theos/theos/issues/285)

2. 缺少Alist
- [AltList](https://github.com/opa334/AltList)


## Special thanks
- [masagrator/NX-FPS](https://github.com/masagrator/NX-FPS)
- [JoeyDeVries/LearnOpenGL](https://github.com/JoeyDeVries/LearnOpenGL)
- [loyinglin/LearnMetal](https://github.com/loyinglin/LearnMetal)
