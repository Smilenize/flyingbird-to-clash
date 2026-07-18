# 通过 WebDAV 在多设备间使用

`flyingbird-current.yaml` 可以放在私人 WebDAV 中，供其他电脑或手机下载后导入 Clash / mihomo 客户端。

## 推荐方式

```text
电脑 A 导出 YAML
        ↓
WebDAV 客户端同步到私人目录
        ↓
电脑 B 或手机下载到本地
        ↓
Clash / FlClash 从本地文件导入
```

建议由 WebDAV 客户端负责认证和同步，代理客户端只读取本地文件。私人 WebDAV 通常需要用户名、密码或特殊认证，直接把 WebDAV 地址当作远程订阅并不一定兼容。

## 自动复制到同步目录

如果 WebDAV 已挂载或同步到本地目录，可以运行：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass `
  -File ".\Export-FlyingBirdProfile.ps1" `
  -SyncDirectory "D:\WebDAV\FlyingBird"
```

脚本会复制：

```text
D:\WebDAV\FlyingBird\flyingbird-current.yaml
```

## 更新限制

导出的文件是静态快照：

- 云端文件更新后，其他设备可能需要重新同步并重新导入
- 不会自动获得机场后续新增或删除的节点
- 不包含订阅 HTTP 响应头，因此客户端通常不显示套餐剩余流量和到期时间
- 节点是否可继续使用取决于服务端账号、凭证、设备数和并发限制

## 安全建议

- WebDAV 必须使用 HTTPS
- 不要创建公开分享链接
- 使用强密码，并在可用时启用多因素认证
- 确保每台设备保留本地副本，以免 WebDAV 临时不可用
- 不要把同步目录加入公开 Git 仓库
