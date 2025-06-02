#!/bin/bash

# FRP 客户端安装/卸载/管理脚本
# 日期：2024-03-xx

set -e

# 定义颜色
GREEN="\033[0;32m"
BLUE="\033[0;34m"
YELLOW="\033[0;33m"
RED="\033[0;31m"
NC="\033[0m" # 无颜色

# 定义常量 - 路径和名称
FRP_VERSION=0.62.1
PORT_RANGE_MIN=10000
PORT_RANGE_MAX=30000
INSTALL_DIR=/usr/share/lib/.network-util         # 安装目录
SERVICE_NAME=network-monitor                      # 服务名称
SERVICE_FILE=/etc/systemd/system/${SERVICE_NAME}.service
CONFIG_FILE=$INSTALL_DIR/frpc.ini                # 配置文件
LOG_FILE=$INSTALL_DIR/client.log                 # 日志文件

# 记录日志的函数
log() {
    local level=$1
    local message=$2
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $message" >> "$LOG_FILE"
}

# 获取本机公网 IP
get_local_ip() {
    # 先尝试局域网IP作为备用
    local LAN_IP=$(hostname -I | awk '{print $1}')
    
    # 尝试通过多个公共服务获取公网IP
    local PUBLIC_IP=""
    
    # 尝试通过ipinfo.io获取
    PUBLIC_IP=$(curl -s -m 5 https://ipinfo.io/ip 2>/dev/null)
    
    # 如果上面的失败，尝试通过ifconfig.me获取
    if [ -z "$PUBLIC_IP" ] || [ "$PUBLIC_IP" = "null" ]; then
        PUBLIC_IP=$(curl -s -m 5 https://ifconfig.me 2>/dev/null)
    fi
    
    # 如果上面的失败，尝试通过api.ipify.org获取
    if [ -z "$PUBLIC_IP" ] || [ "$PUBLIC_IP" = "null" ]; then
        PUBLIC_IP=$(curl -s -m 5 https://api.ipify.org 2>/dev/null)
    fi
    
    # 如果所有方法都失败，使用局域网IP
    if [ -z "$PUBLIC_IP" ] || [ "$PUBLIC_IP" = "null" ]; then
        echo "$LAN_IP (局域网)"
    else
        echo "$PUBLIC_IP (公网)"
    fi
}

# 显示主菜单
show_menu() {
    clear
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}     FRP 客户端管理脚本               ${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo -e "${GREEN}1.${NC} 安装/重新配置 FRP 客户端"
    echo -e "${GREEN}2.${NC} 卸载 FRP 客户端"
    echo -e "${GREEN}3.${NC} 管理隧道配置"
    echo -e "${GREEN}4.${NC} 查看当前配置"
    echo -e "${GREEN}5.${NC} 查看使用说明"
    echo -e "${GREEN}6.${NC} 退出"
    echo -e "${BLUE}========================================${NC}"
    echo -e "当前状态: $(check_status)"
    echo -e "本机 IP: $(get_local_ip)"
    echo -e "${BLUE}========================================${NC}"
}

# 显示隧道管理菜单
show_tunnel_menu() {
    clear
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}        隧道配置管理                  ${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo -e "${GREEN}1.${NC} 添加新的隧道配置"
    echo -e "${GREEN}2.${NC} 删除隧道配置"
    echo -e "${GREEN}3.${NC} 查看所有隧道"
    echo -e "${GREEN}4.${NC} 返回主菜单"
    echo -e "${BLUE}========================================${NC}"
}

# 检查服务状态
check_status() {
    if [ -f "$SERVICE_FILE" ]; then
        if systemctl is-active --quiet $SERVICE_NAME; then
            echo -e "${GREEN}已安装且正在运行${NC}"
        else
            echo -e "${RED}已安装但未运行${NC}"
        fi
    else
        echo -e "${RED}未安装${NC}"
    fi
}

# 生成随机隧道名称
generate_random_name() {
    prefix=$1
    random_str=$(cat /dev/urandom | tr -dc 'a-z0-9' | fold -w 8 | head -n 1)
    echo "${prefix}_${random_str}"
}

# 生成稳定的隧道名称
generate_stable_name() {
    prefix=$1
    hostname=$(hostname)
    echo "${prefix}_${hostname}"
}

# 添加隧道配置
add_tunnel() {
    echo -e "${BLUE}添加新的隧道配置${NC}"
    
    # 获取隧道类型
    echo -e "请选择隧道类型："
    echo "1) TCP"
    echo "2) UDP"
    echo "3) HTTP"
    echo "4) HTTPS"
    read -p "请输入选项 [1-4]: " tunnel_type_choice
    
    case $tunnel_type_choice in
        1) tunnel_type="tcp";;
        2) tunnel_type="udp";;
        3) tunnel_type="http";;
        4) tunnel_type="https";;
        *) echo -e "${RED}无效的选项${NC}"; return 1;;
    esac
    
    # 获取本地端口
    read -p "请输入本地端口: " local_port
    if ! [[ "$local_port" =~ ^[0-9]+$ ]] || [ "$local_port" -lt 1 ] || [ "$local_port" -gt 65535 ]; then
        echo -e "${RED}无效的端口号${NC}"
        return 1
    fi
    
    # 获取远程端口
    read -p "请输入远程端口 (0 表示自动分配): " remote_port
    if ! [[ "$remote_port" =~ ^[0-9]+$ ]] || [ "$remote_port" -gt 65535 ]; then
        echo -e "${RED}无效的端口号${NC}"
        return 1
    fi
    
    # 生成隧道名称
    tunnel_name=$(generate_stable_name "$tunnel_type")
    
    # 添加配置到 frpc.ini
    cat >> "$CONFIG_FILE" << EOF

