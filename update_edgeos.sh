#!/bin/bash

IP=192.168.1.1
HOST=ubnt@${IP}
DEBUG=0

UBNT_FW_SUM=1d6ca85f9c7cfd61382c0bb8b9c0e78f3abd3abba2da23c53721409d9d43397d
UBNT_FW_URL=https://dl.ui.com/firmwares/edgemax/v2.0.9-hotfix.7/
UBNT_FW=ER-e50.v2.0.9-hotfix.7.5622731.tar

RUN=/opt/vyatta/bin/vyatta-op-cmd-wrapper

SCP_OPTS="-o StrictHostKeyChecking=no \
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

log "Waiting for reboot"
rebootwait 20
uissh ${HOST} ${RUN} show system image
log "Finished"
