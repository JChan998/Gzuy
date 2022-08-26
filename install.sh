#!/bin/bash

rm -rf $0

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

cur_dir=$(pwd)

# check root
[[ $EUID -ne 0 ]] && echo -e "${red}Lỗi: ${plain} Tập lệnh này phải được chạy dưới quyền root!\n" && exit 1

# check os
if [[ -f /etc/redhat-release ]]; then
    release="centos"
elif cat /etc/issue | grep -Eqi "debian"; then
    release="debian"
elif cat /etc/issue | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /etc/issue | grep -Eqi "centos|red hat|redhat"; then
    release="centos"
elif cat /proc/version | grep -Eqi "debian"; then
    release="debian"
elif cat /proc/version | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /proc/version | grep -Eqi "centos|red hat|redhat"; then
    release="centos"
else
    echo -e "${red}Phiên bản không được tìm thấy, vui lòng liên hệ với tác giả kịch bản!${plain}\n" && exit 1
fi

if [ "$(getconf WORD_BIT)" != '32' ] && [ "$(getconf LONG_BIT)" != '64' ] ; then
    echo "Phần mềm này không hỗ trợ hệ thống 32-bit (x86), vui lòng sử dụng hệ thống 64-bit (x86_64)"
    exit 2
fi

os_version=""

# os version
if [[ -f /etc/os-release ]]; then
    os_version=$(awk -F'[= ."]' '/VERSION_ID/{print $3}' /etc/os-release)
fi
if [[ -z "$os_version" && -f /etc/lsb-release ]]; then
    os_version=$(awk -F'[= ."]+' '/DISTRIB_RELEASE/{print $2}' /etc/lsb-release)
fi

if [[ x"${release}" == x"centos" ]]; then
    if [[ ${os_version} -le 6 ]]; then
        echo -e "${red}Vui lòng sử dụng CentOS 7 trở lên!${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"ubuntu" ]]; then
    if [[ ${os_version} -lt 16 ]]; then
        echo -e "${red}Vui lòng sử dụng Ubuntu 16 hoặc cao hơn!${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"debian" ]]; then
    if [[ ${os_version} -lt 8 ]]; then
        echo -e "${red}Vui lòng sử dụng Debian 8 trở lên!${plain}\n" && exit 1
    fi
fi

install_base() {
    if [[ x"${release}" == x"centos" ]]; then
        yum install epel-release -y
        yum install wget curl unzip tar crontabs socat -y
    else
        apt install wget curl unzip tar cron socat -y
    fi
}

# 0: running, 1: not running, 2: not installed
check_status() {
    if [[ ! -f /etc/systemd/system/XrayR.service ]]; then
        return 2
    fi
    temp=$(systemctl status XrayR | grep Active | awk '{print $3}' | cut -d "(" -f2 | cut -d ")" -f1)
    if [[ x"${temp}" == x"running" ]]; then
        return 0
    else
        return 1
    fi
}

install_acme() {
    curl https://get.acme.sh | sh
}