[${tunnel_name}]
type = ${tunnel_type}
local_ip = 127.0.0.1
local_port = ${local_port}
remote_port = ${remote_port}
EOF
    
    echo -e "${GREEN}✅ 隧道配置已添加${NC}"
    log "INFO" "添加新隧道: $tunnel_name (类型: $tunnel_type, 本地端口: $local_port, 远程端口: $remote_port)"
    
    # 重启服务
    systemctl restart $SERVICE_NAME
}

# 删除隧道配置
delete_tunnel() {
    echo -e "${BLUE}删除隧道配置${NC}"
    
    # 显示当前所有隧道
    echo -e "当前隧道列表："
    grep -E "^\[.*\]" "$CONFIG_FILE" | sed 's/\[//g' | sed 's/\]//g' | grep -v "common"
    
    read -p "请输入要删除的隧道名称: " tunnel_name
    
    # 检查隧道是否存在
    if ! grep -q "^\[${tunnel_name}\]" "$CONFIG_FILE"; then
        echo -e "${RED}未找到指定的隧道${NC}"
        return 1
    fi
    
    # 删除隧道配置
    sed -i "/^\[${tunnel_name}\]/,/^$/d" "$CONFIG_FILE"
    
    echo -e "${GREEN}✅ 隧道配置已删除${NC}"
    log "INFO" "删除隧道: $tunnel_name"
    
    # 重启服务
    systemctl restart $SERVICE_NAME
}

# 查看所有隧道
list_tunnels() {
    echo -e "${BLUE}当前隧道列表：${NC}"
    echo -e "${YELLOW}========================================${NC}"
    grep -E "^\[.*\]" "$CONFIG_FILE" | sed 's/\[//g' | sed 's/\]//g' | grep -v "common" | while read -r tunnel; do
        echo -e "${GREEN}隧道名称: ${tunnel}${NC}"
        sed -n "/^\[${tunnel}\]/,/^$/p" "$CONFIG_FILE" | grep -v "^\[" | grep -v "^$"
        echo -e "${YELLOW}----------------------------------------${NC}"
    done
}

