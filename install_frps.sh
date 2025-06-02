#!/bin/bash
set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

FRP_VERSION=0.58.0
INSTALL_DIR=/usr/local/frp
LOG_DIR=/var/log/frp

check_installed() {
  if [[ -f "$INSTALL_DIR/frps" ]]; then
    return 0
  else
    return 1
  fi
}

# 检查密码强度
check_password_strength() {
  local password=$1
  if [[ ${#password} -lt 8 ]]; then
    echo -e "${RED}密码长度必须至少为8个字符${NC}"
    return 1
  fi
  if ! [[ $password =~ [A-Z] ]]; then
    echo -e "${RED}密码必须包含至少一个大写字母${NC}"
    return 1
  fi
  if ! [[ $password =~ [a-z] ]]; then
    echo -e "${RED}密码必须包含至少一个小写字母${NC}"
    return 1
  fi
  if ! [[ $password =~ [0-9] ]]; then
    echo -e "${RED}密码必须包含至少一个数字${NC}"
    return 1
  fi
  return 0
}

# 检查下载是否成功
check_download() {
  if [ ! -f "$1" ]; then
    echo -e "${RED}下载失败：$1${NC}"
    exit 1
  fi
}

# 检查文件完整性
check_file_integrity() {
  local file=$1
  if [ ! -s "$file" ]; then
    echo -e "${RED}文件为空或损坏：$file${NC}"
    exit 1
  fi
}

# 备份配置文件
backup_config() {
  if [ -f "$INSTALL_DIR/frps.ini" ]; then
    cp "$INSTALL_DIR/frps.ini" "$INSTALL_DIR/frps.ini.bak.$(date +%Y%m%d%H%M%S)"
  fi
}

show_menu() {
  echo "========================="
  echo " FRPS 一键管理脚本"
  echo "========================="
  echo "1. 安装 frps 服务端"
  echo "2. 卸载 frps 服务端"
  echo "3. 查看当前配置"
  echo "4. 检查更新"
  echo "5. 退出"
  echo "========================="
  read -p "请输入选项 [1-5]: " choice
  case "$choice" in
    1) install_frps ;;
    2) uninstall_frps ;;
    3) cat $INSTALL_DIR/frps.ini 2>/dev/null || echo "未找到配置文件。" ;;
    4) check_version ;;
    5) exit 0 ;;
    *) echo -e "${RED}❌ 无效选项${NC}" ;;
  esac
}

configure_firewall() {
  echo "📝 正在配置防火墙规则（开放 10000-40000）..."

  if command -v ufw &>/dev/null; then
    echo "🛡️ 使用 ufw 配置防火墙..."
    ufw allow 7000/tcp
    ufw allow 7500/tcp
    ufw allow 10000:40000/tcp comment 'FRP Ports'
    ufw reload || true
    ufw enable || true
  elif command -v iptables &>/dev/null; then
    echo "🛡️ 使用 iptables 配置防火墙..."
    iptables -A INPUT -p tcp --dport 10000:40000 -j ACCEPT

    # 保存规则
    if command -v iptables-save &>/dev/null; then
      if [ -d "/etc/iptables" ]; then
        iptables-save > /etc/iptables/rules.v4
      elif [ -d "/etc/sysconfig" ]; then
        iptables-save > /etc/sysconfig/iptables
      else
        echo "⚠️ 无法确定保存iptables规则的位置，请手动保存"
      fi
    fi
  else
    echo "⚠️ 未检测到防火墙工具（ufw 或 iptables），请手动开放端口范围 10000-40000"
  fi
}

