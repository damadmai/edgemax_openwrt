#!/bin/bash

IP=192.168.1.1
HOST=ubnt@${IP}
DEBUG=0

UBNT_FW_SUM=71e36defd8a00ba61031bffd51f3fbb35685394312ca2ba6f5bc0dd7807a0d22
UBNT_FW_URL=https://dl.ui.com/firmwares/edgemax/v2.0.x/
UBNT_FW=ER-e50.v2.0.6.5208541.tar

WRT_TAR_SUM=8f6f370dd7a8bc3e702fba607f175ac5b892a6d8cc852faa94fa73b0f8eccb42
WRT_TAR_URL=https://github.com/stman/OpenWRT-19.07.2-factory-tar-file-for-Ubiquiti-EdgeRouter-x/raw/master/Version%2022.03/
WRT_TAR=openwrt-ramips-mt7621-ubnt_edgerouter-x-initramfs-factory.tar

WRT_V21_SUM=30e606fdcdd7cf271446c4c98848355a3705dfa94372caca6e362b5e9329e522
WRT_V21_URL=https://downloads.openwrt.org/releases/21.02.1/targets/ramips/mt7621/
WRT_V21=openwrt-21.02.1-ramips-mt7621-ubnt_edgerouter-x-sfp-squashfs-sysupgrade.bin

WRT_V23_SUM=daf6816666dbcbe0e5be19a9ff32db2111d84370fdfb1c0106578866cfb2e69a
WRT_V23_URL=https://downloads.openwrt.org/releases/23.05.5/targets/ramips/mt7621/
WRT_V23=openwrt-23.05.5-ramips-mt7621-ubnt_edgerouter-x-sfp-squashfs-sysupgrade.bin

RUN=/opt/vyatta/bin/vyatta-op-cmd-wrapper

SCP_OPTS="-O -o StrictHostKeyChecking=no \
        -o UserKnownHostsFile=/dev/null \
        -o LogLevel=error \
        -oMacs=hmac-sha1"


log()
{
    if [ "${DEBUG}" == "1" ] ;
    then
        echo "${BASH_LINENO[1]} (${BASH_LINENO[0]}): $@"
    else
        echo "$@"
    fi
}

checkbin()
{
    log "Check for '${1}'..."
    if ! command -v ${1} &> /dev/null
    then
        log "Binary '${1}' could not be found"
        exit
    fi
}

iscp()
{
    scp ${SCP_OPTS} ${@}
}

uiscp()
{
    sshpass -p 'ubnt' scp ${SCP_OPTS} ${@}
}

SSH_OPTS="-oMacs=hmac-sha1 \
       -o StrictHostKeyChecking=no \
       -o UserKnownHostsFile=/dev/null \
       -o PubkeyAuthentication=no \
       -o LogLevel=error \
       -o ServerAliveInterval=3 \
       -o ServerAliveCountMax=3 \
       -o ConnectTimeout=20"

issh()
{
    ssh ${SSH_OPTS} ${@}
}

uissh()
{
    sshpass -p 'ubnt' ssh ${SSH_OPTS} ${@}
}

wping()
{
    while ! ping -c 1 -W 1 ${1} > /dev/zero 2>&1 && echo -n .; do sleep 1; done
    echo ""
}

twait()
{
    for i in $(eval echo "{1..${1}}"); do
    	echo -n "." && sleep 1;
    done
    echo ""
}

waitboot()
{
    log "Waiting for ping reply from ${IP}"
    wping ${IP}
    DELAY=15
    log "Got reply, waiting ${DELAY} seconds for SSH availability"
    twait ${DELAY}
}

rebootwait()
{
    log "Reboot device"
    uissh ${HOST} "sudo reboot"
    log "Waiting for reboot"
    if [[ "${1}" == "20" ]]; then
        log "Please disconnect from eth0 and connect to eth1"

    fi
    twait ${1}
    waitboot
}

checkbin "wget"
checkbin "sshpass"
checkbin "scp"
checkbin "sha256sum"
checkbin "ping"

wget -nc ${UBNT_FW_URL}${UBNT_FW}
echo "${UBNT_FW_SUM} ${UBNT_FW}" | sha256sum -c - || exit 0

wget -nc ${WRT_TAR_URL}${WRT_TAR}
echo "${WRT_TAR_SUM} ${WRT_TAR}" | sha256sum -c - || exit 0

wget -nc ${WRT_V21_URL}${WRT_V21}
echo "${WRT_V21_SUM} ${WRT_V21}" | sha256sum -c - || exit 0

wget -nc ${WRT_V23_URL}${WRT_V23}
echo "${WRT_V23_SUM} ${WRT_V23}" | sha256sum -c - || exit 0

echo ""
waitboot
log "Delete additional firmware image"
uissh ${HOST} "echo Yes | ${RUN} delete system image"
log "Copy firmware ${UBNT_FW} to device RAM"
uiscp ${UBNT_FW} ${HOST}:/tmp
log "Write firmware to flash"
uissh ${HOST} ${RUN} add system image /tmp/${UBNT_FW}
rebootwait 10
log "Checking Bootloader"
OUT=$(uissh ${HOST} ${RUN} show system boot-image)
log "${OUT}"
if [[ "$OUT" == *"to upgrade"* ]]; then
    log "Upgrading Bootloader"
    uissh ${HOST} "echo Yes | ${RUN} add system boot-image"
    rebootwait 10
fi

log "Delete old firmware image"
uissh ${HOST} "echo Yes | ${RUN} delete system image"
log "Copy firmware ${WRT_TAR} to device RAM"
uiscp ${WRT_TAR} ${HOST}:/tmp
log "Write firmware to flash"
uissh ${HOST} ${RUN} add system image /tmp/${WRT_TAR}
rebootwait 20

HOST=root@${IP}
log "Copy V21 firmware ${WRT_V21} to device RAM"
iscp ${WRT_V21} ${HOST}:/tmp/
log "Write firmware to flash"
issh ${HOST} sysupgrade --force -n /tmp/${WRT_V21}
log "Waiting for reboot"
twait 25
waitboot

HOST=root@${IP}
log "Copy firmware ${WRT_V23} to device RAM"
iscp ${WRT_V23} ${HOST}:/tmp/
log "Write firmware to flash"
issh ${HOST} sysupgrade --force -n /tmp/${WRT_V23}
log "Waiting for reboot"
twait 25
waitboot

issh ${HOST} cat /etc/banner
log "Finished"
