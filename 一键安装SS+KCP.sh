#!/bin/bash

echo -e """\033[41m
欢迎使用 Shadowsocks+KCP 一键脚本
目前仅在 centos7.7 、ubuntu18.04 系统上测试通过，其他发行版请自测

本脚本仅供学习研究使用，切勿用于非法用途，造成的一切后果由使用者承担！
\033[0m"""

read -p "是否继续？[Y/n]" continue
if [ $continue != "Y" ] && [ $continue != "y" ]; then
    exit
fi

user=$(whoami)
if [ "$user" != "root" ]; then
    echo -e "\033[41m请使用root权限运行该脚本\033[0m"
    exit
fi

# centos 系列依赖安装
if [ -f "/etc/redhat-release" ]; then
    echo -e "\033[33m当前系统为centos发行版...开始安装编译所需依赖...\033[0m"
    yum update -y
    yum install epel-release -y
    yum install git gcc gettext autoconf libtool automake make pcre-devel asciidoc xmlto c-ares-devel libev-devel libsodium-devel mbedtls-devel wget curl -y
fi

# ubuntu 系列依赖安装
ubuntu=$(command -v lsb_release)
if [ "$ubuntu" != "" ]; then
    echo -e "\033[33m当前系统为ubuntu发行版...开始安装编译所需依赖...\033[0m"
    apt-get update -y
    apt-get install git gettext build-essential autoconf libtool libpcre3-dev asciidoc-base xmlto libev-dev libc-ares-dev automake libmbedtls-dev libsodium-dev wget curl -y
fi

echo -e "\033[33m依赖安装完毕\033[0m"

echo -e "\033[34m下载shadowsocks-libev源码...\033[0m"
cd /tmp
git clone https://github.com/shadowsocks/shadowsocks-libev.git
cd shadowsocks-libev
git submodule update --init --recursive

echo -e "\033[34m开始编译...\033[0m"
./autogen.sh && ./configure && make && make install

echo -e "\033[35m[shadowsocks-libev]编译成功\033[0m"
rm -rf /tmp/shadowsocks-libev

# 配置 Shadowsocks
echo """
开始配置 Shadowsocks，请仔细填写
"""
ss_listen_ip="127.0.0.1"
read -p "请设置 Shadowsocks 监听地址（默认：$ss_listen_ip）:" ss_listen_ip
ss_listen_ip=${ss_listen_ip:-"127.0.0.1"}

ss_listen_port=135
read -p "请设置 Shadowsocks 监听端口（TCP&UDP，默认：$ss_listen_port）:" ss_listen_port
ss_listen_port=${ss_listen_port:-135}

ss_password="passwd"
read -p "请设置 Shadowsocks 密码（默认：$ss_password）:" ss_password
ss_password=${ss_password:-"passwd"}

ss_encrypt_method="aes-256-cfb"
read -p "请设置 Shadowsocks 加密算法（不懂请别乱写，默认：$ss_encrypt_method）:" ss_encrypt_method
ss_encrypt_method=${ss_encrypt_method:-"aes-256-cfb"}

# 创建目录
if [ ! -d "/etc/shadowsocks-libev" ]; then
    mkdir /etc/shadowsocks-libev
fi
# 生成配置文件
echo """
{
    \"server\":\"$ss_listen_ip\",
    \"server_port\":$ss_listen_port,
    \"local_port\":1080,
    \"password\":\"unashunn\",
    \"timeout\":60,
    \"method\":\"$ss_encrypt_method\"
}
""" > /etc/shadowsocks-libev/config.json

# 启动 Shadowsocks
ss=$(whereis ss-server | cut -d " " -f 2)
nohup $ss -c /etc/shadowsocks-libev/config.json >> /tmp/shadowsocks-libev.log 2>&1 &
echo -e "\033[36mShadowsocks启动成功\033[0m"


# 下载KCP
system_bit=$(getconf LONG_BIT)
base_url="https://github.com"
download_url=""
kcptun_name=""
if [ $system_bit == "64" ]; then
    download_url=$(curl -s -L https://github.com/xtaci/kcptun/releases/latest | grep "/xtaci/kcptun/releases/download/[^\s]*/kcptun-linux-amd64-[^\s]*.tar.gz" -o)
    kcptun_name="server_linux_amd64"
else
    download_url=$(curl -s -L https://github.com/xtaci/kcptun/releases/latest | grep "/xtaci/kcptun/releases/download/[^\s]*/kcptun-linux-386-[^\s]*.tar.gz" -o)
    kcptun_name="server_linux_386"
fi

if [ ! -d "/opt/kcptun" ]; then
    mkdir /opt/kcptun
fi
wget --no-check-certificate $base_url$download_url -O /opt/kcptun/kcp.tar.gz

tar -zxvf /opt/kcptun/kcp.tar.gz -C /opt/kcptun/
rm -f /opt/kcptun/kcp.tar.gz

kcptun="/opt/kcptun/$kcptun_name"

echo """
开始配置 KCP，请仔细填写
"""

kcp_listen_port=202
read -p "请设置 KCP 监听端口（UDP，默认：$kcp_listen_port）:" kcp_listen_port
kcp_listen_port=${kcp_listen_port:-202}

kcp_encrypt_method="xor"
read -p "请设置 KCP 加密算法（不懂请别乱写，默认：$kcp_encrypt_method）:" kcp_encrypt_method
kcp_encrypt_method=${kcp_encrypt_method:-"xor"}

kcp_key="MsyR#8rL45GYnyHh"
read -p "请设置 KCP 加密密钥（默认：$kcp_key）:" kcp_key
kcp_key=${kcp_key:-"MsyR#8rL45GYnyHh"}

kcp_mode="fast2"
read -p "请设置 KCP 加速模式（默认：$kcp_mode）:" kcp_mode
kcp_mode=${kcp_mode:-"fast2"}

kcp_sndwnd=2048
read -p "请设置 KCP 发送缓冲大小（默认：$kcp_sndwnd）:" kcp_sndwnd
kcp_sndwnd=${kcp_sndwnd:-2048}

kcp_rcvwnd=2048
read -p "请设置 KCP 接收缓冲大小（默认：$kcp_rcvwnd）:" kcp_rcvwnd
kcp_rcvwnd=${kcp_rcvwnd:-2048}

# 普通的KCP配置
nohup $kcptun -l :$kcp_listen_port -t 127.0.0.1:$ss_listen_port --crypt $kcp_encrypt_method --key $kcp_key --mode $kcp_mode --dscp 64 --sndwnd $kcp_sndwnd --rcvwnd $kcp_rcvwnd >> /tmp/kcp.log 2>&1 &
echo -e "\033[36mKCP启动成功\033[0m"

read -p "是否启用IOS专版KCP（兼容小火箭的KCP配置）[Y/n]？:" start_ios
if [ $start_ios == "y" ] || [ $start_ios == "Y" ]; then
    read -p "请设置IOS专版KCP监听端口:" kcp_for_ios_port
    if [ $kcp_for_ios_port != "" ];then
        # IOS小火箭的KCP配置
        nohup $kcptun -l :$kcp_for_ios_port -t 127.0.0.1:$ss_listen_port --crypt $kcp_encrypt_method --key $kcp_key --mode $kcp_mode --dscp 64 --sndwnd $kcp_sndwnd --rcvwnd $kcp_rcvwnd -nocomp >> /tmp/kcp_ios.log 2>&1 &
        echo -e "\033[36mIOS版KCP启动成功\033[0m"
    fi
fi
echo -e "\033[32m感谢使用\033[0m"

