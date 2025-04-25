#!/bin/bash
# 安装 nginx

detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        if [ -n "$ID" ]; then
            echo "$ID"
        else
            echo "unknown"
        fi
    else
        echo "unknown"
    fi
}

install_packages() {
    os=$(detect_os)
    case "$os" in
        alpine)
            apk update
            apk add nginx wget
            ;;
        ubuntu)
            apt update
            apt install -y nginx wget
            ;;
        *)
            echo "Unsupported OS: $os"
            exit 1
            ;;
    esac
}

generate_random_string() {
    head /dev/urandom | tr -dc 'A-Za-z0-9!@#$%^&*()-_=+[]{}<>?' | head -c 32
}

setup_service() {
    os=$(detect_os)
    case "$os" in
        alpine)
            # 创建 OpenRC 服务脚本
            if [ ! -f /etc/init.d/frp ]; then
                echo "Creating OpenRC service for Alpine..."
                cat <<EOF > /etc/init.d/frp
#!/sbin/openrc-run

name="frp"
description="FRP Reverse Proxy Service"

command="/etc/frp/frps"
command_args="-c /etc/frp/frps.toml"
command_background=true
pidfile="/run/\${RC_SVCNAME}.pid"

depend() {
    need localmount
}
EOF
                chmod +x /etc/init.d/frp
            fi

            # 添加到默认启动项并启动服务
            rc-update add frp default
            service frp start
            ;;
        ubuntu)
            # 创建 systemd 服务文件
            if [ ! -f /etc/systemd/system/frp.service ]; then
                echo "Creating systemd service for Ubuntu..."
                cat <<EOF > /etc/systemd/system/frp.service
[Unit]
Description=FRP Reverse Proxy Service
After=network.target

[Service]
Type=simple
ExecStart=/etc/frp/frps -c /etc/frp/frps.toml
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
                chmod 644 /etc/systemd/system/frp.service
            fi

            # 重新加载 systemd 配置，添加到启动项并启动服务
            systemctl daemon-reload
            systemctl enable frp
            systemctl start frp
            ;;
        *)
            echo "Unsupported OS: $os"
            exit 1
            ;;
    esac
}

# 安装必要的软件包
install_packages

# 下载和配置 FRP
wget -O frp_0.61.2_linux_amd64.tar.gz https://github.com/fatedier/frp/releases/download/v0.61.2/frp_0.61.2_linux_amd64.tar.gz
tar xvf frp_0.61.2_linux_amd64.tar.gz
rm -rf frp_0.61.2_linux_amd64.tar.gz
mv frp_0.61.2_linux_amd64 /etc/frp

# 配置 FRP 服务和启动项
setup_service

# 配置 FRP 的运行参数
echo "edit frp config"
echo "========================"

read -p "bindPort: " bindPort
bindPort=${bindPort:-7000}

read -p "vhostHTTPPort: " vhostHTTPPort
vhostHTTPPort=${vhostHTTPPort:-10080}

read -p "vhostHTTPSPort: " vhostHTTPSPort
vhostHTTPSPort=${vhostHTTPSPort:-10443}

read -p "webServer.user: " user
user=${user:-10443}

default_pass=$(generate_random_string)
read -p "webServer.password: random($default_pass)" password
password=${password:-$default_pass}

default_token=$(generate_random_string)
read -p "auth.token: random($default_token)" token
token=${token:-$default_token}

read -p "subDomainHost: " subDomainHost

cat <<EOF > /etc/frp/frps.toml
bindPort = $bindPort
vhostHTTPPort = $vhostHTTPPort
vhostHTTPSPort = $vhostHTTPSPort

webServer.addr = "0.0.0.0"
webServer.port = 6443
webServer.user = "$user"
webServer.password = "$password"

auth.method = "token"
auth.token = "$token"

subDomainHost = "$subDomainHost"
EOF

echo "FRP service has been set up and started!"