install_XrayR() {
    if [[ -e /usr/local/XrayR/ ]]; then
        rm /usr/local/XrayR/ -rf
    fi

    mkdir /usr/local/XrayR/ -p
	cd /usr/local/XrayR/

    if  [ $# == 0 ] ;then
        last_version=$(curl -Ls "https://api.github.com/repos/XrayR-project/XrayR/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
        if [[ ! -n "$last_version" ]]; then
            echo -e "${red}Không thể tìm được phiên bản XrayR, có thể đã vượt quá giới hạn API Github, vui lòng thử lại sau hoặc chọn phiên bản XrayR cố định để cài đặt theo cách thủ công${plain}"
            exit 1
        fi
        echo -e "Đã phát hiện phiên bản mới nhất của XrayR：${last_version}，bắt đầu cài đặt"
        wget -N --no-check-certificate -O /usr/local/XrayR/XrayR-linux-64.zip https://github.com/XrayR-project/XrayR/releases/download/${last_version}/XrayR-linux-64.zip
        if [[ $? -ne 0 ]]; then
            echo -e "${red}Không tải xuống được XrayR, hãy đảm bảo máy chủ của bạn có thể tải xuống tệp Github${plain}"
            exit 1
        fi
    else
        last_version=$1
        url="https://github.com/XrayR-project/XrayR/releases/download/${last_version}/XrayR-linux-64.zip"
        echo -e "Bắt đầu cài đặt XrayR v$1"
        wget -N --no-check-certificate -O /usr/local/XrayR/XrayR-linux-64.zip ${url}
        if [[ $? -ne 0 ]]; then
            echo -e "${red}Tải xuống XrayR v$1 không thành công, vui lòng đảm bảo rằng phiên bản này tồn tại${plain}"
            exit 1
        fi
    fi

    unzip XrayR-linux-64.zip
    rm XrayR-linux-64.zip -f
    chmod +x XrayR
    mkdir /etc/XrayR/ -p
    rm /etc/systemd/system/XrayR.service -f
    file="https://github.com/XrayR-project/XrayR-release/raw/master/XrayR.service"
    wget -N --no-check-certificate -O /etc/systemd/system/XrayR.service ${file}
    #cp -f XrayR.service /etc/systemd/system/
    systemctl daemon-reload
    systemctl stop XrayR
    systemctl enable XrayR
    echo -e "${green}XrayR ${last_version}${plain} Quá trình cài đặt hoàn tất, đã được thiết lập để bắt đầu tự động"
    cp geoip.dat /etc/XrayR/
    cp geosite.dat /etc/XrayR/ 

    if [[ ! -f /etc/XrayR/config.yml ]]; then
        cp config.yml /etc/XrayR/
        echo -e ""
        echo -e "Để cài đặt phiên bản mới vui lòng chờ bản update mới nhất từ tác giả."
    else
        systemctl start XrayR
        sleep 2
        check_status
        echo -e ""
        if [[ $? == 0 ]]; then
            echo -e "${green}XrayR khởi động lại thành công${plain}"
        else
            echo -e "${red}XrayR không khởi động được, vui lòng gõ XrayR log để kiểm tra${plain}"
        fi
    fi

    if [[ ! -f /etc/XrayR/dns.json ]]; then
        cp dns.json /etc/XrayR/
    fi
    
    curl -o /usr/bin/XrayR -Ls https://raw.githubusercontent.com/XrayR-project/XrayR-release/master/XrayR.sh
    chmod +x /usr/bin/XrayR
    
    # 设置节点序号
    echo "Đặt số nút"
    echo ""
    read -p "Vui lòng nhập node ID " node_id
    [ -z "${node_id}" ]
    echo "---------------------------"
    echo "Node ID của bạn đặt là: ${node_id}"
    echo "---------------------------"
    echo ""

    # 选择协议
    echo "Chọn giao thức (V2ray mặc định)"
    echo ""
    read -p "Vui lòng nhập giao thức bạn đang sử dụng (V2ray, Shadowsocks, Trojan): " node_type
    [ -z "${node_type}" ]
    
    # 如果不输入默认为V2ray
    if [ ! $node_type ]; then 
    node_type="V2ray"
    fi
    # Trojan
    if [ $node_type == "Trojan" ]; then 
    echo "Vui lòng nhập domain"
    echo ""
    read -p "Domain Trojan TLS: " domain_trojan
    [ -z "${domain_trojan}" ]
    echo "---------------------------"
    echo "Domain của bạn là: ${domain_trojan}"
    echo "---------------------------"
    echo ""
    fi
    
    echo "---------------------------"
    echo "Giao thức bạn chọn là: ${node_type}"
    echo "---------------------------"
    echo ""
    
    # 关闭AEAD强制加密
    echo "Chọn có tắt mã hóa cưỡng bức AEAD hay không (tắt mặc định)"
    echo ""
    read -p "Vui lòng nhập lựa chọn của bạn (1 bật, 0 tắt): " aead_disable
    [ -z "${aead_disable}" ]
   

    # 如果不输入默认为关闭
    if [ ! $aead_disable ]; then
    aead_disable="0"
    fi

    echo "---------------------------"
    echo "Bạn đã chọn ${aead_disable}"
    echo "---------------------------"
    echo ""

    # Writing json
    echo "Đang cố gắng ghi tệp cấu hình ..."
    wget https://raw.githubusercontent.com/JChan998/Gzuy/main/config.yml -O /etc/XrayR/config.yml
    sed -i "s/NodeID:.*/NodeID: ${node_id}/g" /etc/XrayR/config.yml
    sed -i "s/NodeType:.*/NodeType: ${node_type}/g" /etc/XrayR/config.yml
    sed -i "s/CertDomain:.*/CertDomain: "${domain_trojan}"/g" /etc/XrayR/config.yml
    echo ""
    echo "Đã hoàn tất, đang cố khởi động lại dịch vụ XrayR ..."
    echo
    echo "Tắt mã hóa cưỡng bức AEAD ..."
    
    if [ $aead_disable == "0" ]; then
    sed -i 'N;18 i Environment="XRAY_VMESS_AEAD_FORCED=false"' /etc/systemd/system/XrayR.service
    fi

    systemctl daemon-reload
    XrayR restart
    echo "Đang tắt tường lửa!"
    echo
    systemctl disable firewalld
    systemctl stop firewalld
    echo "Dịch vụ XrayR đã được khởi động lại, hãy dùng thử!"
    echo
    #curl -o /usr/bin/XrayR-tool -Ls https://raw.githubusercontent.com/XrayR-project/XrayR/master/XrayR-tool
    #chmod +x /usr/bin/XrayR-tool
    echo -e ""
    echo "XrayR cú pháp tập lệnh "
    echo "------------------------------------------"
    echo "XrayR                    - Menu quản lý (nhiều chức năng)"
    echo "XrayR start              - Khởi động XrayR"
    echo "XrayR stop               - Buộc dừng XrayR"
    echo "XrayR restart            - Khởi động lại XrayR"
    echo "XrayR status             - Xem trạng thái XrayR"
    echo "XrayR enable             - Đặt XrayR bắt đầu tự động"
    echo "XrayR disable            - Hủy tự động khởi động XrayR"
    echo "XrayR log                - Xem nhật ký XrayR"
    echo "XrayR update             - Cập nhật XrayR"
    echo "XrayR update x.x.x       - Cập nhật phiên bản được cố định XrayR"
    echo "XrayR config             - Hiển thị nội dung tệp cấu hình"
    echo "XrayR install            - Cài đặt XrayR"
    echo "XrayR uninstall          - Gỡ cài đặt XrayR"
    echo "XrayR version            - Phiên bản XrayR"
    echo "------------------------------------------"
    echo "Tập lệnh 1 cú pháp cài đặt XrayR"
    echo "Facebook: Fb.com/pntuanhai"
    echo "Lệnh config"
    echo "vi /etc/XrayR/config.yml"
}

echo -e "${green}bắt đầu cài đặt${plain}"
install_base
install_acme
install_XrayR $1
