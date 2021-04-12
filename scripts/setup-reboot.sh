#!/bin/bash
# ------------------------------------------------------------------
#          Install SAP HANA Master Node
#		   invoked once via cloudformation call through user-data
# ------------------------------------------------------------------

SCRIPT_DIR=/root/install/

[ -e /root/install/config.sh ] && source /root/install/config.sh
[ -e /root/install/os.sh ] && source /root/install/os.sh

log() {
	echo $* 2>&1 | tee -a ${HANA_LOG_FILE}
}

if [ $(isRHEL) == 1 ]; then
    #
    log "RedHat has been detected"
    #
    if [ -f /etc/rc.d/rc.local ]; then
        mv /etc/rc.d/rc.local /etc/rc.d/rc.local.bkup.QS
        cp /root/install/rc_local.sh /etc/rc.d/rc.local
    else
        cp /root/install/rc_local.sh /etc/rc.d/rc.local
    fi
elif [ $(isSLES) == 1 ]; then
    #
    log "SUSE has been detected"
    #
    if [ -f /etc/rc.d/boot.local ]; then
        mv /etc/rc.d/boot.local /etc/rc.d/boot.local.bkup.QS
        cp /root/install/rc_local.sh /etc/rc.d/boot.local
    else
        cp /root/install/rc_local.sh /etc/rc.d/boot.local
    fi
else
    log "Unsuppored Operating System detected"
    exit 1
fi
#
shutdown -r now