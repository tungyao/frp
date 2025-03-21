#/bin/bash
#安装nginx

generate_random_string() {
    head /dev/urandom | tr -dc 'A-Za-z0-9!@#$%^&*()-_=+[]{}<>?' | head -c 32
}
apk update
apk add nginx
apk add wget
wget -O frp_0.61.2_linux_amd64.tar.gz https://github.com/fatedier/frp/releases/download/v0.61.2/frp_0.61.2_linux_amd64.tar.gz
tar xvf frp_0.61.2_linux_amd64.tar.gz
rm -rf frp_0.61.2_linux_amd64.tar.gz
mv frp_0.61.2_linux_amd64 /etc/frp


# 创建 OpenRC 服务脚本
if [ ! -f /etc/init.d/frp ]; then
echo "not exist frp service"
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
fi

# 赋予执行权限
chmod +x /etc/init.d/frp

# 添加到默认启动项
rc-update add frp default

# 启动服务
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

service frp start
