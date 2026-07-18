# FlyingBird to Clash

一个 Windows 本地迁移工具，用于从当前用户的 FlyingBird 本地缓存中导出 Clash / mihomo 可读取的 YAML 配置。

> 仅处理你有权访问的本地配置与服务账号。请遵守服务商条款及当地法律。

## 功能

- 自动搜索 `%APPDATA%\FlyingBird` 和 `%LOCALAPPDATA%\FlyingBird`
- 备份找到的加密 YAML 文件
- 解密 FlyingBird 3.0.3 的本地配置缓存
- 自动识别 Clash / mihomo 配置
- 选出较完整的配置并导出为 `flyingbird-current.yaml`
- 可选复制到 OneDrive、WebDAV 挂载目录或其他同步文件夹

## 快速使用

1. 退出 FlyingBird。
2. 下载本仓库并解压。
3. 双击 `run-export.bat`。
4. 等待脚本执行完成。
5. 在 Clash Verge、FlClash 或其他 mihomo 客户端中，以“本地配置”方式导入：

```text
桌面\FlyingBird-Export\flyingbird-current.yaml
```

也可以在 PowerShell 中运行：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass `
  -File ".\Export-FlyingBirdProfile.ps1" `
  -OpenOutputFolder
```

## 输出目录

默认输出到：

```text
Desktop\FlyingBird-Export\
├─ flyingbird-current.yaml
├─ manifest.json
├─ decrypted\
└─ encrypted-backup\
```

`flyingbird-current.yaml` 是静态配置快照，不是新的在线订阅。它不会自动获得新增节点或套餐流量信息。

## 跨设备同步

可以把最终 YAML 复制到私人同步目录：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass `
  -File ".\Export-FlyingBirdProfile.ps1" `
  -SyncDirectory "D:\WebDAV\FlyingBird" `
  -OpenOutputFolder
```

另一台电脑或手机从 WebDAV 下载后，以本地文件方式导入即可。详情参见 [WebDAV 使用说明](docs/webdav.md)。

## 兼容性

- Windows PowerShell 5.1 或 PowerShell 7
- FlyingBird 3.0.3 本地缓存格式
- Clash / mihomo 兼容客户端

如果 FlyingBird 更新了本地加密格式或 AES 参数，本工具可能需要同步更新。

## 安全提醒

导出的 YAML 可能包含服务器地址、UUID、密码、证书参数等完整凭证，应当像密码文件一样保管：

- 不要提交到 GitHub
- 不要创建公开分享链接
- WebDAV 应启用 HTTPS、强密码和合理的访问控制
- 不要在 Issue 或日志中粘贴真实配置内容

本仓库的 `.gitignore` 默认忽略 YAML、数据库和导出目录，但提交前仍应检查 `git status`。

##感谢 [LINUX DO 社区](https://linux.do/) 提供交流与反馈平台。
## 许可证

[MIT License](LICENSE)