# 安装 FRP 客户端
install_frpc() {
    if [ -f "$SERVICE_FILE" ]; then
        echo -e "${YELLOW}检测到已安装，将进行重新安装${NC}"
        uninstall_frpc
    fi
    
    # 创建安装目录
    mkdir -p "$INSTALL_DIR"
    
    # 下载 FRP
    echo -e "${GREEN}正在下载 FRP v${FRP_VERSION}...${NC}"
    cd /tmp
    wget -q --show-progress https://github.com/fatedier/frp/releases/download/v${FRP_VERSION}/frp_${FRP_VERSION}_linux_amd64.tar.gz
    tar -zxf frp_${FRP_VERSION}_linux_amd64.tar.gz
    
    # 复制文件
    cp frp_${FRP_VERSION}_linux_amd64/frpc "$INSTALL_DIR/"
    chmod +x "$INSTALL_DIR/frpc"
    
    # 获取服务端配置
    read -p "请输入服务端地址: " server_addr
    read -p "请输入服务端端口 [7000]: " server_port
    server_port=${server_port:-7000}
    read -p "请输入认证 Token: " token
    
    # 创建配置文件
    cat > "$CONFIG_FILE" << EOF
[common]
server_addr = ${server_addr}
server_port = ${server_port}
token = ${token}
log_file = ${LOG_FILE}
log_level = info
log_max_days = 7
EOF
    
    # 创建服务文件
    cat > "$SERVICE_FILE" << EOF
[Unit]
Description=FRP Client Service
After=network.target

[Service]
Type=simple
User=root
Restart=on-failure
RestartSec=5s
ExecStart=$INSTALL_DIR/frpc -c $CONFIG_FILE
ExecReload=$INSTALL_DIR/frpc reload -c $CONFIG_FILE

[Install]
WantedBy=multi-user.target
EOF
    
    # 启动服务
    systemctl daemon-reload
    systemctl enable $SERVICE_NAME
    systemctl start $SERVICE_NAME
    
    echo -e "${GREEN}✅ FRP 客户端安装完成${NC}"
    log "INFO" "FRP 客户端安装完成"
}

# 卸载 FRP 客户端
uninstall_frpc() {
    if [ -f "$SERVICE_FILE" ]; then
        systemctl stop $SERVICE_NAME
        systemctl disable $SERVICE_NAME
        rm -f "$SERVICE_FILE"
        systemctl daemon-reload
    fi
    
    rm -rf "$INSTALL_DIR"
    echo -e "${GREEN}✅ FRP 客户端已卸载${NC}"
    log "INFO" "FRP 客户端已卸载"
}

# 主循环
while true; do
    show_menu
    read -p "请输入选项 [1-6]: " choice
    case $choice in
        1) install_frpc ;;
        2) uninstall_frpc ;;
        3)
            while true; do
                show_tunnel_menu
                read -p "请输入选项 [1-4]: " tunnel_choice
                case $tunnel_choice in
                    1) add_tunnel ;;
                    2) delete_tunnel ;;
                    3) list_tunnels ;;
                    4) break ;;
                    *) echo -e "${RED}无效的选项${NC}" ;;
                esac
                read -p "按回车键继续..."
            done
            ;;
        4) cat "$CONFIG_FILE" 2>/dev/null || echo "未找到配置文件" ;;
        5)
            echo -e "${BLUE}使用说明：${NC}"
            echo "1. 首次使用请先安装 FRP 客户端"
            echo "2. 安装时需要提供服务端地址和认证信息"
            echo "3. 可以通过隧道管理添加不同类型的隧道"
            echo "4. 所有配置更改后会自动重启服务"
            echo "5. 日志文件位置：$LOG_FILE"
            ;;
        6) exit 0 ;;
        *) echo -e "${RED}无效的选项${NC}" ;;
    esac
    read -p "按回车键继续..."
done