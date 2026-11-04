# Android 安装约定

用户要求后续每次更新同时安装到 `android-devices.json` 中的两台设备，使用同一份 APK，覆盖安装并保留数据。仅安装，不启动应用或操作设备验证交互。

使用 `D:/Program Files/flutter` 构建。构建及 APK 校验完成后运行：

```powershell
./tool/install_android_devices.ps1
```

无线调试端口会变化。如果离线，询问当前调试地址后传入 `-Device1Address` / `-Device2Address`。配对状态通常保留，不保存配对码。脚本核对序列号，逐台安装，最后汇总失败；两台都成功才保存新的地址。

用户临时要求跳过第二台时使用 `-SkipDevice2`，仅本次安装第一台并保存其新地址，不删除第二台的配置。默认仍安装两台。
