#!/bin/bash

# 检查是否安装了 jq
if ! command -v jq &> /dev/null; then
  echo "此脚本需要 jq，请使用以下命令安装："
  echo "sudo apt install jq"
  exit 1
fi

# 检查是否已有 Go 安装
if [ -d /usr/local/go ]; then
  echo "在 /usr/local/go 找到现有 Go 安装"
  read -p "是否删除现有版本并安装新版本？(y/n) " answer
  if [ "$answer" != "y" ]; then
    echo "安装已取消"
    exit 0
  fi
  sudo rm -rf /usr/local/go
fi

# 获取最新的五个稳定 Go 版本
mapfile -t versions < <(curl -s https://go-version.tungyao.cn | jq -r '.[].name' | grep '^1\.[0-9]\+\.[0-9]\+$' | sort -V -r | head -n 5)

# 检查是否找到版本
if [ ${#versions[@]} -eq 0 ]; then
  echo "未找到 Go 版本，请稍后重试。"
  exit 1
fi

# 显示最新五个版本
echo "最新的五个 Go 版本："
for i in "${!versions[@]}"; do
  echo "$((i+1)). ${versions[i]}"
done

# 提示用户选择版本
read -p "请输入要安装的版本编号 (1-${#versions[@]}): " choice
if ! [[ $choice =~ ^[0-9]+$ ]] || [ $choice -lt 1 ] || [ $choice -gt ${#versions[@]} ]; then
  echo "无效的选择"
  exit 1
fi
let choice--
selected_ver=${versions[$choice]}

# 确定系统架构
case $(uname -m) in
  x86_64) arch=amd64 ;;
  aarch64) arch=arm64 ;;
  *) echo "不支持的架构：$(uname -m)"; exit 1 ;;
esac

# 构建下载 URL
url="https://go.dev/dl/go${selected_ver}.linux-${arch}.tar.gz"

# 下载选定版本
echo "正在下载 $url"
wget -O /tmp/go.tar.gz $url
if [ $? -ne 0 ]; then
  echo "下载失败"
  exit 1
fi

# 解压到 /usr/local
echo "正在解压到 /usr/local"
sudo tar -C /usr/local -xzf /tmp/go.tar.gz
if [ $? -ne 0 ]; then
  echo "解压失败"
  exit 1
fi


# 清理下载的文件
rm /tmp/go.tar.gz

# 自动添加到当前会话的 PATH
if [[ ":$PATH:" != *":/usr/local/go/bin:"* ]]; then
    export PATH=$PATH:/usr/local/go/bin
    echo "已将 /usr/local/go/bin 添加到当前会话的 PATH"
else
    echo "/usr/local/go/bin 已在当前会话的 PATH 中"
fi

# 添加到 ~/.bashrc 如果不存在
if ! grep -q 'export PATH=$PATH:/usr/local/go/bin' ~/.bashrc; then
    echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.bashrc
    echo "已将 /usr/local/go/bin 添加到 ~/.bashrc"
else
    echo "PATH 已包含 /usr/local/go/bin 在 ~/.bashrc 中"
fi

echo "Go ${selected_ver} 已安装到 /usr/local/go"
source ~/.baserc
echo "您现在可以直接使用 go 命令"
