#!/bin/bash
# ------------------------------------------------------------------
#          Install SAP HANA Master Node
#		   invoked once via cloudformation call through user-data
# ------------------------------------------------------------------

SCRIPT_DIR=/root/install/
ROLE=$1

[ -e /root/install/config.sh ] && source /root/install/config.sh
[ -e /root/install/os.sh ] && source /root/install/os.sh

log() {
	echo $* 2>&1 | tee -a ${HANA_LOG_FILE}
}

setup_new_rclocal_rhel() {
    #
    log `date` "Automatic Reboot - RHEL - placing new rc.local file"
    cp /root/install/rc_local_${ROLE}.sh /etc/rc.d/rc.local
    chmod +x /etc/rc.d/rc.local
}

setup_new_rclocal_sles() {
    #
    log `date` "Automatic Reboot - SLES - placing new rc.local file"
    cp /root/install/rc_local_${ROLE}.sh /etc/rc.d/boot.local
    chmod +x /etc/rc.d/boot.local
}

setup_existing_rclocal_rhel() {
    #
    log `date` "Automatic Reboot - RHEL - creating backup of existing rc.local file"
    mv /etc/rc.d/rc.local /etc/rc.d/rc.local.bkup.QS
    cp /root/install/rc_local_${ROLE}.sh /etc/rc.d/rc.local
    chmod +x /etc/rc.d/rc.local
}

setup_existing_rclocal_sles() {
    #
    log `date` "Automatic Reboot - SLES - creating backup of existing rc.local file"
    mv /etc/rc.d/boot.local /etc/rc.d/boot.local.bkup.QS
    cp /root/install/rc_local_${ROLE}.sh /etc/rc.d/boot.local
    chmod +x /etc/rc.d/rc.local /etc/rc.d/boot.local
}

reboot_instance() {
    #
    log `date` "Automatic Reboot - Rebooting now"
    shutdown -r now
}

if [ $(isRHEL) == 1 ]; then
    #
    log `date` "RedHat has been detected - setting up reboot environment"
    #
    if [ -f /etc/rc.d/rc.local ]; then
        setup_existing_rclocal_sles
    else
        setup_new_rclocal_sles
    fi
    reboot_instance
elif [ $(isSLES) == 1 ]; then
    #
    log `date` "SUSE has been detected - setting up reboot environment"
    #
    if [ -f /etc/rc.d/boot.local ]; then
        setup_existing_rclocal_rhel
    else
        setup_new_rclocal_rhel
    fi
    reboot_instance
else
    log "Unsuppored Operating System detected"
    exit 1
fi
#