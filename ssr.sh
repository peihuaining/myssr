#! /bin/bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH
#=================================================================#
#   适用系统:  CentOS 6,7, Debian, Ubuntu                         #
#   描述: One click Install ShadowsocksR Server                   #
#   作者: 91yun <https://twitter.com/91yun>                       #
#   翻译: @小文's blog <https://www.qcgzxw.cn>                    #
#   鸣谢: @Teddysun <i@teddysun.com>                              #
#   介绍: https://www.qcgzxw.cn/?p=533                            #
#=================================================================#



#Current folder
cur_dir=`pwd`
# Get public IP address
IP=$(ip addr | egrep -o '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | egrep -v "^192\.168|^172\.1[6-9]\.|^172\.2[0-9]\.|^172\.3[0-2]\.|^10\.|^127\.|^255\.|^0\." | head -n 1)
if [[ "$IP" = "" ]]; then
    IP=$(wget -qO- -t1 -T2 ipv4.icanhazip.com)
fi

# Make sure only root can run our script
function rootness(){
    if [[ $EUID -ne 0 ]]; then
       echo "Error:This script must be run as root!" 1>&2
       exit 1
    fi
}

# Check OS
function checkos(){
    if [ -f /etc/redhat-release ];then
        OS='CentOS'
    elif [ ! -z "`cat /etc/issue | grep bian`" ];then
        OS='Debian'
    elif [ ! -z "`cat /etc/issue | grep Ubuntu`" ];then
        OS='Ubuntu'
    else
        echo "不支持的系统, 请重装之后再试!"
        exit 1
    fi
}

# Get version
function getversion(){
    if [[ -s /etc/redhat-release ]];then
        grep -oE  "[0-9.]+" /etc/redhat-release
    else    
        grep -oE  "[0-9.]+" /etc/issue
    fi    
}

# CentOS version
function centosversion(){
    local code=$1
    local version="`getversion`"
    local main_ver=${version%%.*}
    if [ $main_ver == $code ];then
        return 0
    else
        return 1
    fi        
}

# Disable selinux
function disable_selinux(){
if [ -s /etc/selinux/config ] && grep 'SELINUX=enforcing' /etc/selinux/config; then
    sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
    setenforce 0
fi
}

# Pre-installation settings
function pre_install(){
    # Not support CentOS 5
    if centosversion 5; then
        echo "不支持 CentOS 5, 请重装系统到 CentOS 6+/Debian 7+/Ubuntu 12+ 再重试."
        exit 1
    fi
    # Set ShadowsocksR config password
     echo "请输入ShadowsocksR连接密码:"
    read -p "(如不输入密码则默认密码: ):" shadowsockspwd
    [ -z "$shadowsockspwd" ] && shadowsockspwd="P314ADsl"
    echo
    echo "---------------------------"
    echo "password = $shadowsockspwd"
    echo "---------------------------"
    echo
    # Set ShadowsocksR config port
    while true
    do
    echo -e "请输入ShadowsocksR连接端口 [1-65535]（建议使用5位数端口）:"
    read -p "(如不输入端口则默认端口: 443):" shadowsocksport
    [ -z "$shadowsocksport" ] && shadowsocksport="443"
    expr $shadowsocksport + 0 &>/dev/null
    if [ $? -eq 0 ]; then
        if [ $shadowsocksport -ge 1 ] && [ $shadowsocksport -le 443 ]; then
            echo
            echo "---------------------------"
            echo "port = $shadowsocksport"
            echo "---------------------------"
            echo
            break
        else
            echo "端口指定错误，请重新输入正确的端口."
        fi
    else
        echo "端口指定错误，请重新输入正确的端口."
    fi
    done
    get_char(){
        SAVEDSTTY=`stty -g`
        stty -echo
        stty cbreak
        dd if=/dev/tty bs=1 count=1 2> /dev/null
        stty -raw
        stty echo
        stty $SAVEDSTTY
    }
    echo
    echo "按任意键开始搭建...或者按Ctrl+C退出搭建"
    char=`get_char`
    # Install necessary dependencies
    if [ "$OS" == 'CentOS' ]; then
        yum install -y wget unzip openssl-devel gcc swig python python-devel python-setuptools autoconf libtool libevent git ntpdate
        yum install -y m2crypto automake make curl curl-devel zlib-devel perl perl-devel cpio expat-devel gettext-devel
    else
        apt-get -y update
        apt-get -y install python python-dev python-pip python-m2crypto curl wget unzip gcc swig automake make perl cpio build-essential git ntpdate
    fi
    cd $cur_dir
}

# Download files
function download_files(){
    # Download libsodium file
    if ! wget --no-check-certificate -O libsodium-1.0.18.tar.gz https://download.libsodium.org/libsodium/releases/libsodium-1.0.18.tar.gz; then
        echo "Failed to download libsodium file!"
        exit 1
    fi
    # Download ShadowsocksR file
    # if ! wget --no-check-certificate -O manyuser.zip https://github.com/breakwa11/shadowsocks/archive/manyuser.zip; then
        # echo "Failed to download ShadowsocksR file!"
        # exit 1
    # fi
    # Download ShadowsocksR chkconfig file
    if [ "$OS" == 'CentOS' ]; then
        if ! wget --no-check-certificate https://raw.githubusercontent.com/qcgzxw/shadowsocks_install/master/shadowsocksR -O /etc/init.d/shadowsocks; then
            echo "Failed to download ShadowsocksR chkconfig file!"
            exit 1
        fi
    else
        if ! wget --no-check-certificate https://raw.githubusercontent.com/qcgzxw/shadowsocks_install/master/shadowsocksR-debian -O /etc/init.d/shadowsocks; then
            echo "Failed to download ShadowsocksR chkconfig file!"
            exit 1
        fi
    fi
}

# firewall set
function firewall_set(){
    echo "firewall set start..."
    if centosversion 6; then
        /etc/init.d/iptables status > /dev/null 2>&1
        if [ $? -eq 0 ]; then
            iptables -L -n | grep '${shadowsocksport}' | grep 'ACCEPT' > /dev/null 2>&1
            if [ $? -ne 0 ]; then
                iptables -I INPUT -m state --state NEW -m tcp -p tcp --dport ${shadowsocksport} -j ACCEPT
                iptables -I INPUT -m state --state NEW -m udp -p udp --dport ${shadowsocksport} -j ACCEPT
                /etc/init.d/iptables save
                /etc/init.d/iptables restart
            else
                echo "端口 ${shadowsocksport} 已设置."
            fi
        else
            echo "WARNING: iptables looks like shutdown or not installed, please manually set it if necessary."
        fi
    elif centosversion 7; then
        systemctl status firewalld > /dev/null 2>&1
        if [ $? -eq 0 ];then
            firewall-cmd --permanent --zone=public --add-port=${shadowsocksport}/tcp
            firewall-cmd --permanent --zone=public --add-port=${shadowsocksport}/udp
            firewall-cmd --reload
        else
			/etc/init.d/iptables status > /dev/null 2>&1
			if [ $? -eq 0 ]; then
				iptables -L -n | grep '${shadowsocksport}' | grep 'ACCEPT' > /dev/null 2>&1
				if [ $? -ne 0 ]; then
					iptables -I INPUT -m state --state NEW -m tcp -p tcp --dport ${shadowsocksport} -j ACCEPT
					iptables -I INPUT -m state --state NEW -m udp -p udp --dport ${shadowsocksport} -j ACCEPT
					/etc/init.d/iptables save
					/etc/init.d/iptables restart
				else
					echo "端口 ${shadowsocksport} 已设置."
				fi
			else
				echo "WARNING: firewall like shutdown or not installed, please manually set it if necessary."
			fi		
        fi
    fi
    echo "firewall set completed..."
}

# Config ShadowsocksR
function config_shadowsocks(){
    cat > /etc/shadowsocks.json<<-EOF
{
    "server": "0.0.0.0",
    "server_ipv6": "::",
    "server_port": ${shadowsocksport},
    "local_address": "127.0.0.1",
    "local_port": 8080,
    "password": "${shadowsockspwd}",
    "timeout": 120,
    "udp_timeout": 60,
    "method": "chacha20",
    "protocol": "auth_aes128_md5",
    "protocol_param": "",
    "obfs": "http_simple_compatible",
    "obfs_param": "",
    "dns_ipv6": false,
    "connect_verbose_info": 1,
    "redirect": "",
    "fast_open": false,
    "workers": 1

}
EOF
}

# Install ShadowsocksR
function install_ss(){
    # Install libsodium
    tar zxf libsodium-1.0.18.tar.gz
    cd $cur_dir/libsodium-1.0.18
    ./configure && make && make install
    echo "/usr/local/lib" > /etc/ld.so.conf.d/local.conf
    ldconfig
    # Install ShadowsocksR
    cd $cur_dir
    # unzip -q manyuser.zip
    # mv shadowsocks-manyuser/shadowsocks /usr/local/
	git clone https://github.com/qcgzxw/ssr.git /usr/local/shadowsocks
    if [ -f /usr/local/shadowsocks/server.py ]; then
        chmod +x /etc/init.d/shadowsocks
        # Add run on system start up
        if [ "$OS" == 'CentOS' ]; then
            chkconfig --add shadowsocks
            chkconfig shadowsocks on
        else
            update-rc.d -f shadowsocks defaults
        fi
        # Run ShadowsocksR in the background
        /etc/init.d/shadowsocks start
         clear
        echo
        echo "祝贺！ ShadowsocksR 已经配置成功!"
        echo -e "服务器 IP: \033[41;37m ${IP} \033[0m"
        echo -e "服务器 端口: \033[41;37m ${shadowsocksport} \033[0m"
        echo -e "连接密码: \033[41;37m ${shadowsockspwd} \033[0m"
		echo -e "加密: \033[41;37m chacha20 \033[0m"
        echo -e "协议: \033[41;37m auth_aes128_md5 \033[0m"
        echo -e "混淆: \033[41;37m http_simple \033[0m"
		echo
		echo
		echo "请下载和你系统版本对应的SSR客户端使用该服务 "
		echo "SSR所有客户端下载地址："
		echo -e "\033[34m https://www.qcgzxw.cn/301.html \033[0m"
		echo
        echo "Vultr实战搭建ssr+锐速教程（内附视频教程）："
		echo -e "\033[34m https://www.qcgzxw.cn/1640.html \033[0m"
		echo
        echo -e "小文's blog地址：\033[34m www.qcgzxw.cn \033[0m"
        echo
    else
        echo "SSR安装失败!"
        install_cleanup
        exit 1
    fi
}


# Install cleanup
function install_cleanup(){
    cd $cur_dir
    rm -f manyuser.zip
    rm -rf shadowsocks-manyuser
    rm -f libsodium-1.0.10.tar.gz
    rm -rf libsodium-1.0.10
}


# Uninstall ShadowsocksR
function uninstall_shadowsocks(){
    printf "Are you sure uninstall ShadowsocksR? (y/n) "
    printf "\n"
    read -p "(Default: n):" answer
    if [ -z $answer ]; then
        answer="n"
    fi
    if [ "$answer" = "y" ]; then
        /etc/init.d/shadowsocks status > /dev/null 2>&1
        if [ $? -eq 0 ]; then
            /etc/init.d/shadowsocks stop
        fi
        checkos
        if [ "$OS" == 'CentOS' ]; then
            chkconfig --del shadowsocks
        else
            update-rc.d -f shadowsocks remove
        fi
        rm -f /etc/shadowsocks.json
        rm -f /etc/init.d/shadowsocks
        rm -rf /usr/local/shadowsocks
        echo "ShadowsocksR uninstall success!"
    else
        echo "uninstall cancelled, Nothing to do"
    fi
}


# Install ShadowsocksR
function install_shadowsocks(){
    checkos
    rootness
    disable_selinux
    pre_install
    download_files
    config_shadowsocks
    install_ss
    if [ "$OS" == 'CentOS' ]; then
        firewall_set > /dev/null 2>&1
    fi
	#check_datetime
    install_cleanup
	
}

# Initialization step
action=$1
[ -z $1 ] && action=install
case "$action" in
install)
    install_shadowsocks
    ;;
uninstall)
    uninstall_shadowsocks
    ;;
*)
    echo "Arguments error! [${action} ]"
    echo "Usage: `basename $0` {install|uninstall}"
    ;;
esac
