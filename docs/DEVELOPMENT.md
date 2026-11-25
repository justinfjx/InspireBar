# 开发 InspireBar

| 目录 | 职责 |
| --- | --- |
| `Sources/CodexBar` | InspireBar 的菜单栏、用量卡片、趋势和本地同步 |
| `Sources/CodexBar/Resources/InspireReader` | 使用 Inspire CLI 的 Python 环境读取项目、个人账单和实例 |
| `Sources/CodexBarCore` | Swift 快照模型和按周预测 |
| `Tests` | Swift 预测与数据解析测试、Python 存储测试 |

```sh
make test-fast FILTER=InspireQuotaTests
make test
./Scripts/install_lint_tools.sh
make check
./Scripts/package_app.sh release
```

`package_app.sh` 在仓库根目录生成独立、临时签名的 `InspireBar.app`。使用 `make start` 构建并重启此仓库的副本。原版 CodexBar 与此应用使用不同的 bundle identifier 和数据目录。

发布时运行 `./Scripts/package_dmg.sh`，在 `.build/dist` 生成同时包含 Apple 芯片和 Intel 架构的安装镜像。应用使用临时签名；分发前需要 Apple 公证时，应使用自己的 Developer ID 签名并公证。公开发行时从不含个人路径的干净检出目录构建。

验证新设置窗口时，可传入 `--show-settings`；使用 `--diagnose-menu-bar` 将菜单栏状态项的几何信息输出到标准输出。打包使用当前 SDK 的链接标记，保留 macOS 14 的运行下限。

用 `./Scripts/build_icon.sh` 从票券矢量源重新生成 `Icon.icns`。菜单栏图标随余额变化，由 `IconRenderer` 绘制。

需要用已授权的本机 Inspire 会话核对采集时，可使用隔离目录：

```sh
./InspireBar.app/Contents/MacOS/InspireBar --refresh-once --data-dir "$PWD/.build/inspire-qa"
```

需要迁移旧看板历史时，首次采集可传入 `--import-archive /absolute/path/to/archive.json`。采集器匹配成功登录的账号后才会采用旧档案，已有档案时继续使用本地数据。切换 CLI 的活动账号后，下一次同步会切到该账号的档案。

日账单以平台返回的数据为准。跨周期的余额实测样本保留于各账号档案；当前周期的曲线仅展示相应区间。刷新失败时保留最近成功数据及其时间，过期后暂停预测。测试使用合成数据，不需要平台账号。
