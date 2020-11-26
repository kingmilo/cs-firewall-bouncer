#!/usr/bin/env bash
BIN_PATH_INSTALLED="/usr/local/bin/cs-firewall-bouncer"
BIN_PATH="./cs-firewall-bouncer"
CONFIG_DIR="/etc/crowdsec/cs-firewall-bouncer/"
PID_DIR="/var/run/crowdsec/"
SYSTEMD_PATH_FILE="/etc/systemd/system/cs-firewall-bouncer.service"

# Default pkg manager is apt
PKG="apt"
# Default firewall backend is nftables
FW_BACKEND="nftables"
API_KEY=""

check_pkg_manager(){
    if [ -f /etc/redhat-release ] ; then
        PKG="yum"
    fi   
}

check_firewall() {
    iptables="true"
    which iptables > /dev/null
    if [[ $? != 0 ]]; then 
        iptables="false"
    fi

    nftables="true"
    which nft > /dev/null
    if [[ $? != 0 ]]; then 
        nftables="false"
    fi   

    if [ "$nftables" = "false" -a "$iptables" = "false" ]; then
        echo "No firewall found, do you want to install nftables (Y/n) ?"
        read answer
        if [[ ${answer} == "" ]]; then
            answer="y"
        fi
        if [ "$answer" != "${answer#[Yy]}" ] ;then
            "$PKG" install -y -qq nftables > /dev/null && echo "nftables successfully installed"
        else
            echo "unable to continue without nftables. Please install nftables or iptables to use this bouncer." && exit 1
        fi   
    fi

    if [ "$nftables" = "true" -a "$iptables" = "true" ]; then
        echo "Found nftables and iptables, which firewall do you want to use (nftables/iptables)?"
        read answer
        if [ "$answer" = "iptables" ]; then
            FW_BACKEND="iptables"
        fi   
    fi

    if [ "$FW_BACKEND" = "iptables" ]; then
        check_ipset
    fi
}



gen_apikey() {
    SUFFIX=`tr -dc A-Za-z0-9 </dev/urandom | head -c 8`
    API_KEY=`cscli bouncers add cs-firewall-bouncer-${SUFFIX} -o raw`
}

gen_config_file() {
    API_KEY=${API_KEY} BACKEND=${FW_BACKEND} envsubst < ./config/cs-firewall-bouncer.yaml > "${CONFIG_DIR}cs-firewall-bouncer.yaml"
}

check_ipset() {
    which ipset > /dev/null
    if [[ $? != 0 ]]; then
        echo "ipset not found, do you want to install it (Y/n)? "
        read answer
        if [[ ${answer} == "" ]]; then
            answer="y"
        fi
        if [ "$answer" != "${answer#[Yy]}" ] ;then
            "$PKG" install -y -qq ipset > /dev/null && echo "ipset successfully installed"
        else
            echo "unable to continue without ipset. Exiting" && exit 1
        fi      
    fi
}


install_firewall_bouncer() {
	install -v -m 755 -D "${BIN_PATH}" "${BIN_PATH_INSTALLED}"
	mkdir -p "${CONFIG_DIR}"
	cp "./config/cs-firewall-bouncer.yaml" "${CONFIG_DIR}cs-firewall-bouncer.yaml"
	CFG=${CONFIG_DIR} PID=${PID_DIR} BIN=${BIN_PATH_INSTALLED} envsubst < ./config/cs-firewall-bouncer.service > "${SYSTEMD_PATH_FILE}"
	systemctl daemon-reload
}



check_pkg_manager
check_firewall
echo "Installing firewall-bouncer"
install_firewall_bouncer
gen_apikey
gen_config_file
echo "The firewall-bouncer service has been installed!"
