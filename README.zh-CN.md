# GlassTether

**让 iPhone 就在鼠标触手可及之处。**

原生 Mac 应用：通过 USB 显示 iPhone 画面，通过蓝牙绝对鼠标控制手机。鼠标移入真实画面后操作手机，移出后回到 Mac。

这是本地 alpha 审阅版，名称暂定，尚未公开发布或授予开源许可证。不能承诺所有 iPhone / iOS 组合兼容。

[English](README.md) · [中文连接指南](docs/SETUP.zh-CN.md) · [兼容性与验收](docs/COMPATIBILITY.md)

## 首次使用

1. 在其他应用断开手机预览，只用 USB 接入一台 iPhone，解锁并信任 Mac。点击 **Connect USB video**，允许相机权限。
2. 点击 **Pair Bluetooth mouse**。在 iPhone「设置 → 辅助功能 → 触控 → 辅助触控 → 设备 → 蓝牙设备」配对 **GT Mouse**；也可能显示 Mac 名称。
3. 开启辅助触控、关闭停留控制与拖移锁定，确认配对的就是预览中的手机，然后开启 **Control iPhone**。
4. 移入画面操作，黑边不转发。移出恢复 Mac 光标，按 **Esc** 停用控制。失焦、画面过期、断线后需重新手动开启。

USB 与蓝牙身份不能直接对应，请自行核对手机。应用只显示视频，不采集音频，不录屏、截图、OCR，不转发键盘或多点触控，不提供云端或远程网络控制。

## 构建

需要 Xcode、Swift 6；最低构建目标 macOS 14，运行兼容范围仍待逐机验证。

```sh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
swift test
./script/build.sh
```

在 Finder 打开脚本输出的 `dist/GlassTether-NNN.app`。脚本只构建和临时签名，不会安装、启动或连接手机。目前没有经过公证的公开安装包。

源 demo 在一个设备组合上获得用户确认：约 25%/25% 位置符合预期，鼠标可跟随。本新版本、全部区域误差、点击拖动、退出释放、旋转和重连仍需真机验收；手机型号与 iOS 版本尚未记录。

开发结构、英文贡献指南、问题模板和发布材料都已放入仓库。开源前还需确认名称、许可证、代码再分发权利、正式蓝牙身份及 GitHub 目的地，详见 [发布审阅材料](docs/RELEASE_REVIEW.md)。
