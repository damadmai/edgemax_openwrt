#!/bin/bash

IP=192.168.1.1
IP_WRT=192.168.1.1
HOST=ubnt@${IP}

UBNT_FW_SUM=71e36defd8a00ba61031bffd51f3fbb35685394312ca2ba6f5bc0dd7807a0d22
UBNT_FW_URL=https://dl.ui.com/firmwares/edgemax/v2.0.x/
UBNT_FW=ER-e50.v2.0.6.5208541.tar

WRT_TAR_SUM=cb6e043a6175393e4658b0031e7efe0fb4dcedf8b2df6a3bdaa7732d35fe7c08
WRT_TAR_URL=http://openwrt.jaru.eu.org/openwrt-18.06/targets/ramips/mt7621/
WRT_TAR=openwrt-18.06-snapshot-r7911-f65330d27d-ramips-mt7621-ubnt-erx-sfp-initramfs-factory.tar

WRT_BIN_SUM=30e606fdcdd7cf271446c4c98848355a3705dfa94372caca6e362b5e9329e522
WRT_BIN_URL=https://downloads.openwrt.org/releases/21.02.1/targets/ramips/mt7621/
WRT_BIN=openwrt-21.02.1-ramips-mt7621-ubnt_edgerouter-x-sfp-squashfs-sysupgrade.bin

RUN=/opt/vyatta/bin/vyatta-op-cmd-wrapper

SCP_OPTS="-o StrictHostKeyChecking=no \
        -o UserKnownHostsFile=/dev/null \
        -o LogLevel=error \
        -oMacs=hmac-sha1"

iscp()
{
    scp ${SCP_OPTS} ${@}
}

uiscp()
{
    sshpass -p ubnt scp ${SCP_OPTS} ${@}
}

SSH_OPTS="-oMacs=hmac-sha1 \
       -o StrictHostKeyChecking=no \
       -o UserKnownHostsFile=/dev/null \
       -o PubkeyAuthentication=no \
       -o LogLevel=error \
       -o ServerAliveInterval=3 \
       -o ServerAliveCountMax=3"

issh()
{
    ssh ${SSH_OPTS} ${@}
}

uissh()
{
    sshpass -p ubnt ssh ${SSH_OPTS} ${@}
}

wping()
{
    while ! ping -c 1 -W 1 ${1} > /dev/zero 2>&1 && echo -n .; do sleep 1; done
    echo ""
}

twait()
{
    for i in $(eval echo "{1..${1}}"); do echo -n . && sleep 1; done
    echo ""
}

waitboot()
{
    echo "Waiting for ping reply from ${IP}"
    wping ${IP}
    DELAY=15
    echo "Got reply, waiting ${DELAY} seconds for SSH availability"
    twait ${DELAY}
}

rebootwait()
{
    echo "Reboot device"
    uissh ${HOST} "sudo reboot"
    echo Waiting for reboot
    if [[ "${1}" == "20" ]]; then
        echo Please disconnect from eth0 and connect to eth1
    fi
    twait ${1}
    waitboot
}

wget -nc ${UBNT_FW_URL}${UBNT_FW}
echo "${UBNT_FW_SUM} ${UBNT_FW}" | sha256sum -c - || exit 0

wget -nc ${WRT_TAR_URL}${WRT_TAR}
echo "${WRT_TAR_SUM} ${WRT_TAR}" | sha256sum -c - || exit 0

wget -nc ${WRT_BIN_URL}${WRT_BIN}
echo "${WRT_BIN_SUM} ${WRT_BIN}" | sha256sum -c - || exit 0

echo ""
waitboot
echo "Delete additional firmware image"
uissh ${HOST} "echo Yes | ${RUN} delete system image"
echo "Copy firmware ${UBNT_FW} to device RAM"
uiscp ${UBNT_FW} ${HOST}:/tmp
echo "Write firmware to flash"
uissh ${HOST} ${RUN} add system image /tmp/${UBNT_FW}
rebootwait 10
echo "Checking Bootloader"
OUT=$(uissh ${HOST} ${RUN} show system boot-image)
echo "${OUT}"
if [[ "$OUT" == *"to upgrade"* ]]; then
    echo "Upgrading Bootloader"
    uissh ${HOST} "echo Yes | ${RUN} add system boot-image"
    rebootwait 10
fi

echo "Delete old firmware image"
uissh ${HOST} "echo Yes | ${RUN} delete system image"
echo "Copy firmware ${WRT_TAR} to device RAM"
uiscp ${WRT_TAR} ${HOST}:/tmp
echo "Write firmware to flash"
uissh ${HOST} ${RUN} add system image /tmp/${WRT_TAR}
rebootwait 20

HOST=root@${IP}
echo "Copy firmware ${WRT_BIN} to device RAM"
iscp ${WRT_BIN} ${HOST}:/tmp/
echo "Write firmware to flash"
issh ${HOST} sysupgrade --force -n /tmp/${WRT_BIN}
echo "Waiting for reboot"
twait 15
waitboot
issh ${HOST} cat /etc/banner
echo "Finished"
