# FRP 网络工具套件

这是一个用于快速部署和管理 FRP（Fast Reverse Proxy）服务端和客户端的工具套件。该套件包含两个主要脚本：

1. `install_frps.sh` - FRP 服务端安装和管理脚本
2. `network-tool.sh` - FRP 客户端安装和管理脚本

## 功能特点

### 服务端 (install_frps.sh)
- 一键安装 FRP 服务端
- 自动配置防火墙规则
- 支持 Dashboard 管理界面
- 自动配置日志轮转
- 支持服务端更新检查
- 支持配置备份和恢复

### 客户端 (network-tool.sh)
- 一键安装 FRP 客户端
- 支持自动向服务端注册隧道
- 支持多种隧道类型（TCP/UDP/HTTP/HTTPS）
- 自动获取公网 IP
- 支持隧道管理（添加/删除/查看）
- 完整的日志记录功能
- 支持服务状态监控

## 系统要求

- Linux 操作系统（推荐 Ubuntu/Debian/CentOS）
- Bash 4.0 或更高版本
- 需要 root 权限运行
- 服务端需要公网 IP 或域名

## 安装说明

### 服务端安装

直接执行以下命令：

```bash
sudo bash -c "$(curl -fsSL https://raw.githubusercontent.com/yeyou612/frp_sh01/main/install_frps.sh)"
```

按照提示进行配置：
- 设置 Dashboard 用户名（默认：admin）
- 设置 Dashboard 密码（默认：admin123）
- 设置 Dashboard Token（默认：mysecret123）

### 客户端安装

直接执行以下命令：

```bash
sudo bash -c "$(curl -fsSL https://raw.githubusercontent.com/yeyou612/frp_sh01/main/network-tool.sh)"
```

按照提示进行配置：
- 输入服务端地址
- 输入认证 Token
- 配置需要的隧道

## 使用说明

### 服务端管理

运行 `./install_frps.sh` 后，可以通过菜单进行以下操作：
1. 安装/重新安装 FRP 服务端
2. 卸载 FRP 服务端
3. 查看当前配置
4. 检查更新
5. 退出

### 客户端管理

运行 `./network-tool.sh` 后，可以通过菜单进行以下操作：
1. 安装/重新配置网络监控工具
2. 卸载网络监控工具
3. 管理网络通道
4. 查看当前配置
5. 查看使用说明
6. 退出

## 端口说明

- 服务端默认端口：
  - 7000：FRP 服务端口
  - 7500：Dashboard 管理界面
  - 7501：API 接口
  - 10000-40000：隧道端口范围

## 安全说明

1. 首次安装后请立即修改默认密码和 Token
2. 建议使用强密码（包含大小写字母、数字和特殊字符）
3. 定期更新 FRP 版本以获取安全补丁
4. 建议配置防火墙，只开放必要的端口

## 常见问题

1. 如果安装失败，请检查：
   - 是否有 root 权限
   - 系统是否满足要求
   - 网络连接是否正常

2. 如果客户端连接失败，请检查：
   - 服务端地址是否正确
   - Token 是否匹配
   - 防火墙是否放行相应端口

## 日志位置

- 服务端日志：`/var/log/frp/frps.log`
- 客户端日志：`/usr/share/lib/.network-util/client.log`

## 许可证

MIT License

## 作者

[yeyou612]

## 更新日志

### v1.0.0 (2024-03-xx)
- 初始版本发布
- 支持基本的服务端和客户端功能
- 添加完整的隧道管理功能 