install_frps() {
  if check_installed; then
    echo -e "${YELLOW}⚠️ 已检测到 frps 已安装在 $INSTALL_DIR${NC}"
    show_menu
    return
  fi

  while true; do
    read -p "请输入 Dashboard 用户名（默认 admin）: " DASH_USER
    DASH_USER=${DASH_USER:-admin}
    if [[ ${#DASH_USER} -lt 3 ]]; then
      echo -e "${RED}用户名长度必须至少为3个字符${NC}"
      continue
    fi
    break
  done

  while true; do
    read -s -p "请输入 Dashboard 密码（默认 admin123）: " DASH_PWD
    echo
    DASH_PWD=${DASH_PWD:-admin123}
    if ! check_password_strength "$DASH_PWD"; then
      continue
    fi
    break
  done

  while true; do
    read -s -p "请输入 Dashboard Token（默认 mysecret123）: " DASH_TOKEN
    echo
    DASH_TOKEN=${DASH_TOKEN:-mysecret123}
    if ! check_password_strength "$DASH_TOKEN"; then
      continue
    fi
    break
  done

  mkdir -p $INSTALL_DIR
  mkdir -p $LOG_DIR
  cd /tmp
  
  echo -e "${GREEN}正在下载 FRP v${FRP_VERSION}...${NC}"
  wget -q --show-progress https://github.com/fatedier/frp/releases/download/v${FRP_VERSION}/frp_${FRP_VERSION}_linux_amd64.tar.gz
  check_download "frp_${FRP_VERSION}_linux_amd64.tar.gz"
  
  echo -e "${GREEN}正在解压...${NC}"
  tar -zxf frp_${FRP_VERSION}_linux_amd64.tar.gz
  check_file_integrity "frp_${FRP_VERSION}_linux_amd64/frps"
  
  if pgrep -x "frps" > /dev/null; then
    echo -e "${YELLOW}⚠️ 检测到 frps 正在运行，尝试停止...${NC}"
    systemctl stop frps || true
    sleep 2
    while fuser "$INSTALL_DIR/frps" 2>/dev/null | grep -q .; do
      echo -e "${YELLOW}⏳ 等待 frps 文件释放中...${NC}"
      sleep 1
    done
  fi
  
  backup_config
  
  cp frp_${FRP_VERSION}_linux_amd64/frps $INSTALL_DIR/frps.new
  mv -f $INSTALL_DIR/frps.new $INSTALL_DIR/frps
  chmod 755 $INSTALL_DIR/frps
  chown root:root $INSTALL_DIR/frps
  
  cat > $INSTALL_DIR/frps.ini <<EOF
[common]
bind_port = 7000
dashboard_port = 7500
dashboard_user = ${DASH_USER}
dashboard_pwd = ${DASH_PWD}
dashboard_token = ${DASH_TOKEN}
log_level = info
log_file = ${LOG_DIR}/frps.log
log_max_days = 7
authentication_method = token
token = ${DASH_TOKEN}
allow_ports = 10000-40000
max_pool_count = 100
EOF

  # 配置日志轮转
  cat > /etc/logrotate.d/frp <<EOF
${LOG_DIR}/frps.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    create 644 root root
}
EOF

  cat > /etc/systemd/system/frps.service <<EOF
[Unit]
Description=FRP Server Service
After=network.target

[Service]
Type=simple
ExecStart=${INSTALL_DIR}/frps -c ${INSTALL_DIR}/frps.ini
Restart=on-failure
RestartSec=5s
LimitNOFILE=1048576
MemoryLimit=512M

[Install]
WantedBy=multi-user.target
EOF

  systemctl daemon-reexec
  systemctl daemon-reload
  systemctl enable frps
  systemctl restart frps
  
  # 配置防火墙
  configure_firewall
  
  echo -e "${GREEN}✅ frps 已安装成功，当前配置如下：${NC}"
  cat $INSTALL_DIR/frps.ini
  systemctl status frps --no-pager
}

uninstall_frps() {
  if systemctl is-active --quiet frps; then
    echo "🔍 检测到 frps 正在运行，正在停止服务..."
    systemctl stop frps
  fi
  
  if systemctl is-enabled --quiet frps; then
    echo "🔧 正在移除开机启动配置..."
    systemctl disable frps
  fi
  
  echo "🗑️ 正在清理配置与文件..."
  rm -f /etc/systemd/system/frps.service
  rm -rf /usr/local/frp
  systemctl daemon-reload
  
  echo "✅ frps 已完全卸载。"
}

# 添加版本检查功能
check_version() {
  local latest_version=$(curl -s https://api.github.com/repos/fatedier/frp/releases/latest | grep -oP '"tag_name": "\K(.*)(?=")')
  if [ "$latest_version" != "v${FRP_VERSION}" ]; then
    echo -e "${YELLOW}⚠️ 发现新版本: ${latest_version}，当前版本: v${FRP_VERSION}${NC}"
    read -p "是否更新到最新版本？[y/N] " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
      FRP_VERSION=${latest_version#v}
      install_frps
    fi
  fi
}

# 启动脚本前判断安装状态
if check_installed; then
  echo "✅ 已检测到 frps 安装，进入菜单模式管理："
else
  echo "🆕 未检测到 frps，可进行安装："
fi

show_menu