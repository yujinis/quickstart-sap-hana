#!/bin/bash

# ------------------------------------------------------------------
#         Global Variables
# ------------------------------------------------------------------

SCRIPT_DIR=/root/install/
CLUSTERWATCH_SCRIPT=${SCRIPT_DIR}/ClusterWatchEngine.sh
MIN_KERN="30"
OSRELEASE="/etc/os-release"

# ------------------------------------------------------------------
#          Choose default log file
# ------------------------------------------------------------------

if [ -z "${HANA_LOG_FILE}" ] ; then
    if [ ! -d "/root/install/" ]; then
      mkdir -p "/root/install/"
    fi
    HANA_LOG_FILE=/root/install/install.log
fi

[ -e /root/install/config.sh ] && source /root/install/config.sh
[ -e /root/install/os.sh ] && source /root/install/os.sh

while getopts ":l:" o; do
    case "${o}" in
        l)
            HANA_LOG_FILE=${OPTARG}
            ;;
        *)
            usage
            ;;
    esac
done

shift $((OPTIND-1))
[[ $# -gt 0 ]] && usage;


#***BEGIN Functions***

# ------------------------------------------------------------------
#
#          Install SAP HANA prerequisites (master node)
#
# ------------------------------------------------------------------


usage() {
    cat <<EOF
    Usage: $0 [options]
        -h print usage
        -l HANA_LOG_FILE [optional]
EOF
    exit 1
}

check_kernel() {

    KERNEL=$(uname -r | cut -c 1-4 | awk -F"." '{ print $1$2 }')

    if [ "$KERNEL" -gt "$MIN_KERN" ]
    then
    	echo 1
    else
    	echo 0
    fi
}

check_zypper() {

    ZRM=$(zypper -n remove cpupower )
    ZINST=$(zypper -n install cpupower | grep done )

    if [ "$ZINST" ]
    then
    	echo 1
    else
    	echo 0
    fi
}

check_slesforsap() {

    SLESFORSAP=$(grep -i sap "$OSRELEASE" )

    if [ "$SLESFORSAP" ]
    then
        echo 1
    else
        echo 0
    fi
}

check_instancetype() {
	INSTANCE_TYPE=$(curl http://169.254.169.254/latest/meta-data/instance-type 2> /dev/null )
	IS_IT_X1=$(echo $INSTANCE_TYPE | grep -i x1)

	if [ "$IS_IT_X1" ]
	then
	    echo 1
	else
	    echo 0
	fi
}


# ------------------------------------------------------------------
#          Output log to HANA_LOG_FILE
# ------------------------------------------------------------------

log() {

    echo $* 2>&1 | tee -a ${HANA_LOG_FILE}

}

install_prereq() {

    # ------------------------------------------------------------------
    #          Install all the pre-requisites for SAP HANA
    # ------------------------------------------------------------------

    log "## Installing HANA Prerequisites...## "

    zypper -n install gtk2 2>&1 | tee -a ${HANA_LOG_FILE}
    zypper -n install java-1_6_0-ibm 2>&1 | tee -a ${HANA_LOG_FILE}
    zypper -n install libicu  | tee -a ${HANA_LOG_FILE}
    zypper -n install mozilla-xulrunner*  | tee -a ${HANA_LOG_FILE}
    zypper se xulrunner  | tee -a ${HANA_LOG_FILE}
    zypper -n install ntp  | tee -a ${HANA_LOG_FILE}
    zypper -n install sudo  | tee -a ${HANA_LOG_FILE}
    zypper -n install syslog-ng  | tee -a ${HANA_LOG_FILE}
    zypper -n install tcsh libssh2-1 | tee -a ${HANA_LOG_FILE}
    zypper -n install autoyast2-installation | tee -a ${HANA_LOG_FILE}
    zypper -n install yast2-ncurses  | tee -a ${HANA_LOG_FILE}
    zypper -n install cpupower  | tee -a ${HANA_LOG_FILE}


    # ------------------------------------------------------------------
    # In order to install SAP HANA on SLES 12 or SLES 12 for SAP Applications
    # please refer also to SAP note "1944799 SAP HANA Guidelines for SLES Operating System installation".
    # For running SAP HANA you may need libopenssl version 0.9.8.
    # This version of libopenssl is provided with the so called Legacy Module of SLE 12. When you added the software repository as described above install you can install the libopenssl 0.9.8 via zypper, yast2 etc. e.g. by calling
    # ------------------------------------------------------------------

    if [ $(isSLES12) == 1  -o  $(isSLES12SP1) == 1 ]
    then
	     zypper -n in libopenssl0_9_8 | tee -a ${HANA_LOG_FILE}
    fi

    # ------------------------------------------------------------------
    #          Install unrar for media extraction
    # ------------------------------------------------------------------

    zypper -n install unrar  | tee -a ${HANA_LOG_FILE}

    #SLES 12 installation fails with libnuma
    zypper -n install libnuma-devel | tee -a ${HANA_LOG_FILE}

    chkconfig boot.kdump  | tee -a ${HANA_LOG_FILE}
    chkconfig kdump off
    echo "net.ipv4.tcp_slow_start_after_idle=0" >> /etc/sysctl.conf
    sysctl -p /etc/sysctl.conf  | tee -a ${HANA_LOG_FILE}

    #ipcs -l  | tee -a ${HANA_LOG_FILE}
    echo "kernel.shmmni=65536" >> /etc/sysctl.conf
    sysctl -p /etc/sysctl.conf  | tee -a ${HANA_LOG_FILE}

    #error check and return
}

install_prereq_sles12() {
  # ------------------------------------------------------------------
  #          Install all the pre-requisites for SAP HANA
  # ------------------------------------------------------------------

  log "## Installing required OS Packages## "

  zypper -n install gtk2 2>&1 | tee -a ${HANA_LOG_FILE}
  zypper -n install java-1_6_0-ibm 2>&1 | tee -a ${HANA_LOG_FILE}
  zypper -n install libicu  | tee -a ${HANA_LOG_FILE}
  zypper -n install mozilla-xulrunner*  | tee -a ${HANA_LOG_FILE}
  zypper -n install ntp  | tee -a ${HANA_LOG_FILE}
  zypper -n install sudo  | tee -a ${HANA_LOG_FILE}
  zypper -n install syslog-ng  | tee -a ${HANA_LOG_FILE}
  zypper -n install tcsh libssh2-1 | tee -a ${HANA_LOG_FILE}
  zypper -n install autoyast2-installation | tee -a ${HANA_LOG_FILE}
  zypper -n install yast2-ncurses  | tee -a ${HANA_LOG_FILE}
  zypper -n install cpupower  | tee -a ${HANA_LOG_FILE}
  zypper -n install libopenssl0_9_8 | tee -a ${HANA_LOG_FILE}
  zypper -n install libgcc_s1 | tee -a ${HANA_LOG_FILE}
  zypper -n install libstdc++6  | tee -a ${HANA_LOG_FILE}
 
  #SLES 12 installation fails with libnuma
  zypper -n install libnuma-devel | tee -a ${HANA_LOG_FILE}
  
  #Install unrar for media extraction
  zypper -n install unrar  | tee -a ${HANA_LOG_FILE}
  
  # Install GCC and GC++ compilers. GCC includes package libatomic1 that is required for all GCC 7 compiled apps, see OSS note 2593824.
  zypper -n install gcc | tee -a ${HANA_LOG_FILE}
  zypper -n install gcc-c++ | tee -a ${HANA_LOG_FILE}
 
  # Install most current libatomic1 if available
  zypper -n install libatomic1 | tee -a ${HANA_LOG_FILE}
 
  #Remove ulimit package
  zypper remove ulimit > /dev/null
  
  chkconfig boot.kdump  | tee -a ${HANA_LOG_FILE}
  chkconfig kdump off
  echo "net.ipv4.tcp_slow_start_after_idle=0" >> /etc/sysctl.conf
  sysctl -p /etc/sysctl.conf  | tee -a ${HANA_LOG_FILE}
  echo "kernel.shmmni=65536" >> /etc/sysctl.conf
  sysctl -p /etc/sysctl.conf  | tee -a ${HANA_LOG_FILE}

}

install_prereq_sles12sp1() {
    # ------------------------------------------------------------------
    #          Install all the pre-requisites for SAP HANA
    # ------------------------------------------------------------------

    log "## Installing required OS Packages## "

    zypper -n install gtk2 2>&1 | tee -a ${HANA_LOG_FILE}
    zypper -n install java-1_6_0-ibm 2>&1 | tee -a ${HANA_LOG_FILE}
    zypper -n install libicu  | tee -a ${HANA_LOG_FILE}
    zypper -n install mozilla-xulrunner*  | tee -a ${HANA_LOG_FILE}
    zypper -n install ntp  | tee -a ${HANA_LOG_FILE}
    zypper -n install sudo  | tee -a ${HANA_LOG_FILE}
    zypper -n install syslog-ng  | tee -a ${HANA_LOG_FILE}
    zypper -n install tcsh libssh2-1 | tee -a ${HANA_LOG_FILE}
    zypper -n install autoyast2-installation | tee -a ${HANA_LOG_FILE}
    zypper -n install yast2-ncurses  | tee -a ${HANA_LOG_FILE}
    zypper -n install cpupower  | tee -a ${HANA_LOG_FILE}
    zypper -n install libopenssl0_9_8 | tee -a ${HANA_LOG_FILE}
    zypper -n install libgcc_s1 | tee -a ${HANA_LOG_FILE}
    zypper -n install libstdc++6  | tee -a ${HANA_LOG_FILE}
    zypper -n install nvme-cli | tee -a ${HANA_LOG_FILE}
    
    #SLES 12 installation fails with libnuma
    zypper -n install libnuma-devel | tee -a ${HANA_LOG_FILE}
    
    #Install unrar for media extraction
    zypper -n install unrar  | tee -a ${HANA_LOG_FILE}
    
    # Install GCC and GC++ compilers. GCC includes package libatomic1 that is required for all GCC 7 compiled apps, see OSS note 2593824.
    zypper -n install gcc | tee -a ${HANA_LOG_FILE}
    zypper -n install gcc-c++ | tee -a ${HANA_LOG_FILE}
    
    # Install most current libatomic1 if available
    zypper -n install libatomic1 | tee -a ${HANA_LOG_FILE}
    
    #Remove ulimit package
    zypper remove ulimit > /dev/null
    
    chkconfig boot.kdump  | tee -a ${HANA_LOG_FILE}
    chkconfig kdump off
    echo "net.ipv4.tcp_slow_start_after_idle=0" >> /etc/sysctl.conf
    sysctl -p /etc/sysctl.conf  | tee -a ${HANA_LOG_FILE}

    echo "kernel.shmmni=65536" >> /etc/sysctl.conf
    sysctl -p /etc/sysctl.conf  | tee -a ${HANA_LOG_FILE}

}

install_prereq_sles12sp2() {
    # ------------------------------------------------------------------
    #          Install all the pre-requisites for SAP HANA
    # ------------------------------------------------------------------

    log "## Installing required OS Packages## "
    zypper -n install systemd 2>&1 | tee -a ${HANA_LOG_FILE}
    zypper -n install gtk2 2>&1 | tee -a ${HANA_LOG_FILE}
    zypper -n install java-1_6_0-ibm 2>&1 | tee -a ${HANA_LOG_FILE}
    zypper -n install libicu  | tee -a ${HANA_LOG_FILE}
    zypper -n install mozilla-xulrunner*  | tee -a ${HANA_LOG_FILE}
    zypper -n install ntp  | tee -a ${HANA_LOG_FILE}
    zypper -n install sudo  | tee -a ${HANA_LOG_FILE}
    zypper -n install syslog-ng  | tee -a ${HANA_LOG_FILE}
    zypper -n install tcsh libssh2-1 | tee -a ${HANA_LOG_FILE}
    zypper -n install autoyast2-installation | tee -a ${HANA_LOG_FILE}
    zypper -n install yast2-ncurses  | tee -a ${HANA_LOG_FILE}
    zypper -n install cpupower  | tee -a ${HANA_LOG_FILE}
    zypper -n install libopenssl0_9_8 | tee -a ${HANA_LOG_FILE}
    zypper -n install libgcc_s1 | tee -a ${HANA_LOG_FILE}
    zypper -n install libstdc++6  | tee -a ${HANA_LOG_FILE}
    zypper -n install nvme-cli | tee -a ${HANA_LOG_FILE}
    
    #Install unrar for media extraction
    zypper -n install unrar  | tee -a ${HANA_LOG_FILE}
    
    # Install GCC and GC++ compilers. GCC includes package libatomic1 that is required for all GCC 7 compiled apps, see OSS note 2593824.
    zypper -n install gcc | tee -a ${HANA_LOG_FILE}
    zypper -n install gcc-c++ | tee -a ${HANA_LOG_FILE}
    
    # Install most current libatomic1 if available
    zypper -n install libatomic1 | tee -a ${HANA_LOG_FILE}
    
    #SLES 12 installation fails with libnuma
    zypper -n install libnuma-devel | tee -a ${HANA_LOG_FILE}
    
    #Remove ulimit package
    zypper remove ulimit > /dev/null

    chkconfig boot.kdump  | tee -a ${HANA_LOG_FILE}
    chkconfig kdump off
    echo "net.ipv4.tcp_slow_start_after_idle=0" >> /etc/sysctl.conf
    sysctl -p /etc/sysctl.conf  | tee -a ${HANA_LOG_FILE}
    echo "kernel.shmmni=65536" >> /etc/sysctl.conf
    sysctl -p /etc/sysctl.conf  | tee -a ${HANA_LOG_FILE}

}

install_prereq_sles12sp3() {
    # ------------------------------------------------------------------
    #          Install all the pre-requisites for SAP HANA
    # ------------------------------------------------------------------

    log "## Installing required OS Packages## "
    install_enable_ssm_agent
    zypper -n install systemd 2>&1 | tee -a ${HANA_LOG_FILE}
    zypper -n install gtk2 2>&1 | tee -a ${HANA_LOG_FILE}
    zypper -n install java-1_6_0-ibm 2>&1 | tee -a ${HANA_LOG_FILE}
    zypper -n install libicu  | tee -a ${HANA_LOG_FILE}
    zypper -n install mozilla-xulrunner*  | tee -a ${HANA_LOG_FILE}
    zypper -n install ntp  | tee -a ${HANA_LOG_FILE}
    zypper -n install sudo  | tee -a ${HANA_LOG_FILE}
    zypper -n install syslog-ng  | tee -a ${HANA_LOG_FILE}
    zypper -n install tcsh libssh2-1 | tee -a ${HANA_LOG_FILE}
    zypper -n install autoyast2-installation | tee -a ${HANA_LOG_FILE}
    zypper -n install yast2-ncurses  | tee -a ${HANA_LOG_FILE}
    zypper -n install cpupower  | tee -a ${HANA_LOG_FILE}
    zypper -n install libopenssl0_9_8 | tee -a ${HANA_LOG_FILE}
    zypper -n install libgcc_s1 | tee -a ${HANA_LOG_FILE}
    zypper -n install libstdc++6  | tee -a ${HANA_LOG_FILE}
    zypper -n install nvme-cli | tee -a ${HANA_LOG_FILE}
    
    #Install unrar for media extraction
    zypper -n install unrar  | tee -a ${HANA_LOG_FILE}
    
    # Install GCC and GC++ compilers. GCC includes package libatomic1 that is required for all GCC 7 compiled apps, see OSS note 2593824.
    zypper -n install gcc | tee -a ${HANA_LOG_FILE}
    zypper -n install gcc-c++ | tee -a ${HANA_LOG_FILE}
    
    # Install most current libatomic1 if available
    zypper -n install libatomic1 | tee -a ${HANA_LOG_FILE}
    
    #SLES 12 installation fails with libnuma
    zypper -n install libnuma-devel | tee -a ${HANA_LOG_FILE}
    
    # Install Python Six for compability
    zypper -n install python2-six | tee -a ${HANA_LOG_FILE}
    zypper -n install python3-six | tee -a ${HANA_LOG_FILE}
    
    #Remove ulimit package
    zypper remove ulimit > /dev/null

    chkconfig boot.kdump  | tee -a ${HANA_LOG_FILE}
    chkconfig kdump off
    echo "net.ipv4.tcp_slow_start_after_idle=0" >> /etc/sysctl.conf
    sysctl -p /etc/sysctl.conf  | tee -a ${HANA_LOG_FILE}
    echo "kernel.shmmni=65536" >> /etc/sysctl.conf
    sysctl -p /etc/sysctl.conf  | tee -a ${HANA_LOG_FILE}

}

install_prereq_sles12sp4() {
    # ------------------------------------------------------------------
    #          Install all the pre-requisites for SAP HANA
    # ------------------------------------------------------------------

    log "## Installing required OS Packages## "
    install_enable_ssm_agent
    zypper -n install systemd 2>&1 | tee -a ${HANA_LOG_FILE}
    zypper -n install gtk2 2>&1 | tee -a ${HANA_LOG_FILE}
    zypper -n install java-1_6_0-ibm 2>&1 | tee -a ${HANA_LOG_FILE}
    zypper -n install libicu  | tee -a ${HANA_LOG_FILE}
    zypper -n install mozilla-xulrunner*  | tee -a ${HANA_LOG_FILE}
    zypper -n install ntp  | tee -a ${HANA_LOG_FILE}
    zypper -n install sudo  | tee -a ${HANA_LOG_FILE}
    zypper -n install syslog-ng  | tee -a ${HANA_LOG_FILE}
    zypper -n install tcsh libssh2-1 | tee -a ${HANA_LOG_FILE}
    zypper -n install autoyast2-installation | tee -a ${HANA_LOG_FILE}
    zypper -n install yast2-ncurses  | tee -a ${HANA_LOG_FILE}
    zypper -n install cpupower  | tee -a ${HANA_LOG_FILE}
    zypper -n install libopenssl0_9_8 | tee -a ${HANA_LOG_FILE}
    zypper -n install libgcc_s1 | tee -a ${HANA_LOG_FILE}
    zypper -n install libstdc++6  | tee -a ${HANA_LOG_FILE}
    zypper -n install nvme-cli | tee -a ${HANA_LOG_FILE}
    zypper -n install cloud-netconfig-ec2 | tee -a ${HANA_LOG_FILE}
    zypper -n install sysstat | tee -a ${HANA_LOG_FILE}
    zypper -n install uuidd | tee -a ${HANA_LOG_FILE}
    zypper -n install sapconf | tee -a ${HANA_LOG_FILE}
    zypper -n install insserv-compat | tee -a ${HANA_LOG_FILE}
    zypper -n install libltdl7 | tee -a ${HANA_LOG_FILE}
    zypper -n install libssh2-1 | tee -a ${HANA_LOG_FILE}
    
    # As of SLES12 SP4, /sbin/insserv has to be installed for HANA install
    zypper -n install insserv-compat | tee -a ${HANA_LOG_FILE}
    
    #Install unrar for media extraction
    zypper -n install unrar  | tee -a ${HANA_LOG_FILE}
    
    # Install GCC and GC++ compilers. GCC includes package libatomic1 that is required for all GCC 7 compiled apps, see OSS note 2593824.
    zypper -n install gcc | tee -a ${HANA_LOG_FILE}
    zypper -n install gcc-c++ | tee -a ${HANA_LOG_FILE}
    
    # Install most current libatomic1 if available
    zypper -n install libatomic1 | tee -a ${HANA_LOG_FILE}
    
    #SLES 12 installation fails with libnuma
    zypper -n install libnuma-devel | tee -a ${HANA_LOG_FILE}
    
    # Install Python Six for compability
    zypper -n install python2-six | tee -a ${HANA_LOG_FILE} 
    zypper -n install python3-six | tee -a ${HANA_LOG_FILE}
    
    #Remove ulimit package
    zypper remove ulimit > /dev/null

    chkconfig boot.kdump  | tee -a ${HANA_LOG_FILE}
    chkconfig kdump off
    
    echo '#### Added by AWS QuickStart' >> /etc/sysctl.conf
    echo "net.ipv4.tcp_slow_start_after_idle=0" >> /etc/sysctl.conf
    echo "kernel.shmmni=65536" >> /etc/sysctl.conf
    echo "net.core.somaxconn=4096" >> /etc/sysctl.conf
    echo "net.ipv4.tcp_max_syn_backlog=8192" >> /etc/sysctl.conf
    sysctl -p /etc/sysctl.conf  | tee -a ${HANA_LOG_FILE}
    
}

install_prereq_sles12sp5() {
    # ------------------------------------------------------------------
    #          Install all the pre-requisites for SAP HANA
    # ------------------------------------------------------------------

    log "## Installing required OS Packages## "
    install_enable_ssm_agent
    zypper -n install systemd 2>&1 | tee -a ${HANA_LOG_FILE}
    zypper -n install gtk2 2>&1 | tee -a ${HANA_LOG_FILE}
    zypper -n install java-1_6_0-ibm 2>&1 | tee -a ${HANA_LOG_FILE}
    zypper -n install libicu  | tee -a ${HANA_LOG_FILE}
    zypper -n install mozilla-xulrunner*  | tee -a ${HANA_LOG_FILE}
    zypper -n install ntp  | tee -a ${HANA_LOG_FILE}
    zypper -n install sudo  | tee -a ${HANA_LOG_FILE}
    zypper -n install syslog-ng  | tee -a ${HANA_LOG_FILE}
    zypper -n install tcsh libssh2-1 | tee -a ${HANA_LOG_FILE}
    zypper -n install autoyast2-installation | tee -a ${HANA_LOG_FILE}
    zypper -n install yast2-ncurses  | tee -a ${HANA_LOG_FILE}
    zypper -n install cpupower  | tee -a ${HANA_LOG_FILE}
    zypper -n install libopenssl0_9_8 | tee -a ${HANA_LOG_FILE}
    zypper -n install libgcc_s1 | tee -a ${HANA_LOG_FILE}
    zypper -n install libstdc++6  | tee -a ${HANA_LOG_FILE}
    zypper -n install nvme-cli | tee -a ${HANA_LOG_FILE}
    zypper -n install cloud-netconfig-ec2 | tee -a ${HANA_LOG_FILE}
    zypper -n install sysstat | tee -a ${HANA_LOG_FILE}
    zypper -n install uuidd | tee -a ${HANA_LOG_FILE}
    zypper -n install sapconf | tee -a ${HANA_LOG_FILE}
    zypper -n install insserv-compat | tee -a ${HANA_LOG_FILE}
    zypper -n install libltdl7 | tee -a ${HANA_LOG_FILE}
    zypper -n install libssh2-1 | tee -a ${HANA_LOG_FILE}
    
    # As of SLES12 SP4, /sbin/insserv has to be installed for HANA install program or it'll fai
    zypper -n install insserv-compat | tee -a ${HANA_LOG_FILE}
    
    #Install unrar for media extraction
    zypper -n install unrar  | tee -a ${HANA_LOG_FILE}
    
    # Install GCC and GC++ compilers. GCC includes package libatomic1 that is required for all GCC 7 compiled apps, see OSS note 2593824.
    zypper -n install gcc | tee -a ${HANA_LOG_FILE}
    zypper -n install gcc-c++ | tee -a ${HANA_LOG_FILE}
    
    # Install most current libatomic1 if available
    zypper -n install libatomic1 | tee -a ${HANA_LOG_FILE}
    
    #SLES 12 installation fails with libnuma
    zypper -n install libnuma-devel | tee -a ${HANA_LOG_FILE}
    
    #Remove ulimit package
    zypper remove ulimit > /dev/null

    chkconfig boot.kdump  | tee -a ${HANA_LOG_FILE}
    chkconfig kdump off
    
    echo '#### Added by AWS QuickStart' >> /etc/sysctl.conf
    echo "net.ipv4.tcp_slow_start_after_idle=0" >> /etc/sysctl.conf
    echo "kernel.shmmni=65536" >> /etc/sysctl.conf
    echo "net.core.somaxconn=4096" >> /etc/sysctl.conf
    echo "net.ipv4.tcp_max_syn_backlog=8192" >> /etc/sysctl.conf
    sysctl -p /etc/sysctl.conf  | tee -a ${HANA_LOG_FILE}

}

install_prereq_sles15() {
    # ------------------------------------------------------------------
    #          Install all the pre-requisites for SAP HANA
    # ------------------------------------------------------------------

    log "## Installing required OS Packages## "
    install_enable_ssm_agent
    zypper -n install systemd 2>&1 | tee -a ${HANA_LOG_FILE}
    zypper -n install gtk2 2>&1 | tee -a ${HANA_LOG_FILE}
    zypper -n install java-1_6_0-ibm 2>&1 | tee -a ${HANA_LOG_FILE}
    zypper -n install libicu  | tee -a ${HANA_LOG_FILE}
    zypper -n install mozilla-xulrunner*  | tee -a ${HANA_LOG_FILE}
    zypper -n install sudo  | tee -a ${HANA_LOG_FILE}
    zypper -n install syslog-ng  | tee -a ${HANA_LOG_FILE}
    zypper -n install tcsh libssh2-1 | tee -a ${HANA_LOG_FILE}
    zypper -n install autoyast2-installation | tee -a ${HANA_LOG_FILE}
    zypper -n install yast2-ncurses  | tee -a ${HANA_LOG_FILE}
    zypper -n install cpupower  | tee -a ${HANA_LOG_FILE}
    zypper -n install libopenssl0_9_8 | tee -a ${HANA_LOG_FILE}
    zypper -n install libgcc_s1 | tee -a ${HANA_LOG_FILE}
    zypper -n install libstdc++6  | tee -a ${HANA_LOG_FILE}
    zypper -n install nvme-cli | tee -a ${HANA_LOG_FILE}
    zypper -n install cloud-netconfig-ec2 | tee -a ${HANA_LOG_FILE}
    zypper -n install sysstat | tee -a ${HANA_LOG_FILE}
    zypper -n install uuidd | tee -a ${HANA_LOG_FILE}
    zypper -n install sapconf | tee -a ${HANA_LOG_FILE}
    zypper -n install insserv-compat | tee -a ${HANA_LOG_FILE}
    zypper -n install libltdl7 | tee -a ${HANA_LOG_FILE}
    zypper -n install libssh2-1 | tee -a ${HANA_LOG_FILE}
    
    # See OSS note 2788495
    zypper -n install libopenssl1_0_0 | tee -a ${HANA_LOG_FILE}
#    zypper -n install libssh2-1


    # As of SLES12 SP4, /sbin/insserv has to be installed for HANA install program or it'll fail
    zypper -n install insserv-compat | tee -a ${HANA_LOG_FILE}

    # unrar has been replaced by unar in SLES 15, and is implemented as 
    # a symbolic link to unar "unrar --> /usr/bin/unar.                 
    zypper -n install unrar_wrapper | tee -a ${HANA_LOG_FILE}

    # Chrony has replaced NTP for time server synchonization as of SLES 15, and
    # it's installed by default.                                                
    # Below command is only to update chrony to the most current version.       
    zypper -n install chrony | tee -a ${HANA_LOG_FILE}

    # --------------------------------------------------------------------- 
    # in SLES 15, command "ifconfig" has been replaced by "ip", and moved   
    # from package net-tools to net-tools-deprecated. "ip" is installed by  
    # default. Once "ifconfig" is completely removed we'll need to replace  
    # "ifconfig" by "ip" in all codes for SLES15.                           
    # --------------------------------------------------------------------- 
    zypper -n install net-tools-deprecated | tee -a ${HANA_LOG_FILE}

    # SLES 12 installation fails with libnuma
    zypper -n install libnuma-devel | tee -a ${HANA_LOG_FILE}
    
    # Install GCC and GC++ compilers. GCC includes package libatomic1 that is required for all GCC 7 compiled apps, see OSS note 2593824.
    zypper -n install gcc | tee -a ${HANA_LOG_FILE}
    zypper -n install gcc-c++ | tee -a ${HANA_LOG_FILE}
    
    # Install most current libatomic1 if available
    zypper -n install libatomic1 | tee -a ${HANA_LOG_FILE}
    
    # Install Python Six for compability
    zypper -n install python2-six | tee -a ${HANA_LOG_FILE}
    zypper -n install python3-six | tee -a ${HANA_LOG_FILE}
    
    #Remove ulimit package
    zypper remove ulimit > /dev/null

    echo '#### Added by AWS QuickStart' >> /etc/sysctl.conf
    echo "net.ipv4.tcp_slow_start_after_idle=0" >> /etc/sysctl.conf
    echo "kernel.shmmni=65536" >> /etc/sysctl.conf
    echo "net.core.somaxconn=4096" >> /etc/sysctl.conf
    echo "net.ipv4.tcp_max_syn_backlog=8192" >> /etc/sysctl.conf
    sysctl -p /etc/sysctl.conf  | tee -a ${HANA_LOG_FILE}

}

install_prereq_sles15sp1() {
    # ------------------------------------------------------------------
    #          Install all the pre-requisites for SAP HANA
    # ------------------------------------------------------------------

    log "## Installing required OS Packages## "
    install_enable_ssm_agent
    zypper -n install systemd 2>&1 | tee -a ${HANA_LOG_FILE}
    zypper -n install gtk2 2>&1 | tee -a ${HANA_LOG_FILE}
    zypper -n install java-1_6_0-ibm 2>&1 | tee -a ${HANA_LOG_FILE}
    zypper -n install libicu  | tee -a ${HANA_LOG_FILE}
    zypper -n install mozilla-xulrunner*  | tee -a ${HANA_LOG_FILE}
    zypper -n install sudo  | tee -a ${HANA_LOG_FILE}
    zypper -n install syslog-ng  | tee -a ${HANA_LOG_FILE}
    zypper -n install tcsh libssh2-1 | tee -a ${HANA_LOG_FILE}
    zypper -n install autoyast2-installation | tee -a ${HANA_LOG_FILE}
    zypper -n install yast2-ncurses  | tee -a ${HANA_LOG_FILE}
    zypper -n install cpupower  | tee -a ${HANA_LOG_FILE}
    zypper -n install libopenssl0_9_8 | tee -a ${HANA_LOG_FILE}
    zypper -n install libgcc_s1 | tee -a ${HANA_LOG_FILE}
    zypper -n install libstdc++6  | tee -a ${HANA_LOG_FILE}
    zypper -n install nvme-cli | tee -a ${HANA_LOG_FILE}
    zypper -n install cloud-netconfig-ec2 | tee -a ${HANA_LOG_FILE}
    zypper -n install sysstat | tee -a ${HANA_LOG_FILE}
    zypper -n install uuidd | tee -a ${HANA_LOG_FILE}
    zypper -n install sapconf | tee -a ${HANA_LOG_FILE}
    zypper -n install insserv-compat | tee -a ${HANA_LOG_FILE}
    zypper -n install libltdl7 | tee -a ${HANA_LOG_FILE}
    zypper -n install libssh2-1 | tee -a ${HANA_LOG_FILE}
    
    # See OSS note 2788495
    zypper -n install libopenssl1_0_0 | tee -a ${HANA_LOG_FILE}
#    zypper -n install libssh2-1


    # As of SLES12 SP4, /sbin/insserv has to be installed for HANA install program or it'll fail
    zypper -n install insserv-compat | tee -a ${HANA_LOG_FILE}


    # unrar has been replaced by unar in SLES 15, and is implemented as 
    # a symbolic link to unar "unrar --> /usr/bin/unar.                 
    zypper -n install unrar_wrapper | tee -a ${HANA_LOG_FILE}

    # -------------------------------------------------------------------------
    # Chrony has replaced NTP for time server synchonization as of SLES 15, and
    # it's installed by default.                                               
    # Below command is only to update chrony to the most current version.       
    # -------------------------------------------------------------------------
    zypper -n install chrony | tee -a ${HANA_LOG_FILE}

    # ---------------------------------------------------------------------
    # in SLES 15, command "ifconfig" has been replaced by "ip", and moved   
    # from package net-tools to net-tools-deprecated. "ip" is installed by  
    # default. Once "ifconfig" is completely removed we'll need to replace  
    # "ifconfig" by "ip" in all codes for SLES15.                           
    # --------------------------------------------------------------------- 
    zypper -n install net-tools-deprecated | tee -a ${HANA_LOG_FILE}

    #SLES 12 installation fails with libnuma
    zypper -n install libnuma-devel | tee -a ${HANA_LOG_FILE}
    
    # Install GCC and GC++ compilers. GCC includes package libatomic1 that is required for all GCC 7 compiled apps, see OSS note 2593824.
    zypper -n install gcc | tee -a ${HANA_LOG_FILE}
    zypper -n install gcc-c++ | tee -a ${HANA_LOG_FILE}
    
    # Install most current libatomic1 if available
    zypper -n install libatomic1 | tee -a ${HANA_LOG_FILE}
    
    # Remove ulimit package
    zypper remove ulimit > /dev/null

    echo '#### Added by AWS QuickStart' >> /etc/sysctl.conf
    echo "net.ipv4.tcp_slow_start_after_idle=0" >> /etc/sysctl.conf
    echo "kernel.shmmni=65536" >> /etc/sysctl.conf
    echo "net.core.somaxconn=4096" >> /etc/sysctl.conf
    echo "net.ipv4.tcp_max_syn_backlog=8192" >> /etc/sysctl.conf
    sysctl -p /etc/sysctl.conf  | tee -a ${HANA_LOG_FILE}

}

install_prereq_sles15sp2() {
    # ------------------------------------------------------------------
    #          Install all the pre-requisites for SAP HANA
    # ------------------------------------------------------------------

    log "## Installing required OS Packages## "
    install_enable_ssm_agent
    zypper -n update kernel-default 2>&1 | tee -a ${HANA_LOG_FILE}
    zypper -n install systemd 2>&1 | tee -a ${HANA_LOG_FILE}
    zypper -n install gtk2 2>&1 | tee -a ${HANA_LOG_FILE}
    zypper -n install java-1_6_0-ibm 2>&1 | tee -a ${HANA_LOG_FILE}
    zypper -n install libicu  | tee -a ${HANA_LOG_FILE}
    zypper -n install mozilla-xulrunner*  | tee -a ${HANA_LOG_FILE}
    zypper -n install sudo  | tee -a ${HANA_LOG_FILE}
    zypper -n install syslog-ng  | tee -a ${HANA_LOG_FILE}
    zypper -n install tcsh libssh2-1 | tee -a ${HANA_LOG_FILE}
    zypper -n install autoyast2-installation | tee -a ${HANA_LOG_FILE}
    zypper -n install yast2-ncurses  | tee -a ${HANA_LOG_FILE}
    zypper -n install cpupower  | tee -a ${HANA_LOG_FILE}
    zypper -n install libopenssl0_9_8 | tee -a ${HANA_LOG_FILE}
    zypper -n install libgcc_s1 | tee -a ${HANA_LOG_FILE}
    zypper -n install libstdc++6  | tee -a ${HANA_LOG_FILE}
    zypper -n install nvme-cli | tee -a ${HANA_LOG_FILE}
    zypper -n install cloud-netconfig-ec2 | tee -a ${HANA_LOG_FILE}
    zypper -n install sysstat | tee -a ${HANA_LOG_FILE}
    zypper -n install uuidd | tee -a ${HANA_LOG_FILE}
    zypper -n install sapconf | tee -a ${HANA_LOG_FILE}
    zypper -n install insserv-compat | tee -a ${HANA_LOG_FILE}
    zypper -n install libltdl7 | tee -a ${HANA_LOG_FILE}
    zypper -n install libssh2-1 | tee -a ${HANA_LOG_FILE}
    
    # See OSS note 2788495
    zypper -n install libopenssl1_0_0 | tee -a ${HANA_LOG_FILE}
#    zypper -n install libssh2-1


    # As of SLES12 SP4, /sbin/insserv has to be installed for HANA install program or it'll fail
    zypper -n install insserv-compat | tee -a ${HANA_LOG_FILE}


    # unrar has been replaced by unar in SLES 15, and is implemented as 
    # a symbolic link to unar "unrar --> /usr/bin/unar.                 
    zypper -n install unrar_wrapper | tee -a ${HANA_LOG_FILE}

    # -------------------------------------------------------------------------
    # Chrony has replaced NTP for time server synchonization as of SLES 15, and
    # it's installed by default.                                               
    # Below command is only to update chrony to the most current version.       
    # -------------------------------------------------------------------------
    zypper -n install chrony | tee -a ${HANA_LOG_FILE}

    # ---------------------------------------------------------------------
    # in SLES 15, command "ifconfig" has been replaced by "ip", and moved   
    # from package net-tools to net-tools-deprecated. "ip" is installed by  
    # default. Once "ifconfig" is completely removed we'll need to replace  
    # "ifconfig" by "ip" in all codes for SLES15.                           
    # --------------------------------------------------------------------- 
    zypper -n install net-tools-deprecated | tee -a ${HANA_LOG_FILE}

    #SLES 12 installation fails with libnuma
    zypper -n install libnuma-devel | tee -a ${HANA_LOG_FILE}
    
    # Install GCC and GC++ compilers. GCC includes package libatomic1 that is required for all GCC 7 compiled apps, see OSS note 2593824.
    zypper -n install gcc | tee -a ${HANA_LOG_FILE}
    zypper -n install gcc-c++ | tee -a ${HANA_LOG_FILE}
    
    # Install most current libatomic1 if available
    zypper -n install libatomic1 | tee -a ${HANA_LOG_FILE}
    
    # Remove ulimit package
    zypper remove ulimit > /dev/null

    echo '#### Added by AWS QuickStart' >> /etc/sysctl.conf
    echo "net.ipv4.tcp_slow_start_after_idle=0" >> /etc/sysctl.conf
    echo "kernel.shmmni=65536" >> /etc/sysctl.conf
    echo "net.core.somaxconn=4096" >> /etc/sysctl.conf
    echo "net.ipv4.tcp_max_syn_backlog=8192" >> /etc/sysctl.conf
    sysctl -p /etc/sysctl.conf  | tee -a ${HANA_LOG_FILE}

}

install_prereq_sles15sp3() {
    # ------------------------------------------------------------------
    #          Install all the pre-requisites for SAP HANA
    # ------------------------------------------------------------------

    log "## Installing required OS Packages## "
    install_enable_ssm_agent
    zypper -n update kernel-default 2>&1 | tee -a ${HANA_LOG_FILE}
    zypper -n install systemd 2>&1 | tee -a ${HANA_LOG_FILE}
    zypper -n install gtk2 2>&1 | tee -a ${HANA_LOG_FILE}
    zypper -n install java-1_6_0-ibm 2>&1 | tee -a ${HANA_LOG_FILE}
    zypper -n install libicu  | tee -a ${HANA_LOG_FILE}
    zypper -n install mozilla-xulrunner*  | tee -a ${HANA_LOG_FILE}
    zypper -n install sudo  | tee -a ${HANA_LOG_FILE}
    zypper -n install syslog-ng  | tee -a ${HANA_LOG_FILE}
    zypper -n install tcsh libssh2-1 | tee -a ${HANA_LOG_FILE}
    zypper -n install autoyast2-installation | tee -a ${HANA_LOG_FILE}
    zypper -n install yast2-ncurses  | tee -a ${HANA_LOG_FILE}
    zypper -n install cpupower  | tee -a ${HANA_LOG_FILE}
    zypper -n install libopenssl0_9_8 | tee -a ${HANA_LOG_FILE}
    zypper -n install libgcc_s1 | tee -a ${HANA_LOG_FILE}
    zypper -n install libstdc++6  | tee -a ${HANA_LOG_FILE}
    zypper -n install nvme-cli | tee -a ${HANA_LOG_FILE}
    zypper -n install cloud-netconfig-ec2 | tee -a ${HANA_LOG_FILE}
    zypper -n install sysstat | tee -a ${HANA_LOG_FILE}
    zypper -n install uuidd | tee -a ${HANA_LOG_FILE}
    zypper -n install sapconf | tee -a ${HANA_LOG_FILE}
    zypper -n install insserv-compat | tee -a ${HANA_LOG_FILE}
    zypper -n install libltdl7 | tee -a ${HANA_LOG_FILE}
    zypper -n install libssh2-1 | tee -a ${HANA_LOG_FILE}
  
    # See OSS note 2788495
    zypper -n install libopenssl1_0_0 | tee -a ${HANA_LOG_FILE}
#    zypper -n install libssh2-1


    # As of SLES12 SP4, /sbin/insserv has to be installed for HANA install program or it'll fail
    zypper -n install insserv-compat | tee -a ${HANA_LOG_FILE}


    # unrar has been replaced by unar in SLES 15, and is implemented as 
    # a symbolic link to unar "unrar --> /usr/bin/unar.                 
    zypper -n install unrar_wrapper | tee -a ${HANA_LOG_FILE}

    # -------------------------------------------------------------------------
    # Chrony has replaced NTP for time server synchonization as of SLES 15, and
    # it's installed by default.                                               
    # Below command is only to update chrony to the most current version.       
    # -------------------------------------------------------------------------
    zypper -n install chrony | tee -a ${HANA_LOG_FILE}

    # ---------------------------------------------------------------------
    # in SLES 15, command "ifconfig" has been replaced by "ip", and moved   
    # from package net-tools to net-tools-deprecated. "ip" is installed by  
    # default. Once "ifconfig" is completely removed we'll need to replace  
    # "ifconfig" by "ip" in all codes for SLES15.                           
    # --------------------------------------------------------------------- 
    zypper -n install net-tools-deprecated | tee -a ${HANA_LOG_FILE}

    #SLES 12 installation fails with libnuma
    zypper -n install libnuma-devel | tee -a ${HANA_LOG_FILE}
    
    # Install GCC and GC++ compilers. GCC includes package libatomic1 that is required for all GCC 7 compiled apps, see OSS note 2593824.
    zypper -n install gcc | tee -a ${HANA_LOG_FILE}
    zypper -n install gcc-c++ | tee -a ${HANA_LOG_FILE}
    
    # Install most current libatomic1 if available
    zypper -n install libatomic1 | tee -a ${HANA_LOG_FILE}
    
    # Remove ulimit package
    zypper remove ulimit > /dev/null

    echo '#### Added by AWS QuickStart' >> /etc/sysctl.conf
    echo "net.ipv4.tcp_slow_start_after_idle=0" >> /etc/sysctl.conf
    echo "kernel.shmmni=65536" >> /etc/sysctl.conf
    echo "net.core.somaxconn=4096" >> /etc/sysctl.conf
    echo "net.ipv4.tcp_max_syn_backlog=8192" >> /etc/sysctl.conf
    sysctl -p /etc/sysctl.conf  | tee -a ${HANA_LOG_FILE}

}

install_prereq_sles12sp1sap() {
    # ------------------------------------------------------------------
    #          Install all the pre-requisites for SAP HANA
    # ------------------------------------------------------------------

    log "`date` - Install / Update OS Packages## "

    zypper -n install tuned  | tee -a ${HANA_LOG_FILE}
    zypper -n install saptune  | tee -a ${HANA_LOG_FILE}
    zypper -n install cpupower  | tee -a ${HANA_LOG_FILE}
    zypper -n install amazon-ssm-agent | tee -a ${HANA_LOG_FILE}
    zypper -n install nvme-cli | tee -a ${HANA_LOG_FILE}
    systemctl start amazon-ssm-agent | tee -a ${HANA_LOG_FILE}
    
    #Install unrar for media extraction
    zypper -n install unrar  | tee -a ${HANA_LOG_FILE}
    
    # Install GCC and GC++ compilers. GCC includes package libatomic1 that is required for all GCC 7 compiled apps, see OSS note 2593824.
    zypper -n install gcc | tee -a ${HANA_LOG_FILE}
    zypper -n install gcc-c++ | tee -a ${HANA_LOG_FILE}
    
    # Install most current libatomic1 if available
    zypper -n install libatomic1 | tee -a ${HANA_LOG_FILE}
    
    # Apply all Recommended HANA settings with SAPTUNE
    log "`date` - Start saptune daemon"
    saptune daemon start | tee -a ${HANA_LOG_FILE}
    log "`date` - Apply saptune HANA profile"
    saptune solution apply HANA | tee -a ${HANA_LOG_FILE}
}

install_prereq_sles12sp2sap() {
  # ------------------------------------------------------------------
  #          Install all the pre-requisites for SAP HANA
  # ------------------------------------------------------------------

  log "`date` - Install / Update OS Packages## "
  zypper -n install systemd 2>&1 | tee -a ${HANA_LOG_FILE}
  zypper -n install tuned  | tee -a ${HANA_LOG_FILE}
  zypper -n install saptune  | tee -a ${HANA_LOG_FILE}
  zypper -n install cpupower  | tee -a ${HANA_LOG_FILE}
  zypper -n install amazon-ssm-agent | tee -a ${HANA_LOG_FILE}
  zypper -n install nvme-cli | tee -a ${HANA_LOG_FILE}
  systemctl start amazon-ssm-agent | tee -a ${HANA_LOG_FILE}
  
  #Install unrar for media extraction
  zypper -n install unrar  | tee -a ${HANA_LOG_FILE}
  
  # Install GCC and GC++ compilers. GCC includes package libatomic1 that is required for all GCC 7 compiled apps, see OSS note 2593824.
  zypper -n install gcc | tee -a ${HANA_LOG_FILE}
  zypper -n install gcc-c++ | tee -a ${HANA_LOG_FILE}
  
  # Install most current libatomic1 if available
  zypper -n install libatomic1 | tee -a ${HANA_LOG_FILE}
  
  # Apply all Recommended HANA settings with SAPTUNE
  log "`date` - Start saptune daemon"
  saptune daemon start | tee -a ${HANA_LOG_FILE}
  log "`date` - Apply saptune HANA profile"
  mkdir /etc/tuned/saptune # OSS Note 2205917
  cp /usr/lib/tuned/saptune/tuned.conf /etc/tuned/saptune/tuned.conf # OSS Note 2205917
  sed -i "/\[cpu\]/ a force_latency=70" /etc/tuned/saptune/tuned.conf # OSS Note 2205917
  sed -i "s/script.sh/\/usr\/lib\/tuned\/saptune\/script.sh/" /etc/tuned/saptune/tuned.conf # OSS Note 2205917
  saptune solution apply HANA | tee -a ${HANA_LOG_FILE}

}

install_prereq_sles12sp3sap() {
  # ------------------------------------------------------------------
  #          Install all the pre-requisites for SAP HANA
  # ------------------------------------------------------------------

  log "`date` - Install / Update OS Packages## "
  install_enable_ssm_agent
  zypper -n install systemd 2>&1 | tee -a ${HANA_LOG_FILE}
  zypper -n install tuned  | tee -a ${HANA_LOG_FILE}
  zypper -n install saptune  | tee -a ${HANA_LOG_FILE}
  zypper -n install cpupower  | tee -a ${HANA_LOG_FILE}
  zypper -n install nvme-cli | tee -a ${HANA_LOG_FILE}
  zypper -n install libopenssl0_9_8 | tee -a ${HANA_LOG_FILE}
  zypper -n install libgcc_s1 | tee -a ${HANA_LOG_FILE}
  zypper -n install libstdc++6  | tee -a ${HANA_LOG_FILE}
  
  #Install unrar for media extraction
  zypper -n install unrar  | tee -a ${HANA_LOG_FILE}
  
  # Install GCC and GC++ compilers. GCC includes package libatomic1 that is required for all GCC 7 compiled apps, see OSS note 2593824.
  zypper -n install gcc | tee -a ${HANA_LOG_FILE}
  zypper -n install gcc-c++ | tee -a ${HANA_LOG_FILE}
  
  # Install most current libatomic1 if available
  zypper -n install libatomic1 | tee -a ${HANA_LOG_FILE}
  
  # Install Python Six for compability
  zypper -n install python2-six | tee -a ${HANA_LOG_FILE} 
  zypper -n install python3-six | tee -a ${HANA_LOG_FILE}
  
  # Apply all Recommended HANA settings with SAPTUNE
  install_and_run_saptune
}

install_prereq_sles12sp4sap() {
  # ------------------------------------------------------------------
  #          Install all the pre-requisites for SAP HANA
  # ------------------------------------------------------------------

  log "`date` - Install / Update OS Packages## "
  install_enable_ssm_agent
  zypper -n install systemd 2>&1 | tee -a ${HANA_LOG_FILE}
  zypper -n install tuned  | tee -a ${HANA_LOG_FILE}
  zypper -n install saptune  | tee -a ${HANA_LOG_FILE}
  zypper -n install cpupower  | tee -a ${HANA_LOG_FILE}
  zypper -n install nvme-cli | tee -a ${HANA_LOG_FILE}
  zypper -n install libopenssl0_9_8 | tee -a ${HANA_LOG_FILE}
  zypper -n install libgcc_s1 | tee -a ${HANA_LOG_FILE}
  zypper -n install libstdc++6  | tee -a ${HANA_LOG_FILE}
  zypper -n install cloud-netconfig-ec2 | tee -a ${HANA_LOG_FILE}
  zypper -n install supportutils-plugin-ha-sap | tee -a ${HANA_LOG_FILE}
  zypper -n install insserv-compat | tee -a ${HANA_LOG_FILE}
  zypper -n install libltdl7 | tee -a ${HANA_LOG_FILE}
  zypper -n install libssh2-1 | tee -a ${HANA_LOG_FILE}
  
  #Install unrar for media extraction
  zypper -n install unrar  | tee -a ${HANA_LOG_FILE}
  
  # Install GCC and GC++ compilers. GCC includes package libatomic1 that is required for all GCC 7 compiled apps, see OSS note 2593824.
  zypper -n install gcc | tee -a ${HANA_LOG_FILE}
  zypper -n install gcc-c++ | tee -a ${HANA_LOG_FILE}
  
  # Install most current libatomic1 if available
  zypper -n install libatomic1 | tee -a ${HANA_LOG_FILE}
  
  # Install Python Six for compability
  zypper -n install python2-six | tee -a ${HANA_LOG_FILE} 
  zypper -n install python3-six | tee -a ${HANA_LOG_FILE}
  
  # Apply all Recommended HANA settings with SAPTUNE
  install_and_run_saptune

}

install_prereq_sles12sp5sap() {
  # ------------------------------------------------------------------
  #          Install all the pre-requisites for SAP HANA
  # ------------------------------------------------------------------

  log "`date` - Install / Update OS Packages## "
  install_enable_ssm_agent
  zypper -n install systemd 2>&1 | tee -a ${HANA_LOG_FILE}
  zypper -n install tuned  | tee -a ${HANA_LOG_FILE}
  zypper -n install saptune  | tee -a ${HANA_LOG_FILE}
  zypper -n install cpupower  | tee -a ${HANA_LOG_FILE}
  zypper -n install nvme-cli | tee -a ${HANA_LOG_FILE}
  zypper -n install libopenssl0_9_8 | tee -a ${HANA_LOG_FILE}
  zypper -n install libgcc_s1 | tee -a ${HANA_LOG_FILE}
  zypper -n install libstdc++6  | tee -a ${HANA_LOG_FILE}
  zypper -n install cloud-netconfig-ec2 | tee -a ${HANA_LOG_FILE}
  zypper -n install supportutils-plugin-ha-sap | tee -a ${HANA_LOG_FILE}
  zypper -n install insserv-compat | tee -a ${HANA_LOG_FILE}
  zypper -n install libltdl7 | tee -a ${HANA_LOG_FILE}
  zypper -n install libssh2-1 | tee -a ${HANA_LOG_FILE}
  
  #Install unrar for media extraction
  zypper -n install unrar  | tee -a ${HANA_LOG_FILE}
  
  # Install GCC and GC++ compilers. GCC includes package libatomic1 that is required for all GCC 7 compiled apps, see OSS note 2593824.
  zypper -n install gcc | tee -a ${HANA_LOG_FILE}
  zypper -n install gcc-c++ | tee -a ${HANA_LOG_FILE}
  
  # Install most current libatomic1 if available
  zypper -n install libatomic1 | tee -a ${HANA_LOG_FILE}
  
  # Apply all Recommended HANA settings with SAPTUNE
  install_and_run_saptune
}

install_prereq_sles15sap() {
  # ------------------------------------------------------------------
  #          Install all SLES15ForSAP pre-requisites for SAP HANA
  # ------------------------------------------------------------------

  log "`date` - Install / Update OS Packages## "
  install_enable_ssm_agent
  zypper -n install systemd 2>&1 | tee -a ${HANA_LOG_FILE}
  zypper -n install tuned  | tee -a ${HANA_LOG_FILE}
  zypper -n install saptune  | tee -a ${HANA_LOG_FILE}
  zypper -n install cpupower  | tee -a ${HANA_LOG_FILE}
  zypper -n install nvme-cli | tee -a ${HANA_LOG_FILE}
  zypper -n install cloud-netconfig-ec2 | tee -a ${HANA_LOG_FILE}
  zypper -n install supportutils-plugin-ha-sap | tee -a ${HANA_LOG_FILE}
  zypper -n install insserv-compat | tee -a ${HANA_LOG_FILE}
  zypper -n install libltdl7 | tee -a ${HANA_LOG_FILE}
  zypper -n install libssh2-1 | tee -a ${HANA_LOG_FILE}
  
  # Install GCC and GC++ compilers. GCC includes package libatomic1 that is required for all GCC 7 compiled apps, see OSS note 2593824.
  zypper -n install gcc | tee -a ${HANA_LOG_FILE}
  zypper -n install gcc-c++ | tee -a ${HANA_LOG_FILE}
  zypper -n install libgcc_s1 | tee -a ${HANA_LOG_FILE}
  zypper -n install libstdc++6  | tee -a ${HANA_LOG_FILE}
  
  # Install most current libatomic1 if available
  zypper -n install libatomic1 | tee -a ${HANA_LOG_FILE}
  
  # Install Python Six for compability
  zypper -n install python2-six | tee -a ${HANA_LOG_FILE}
  zypper -n install python3-six | tee -a ${HANA_LOG_FILE}
  
  # unrar has been replaced by unar in SLES 15, and is implemented as 
  # a symbolic link to unar "unrar --> /usr/bin/unar.                 
  zypper -n install unrar_wrapper | tee -a ${HANA_LOG_FILE}

  # Chrony has replaced NTP for time server synchonization as of SLES 15, and 
  # it's installed by default.                                                
  # Below command is only to update chrony to the most current version. 
  zypper -n install chrony | tee -a ${HANA_LOG_FILE}

  # In SLES 15, command "ifconfig" has been replaced by "ip", and moved   
  # from package net-tools to net-tools-deprecated. "ip" is installed by  
  # default. Once "ifconfig" is completely removed we'll need to replace  
  # "ifconfig" by "ip" in all codes for SLES15.                           
  zypper -n install net-tools-deprecated | tee -a ${HANA_LOG_FILE}

  # See SLES15 for SAP install Guides 
  zypper -n install patterns-sles-sap_server | tee -a ${HANA_LOG_FILE}

  # See OSS note 2788495
  zypper -n install libopenssl1_0_0 | tee -a ${HANA_LOG_FILE}

  # Apply all Recommended HANA settings with SAPTUNE
  install_and_run_saptune

}

install_prereq_sles15sp1sap() {
  # ------------------------------------------------------------------
  #          Install all SLES15ForSAP pre-requisites for SAP HANA
  # ------------------------------------------------------------------

  log "`date` - Install / Update OS Packages## "
  install_enable_ssm_agent
  zypper -n install systemd 2>&1 | tee -a ${HANA_LOG_FILE}
  zypper -n install tuned  | tee -a ${HANA_LOG_FILE}
  zypper -n install saptune  | tee -a ${HANA_LOG_FILE}
  zypper -n install cpupower  | tee -a ${HANA_LOG_FILE}
  zypper -n install nvme-cli | tee -a ${HANA_LOG_FILE}
  zypper -n install cloud-netconfig-ec2 | tee -a ${HANA_LOG_FILE}
  zypper -n install supportutils-plugin-ha-sap | tee -a ${HANA_LOG_FILE}
  zypper -n install insserv-compat | tee -a ${HANA_LOG_FILE}
  zypper -n install libltdl7 | tee -a ${HANA_LOG_FILE}
  zypper -n install libssh2-1 | tee -a ${HANA_LOG_FILE}
  
  # Install GCC and GC++ compilers. GCC includes package libatomic1 that is required for all GCC 7 compiled apps, see OSS note 2593824.
  zypper -n install gcc | tee -a ${HANA_LOG_FILE}
  zypper -n install gcc-c++ | tee -a ${HANA_LOG_FILE}
  zypper -n install libgcc_s1 | tee -a ${HANA_LOG_FILE}
  zypper -n install libstdc++6  | tee -a ${HANA_LOG_FILE}
  
  # Install most current libatomic1 if available
  zypper -n install libatomic1 | tee -a ${HANA_LOG_FILE}
  
  # unrar has been replaced by unar in SLES 15, and is implemented as 
  # a symbolic link to unar "unrar --> /usr/bin/unar.                 
  zypper -n install unrar_wrapper | tee -a ${HANA_LOG_FILE}

  # Chrony has replaced NTP for time server synchonization as of SLES 15, and 
  # it's installed by default.                                                
  # Below command is only to update chrony to the most current version.
  zypper -n install chrony | tee -a ${HANA_LOG_FILE}

  # In SLES 15, command "ifconfig" has been replaced by "ip", and moved 
  # from package net-tools to net-tools-deprecated. "ip" is installed by
  # default. Once "ifconfig" is completely removed we'll need to replace  
  # "ifconfig" by "ip" in all codes for SLES15.                         
  zypper -n install net-tools-deprecated | tee -a ${HANA_LOG_FILE}

  # See SLES15 for SAP install Guides
  zypper -n install patterns-sles-sap_server | tee -a ${HANA_LOG_FILE}

  # See OSS note 2788495
  
  zypper -n install libopenssl1_0_0 | tee -a ${HANA_LOG_FILE}

  # Apply all Recommended HANA settings with SAPTUNE
  install_and_run_saptune
  
}

install_prereq_sles15sp2sap() {
  # ------------------------------------------------------------------
  #          Install all SLES15ForSAP pre-requisites for SAP HANA
  # ------------------------------------------------------------------

  log "`date` - Install / Update OS Packages## "
  install_enable_ssm_agent
  zypper -n install systemd 2>&1 | tee -a ${HANA_LOG_FILE}
  zypper -n install tuned  | tee -a ${HANA_LOG_FILE}
  zypper -n install saptune  | tee -a ${HANA_LOG_FILE}
  zypper -n install cpupower  | tee -a ${HANA_LOG_FILE}
  zypper -n install nvme-cli | tee -a ${HANA_LOG_FILE}
  zypper -n install cloud-netconfig-ec2 | tee -a ${HANA_LOG_FILE}
  zypper -n install supportutils-plugin-ha-sap | tee -a ${HANA_LOG_FILE}
  zypper -n install insserv-compat | tee -a ${HANA_LOG_FILE}
  zypper -n install libltdl7 | tee -a ${HANA_LOG_FILE}
  zypper -n install libssh2-1 | tee -a ${HANA_LOG_FILE}
  
  # Install GCC and GC++ compilers. GCC includes package libatomic1 that is required for all GCC 7 compiled apps, see OSS note 2593824.
  zypper -n install gcc | tee -a ${HANA_LOG_FILE}
  zypper -n install gcc-c++ | tee -a ${HANA_LOG_FILE}
  zypper -n install libgcc_s1 | tee -a ${HANA_LOG_FILE}
  zypper -n install libstdc++6  | tee -a ${HANA_LOG_FILE}
  
  # Install most current libatomic1 if available
  zypper -n install libatomic1 | tee -a ${HANA_LOG_FILE}
  
  # unrar has been replaced by unar in SLES 15, and is implemented as 
  # a symbolic link to unar "unrar --> /usr/bin/unar.                 
  zypper -n install unrar_wrapper | tee -a ${HANA_LOG_FILE}

  # Chrony has replaced NTP for time server synchonization as of SLES 15, and 
  # it's installed by default.                                                
  # Below command is only to update chrony to the most current version.
  zypper -n install chrony | tee -a ${HANA_LOG_FILE}

  # In SLES 15, command "ifconfig" has been replaced by "ip", and moved 
  # from package net-tools to net-tools-deprecated. "ip" is installed by
  # default. Once "ifconfig" is completely removed we'll need to replace  
  # "ifconfig" by "ip" in all codes for SLES15.                         
  zypper -n install net-tools-deprecated | tee -a ${HANA_LOG_FILE}

  # See SLES15 for SAP install Guides
  zypper -n install patterns-sles-sap_server | tee -a ${HANA_LOG_FILE}

  # See OSS note 2788495
  
  zypper -n install libopenssl1_0_0 | tee -a ${HANA_LOG_FILE}

  # Apply all Recommended HANA settings with SAPTUNE
  install_and_run_saptune
  
}

install_prereq_sles15sp3sap() {
  # ------------------------------------------------------------------
  #          Install all SLES15ForSAP pre-requisites for SAP HANA
  # ------------------------------------------------------------------

  log "`date` - Install / Update OS Packages## "
  install_enable_ssm_agent
  zypper -n install systemd 2>&1 | tee -a ${HANA_LOG_FILE}
  zypper -n install tuned  | tee -a ${HANA_LOG_FILE}
  zypper -n install saptune  | tee -a ${HANA_LOG_FILE}
  zypper -n install cpupower  | tee -a ${HANA_LOG_FILE}
  zypper -n install nvme-cli | tee -a ${HANA_LOG_FILE}
  zypper -n install cloud-netconfig-ec2 | tee -a ${HANA_LOG_FILE}
  zypper -n install supportutils-plugin-ha-sap | tee -a ${HANA_LOG_FILE}
  zypper -n install insserv-compat | tee -a ${HANA_LOG_FILE}
  zypper -n install libltdl7 | tee -a ${HANA_LOG_FILE}
  zypper -n install libssh2-1 | tee -a ${HANA_LOG_FILE}
  
  # Install GCC and GC++ compilers. GCC includes package libatomic1 that is required for all GCC 7 compiled apps, see OSS note 2593824.
  zypper -n install gcc | tee -a ${HANA_LOG_FILE}
  zypper -n install gcc-c++ | tee -a ${HANA_LOG_FILE}
  zypper -n install libgcc_s1 | tee -a ${HANA_LOG_FILE}
  zypper -n install libstdc++6  | tee -a ${HANA_LOG_FILE}
  
  # Install most current libatomic1 if available
  zypper -n install libatomic1 | tee -a ${HANA_LOG_FILE}
  
  # unrar has been replaced by unar in SLES 15, and is implemented as 
  # a symbolic link to unar "unrar --> /usr/bin/unar.                 
  zypper -n install unrar_wrapper | tee -a ${HANA_LOG_FILE}

  # Chrony has replaced NTP for time server synchonization as of SLES 15, and 
  # it's installed by default.                                                
  # Below command is only to update chrony to the most current version.
  zypper -n install chrony | tee -a ${HANA_LOG_FILE}

  # In SLES 15, command "ifconfig" has been replaced by "ip", and moved 
  # from package net-tools to net-tools-deprecated. "ip" is installed by
  # default. Once "ifconfig" is completely removed we'll need to replace  
  # "ifconfig" by "ip" in all codes for SLES15.                         
  zypper -n install net-tools-deprecated | tee -a ${HANA_LOG_FILE}

  # See SLES15 for SAP install Guides
  zypper -n install patterns-sles-sap_server | tee -a ${HANA_LOG_FILE}

  # See OSS note 2788495
  
  zypper -n install libopenssl1_0_0 | tee -a ${HANA_LOG_FILE}

  # Apply all Recommended HANA settings with SAPTUNE
  install_and_run_saptune
  
}

install_prereq_sles12sp1sapbyos() {
  # ------------------------------------------------------------------
  #          Install all the pre-requisites for SAP HANA
  # ------------------------------------------------------------------

  log "`date` - Install / Update OS Packages## "

  zypper -n install tuned  | tee -a ${HANA_LOG_FILE}
  zypper -n install saptune  | tee -a ${HANA_LOG_FILE}
  zypper -n install cpupower  | tee -a ${HANA_LOG_FILE}
  zypper -n install amazon-ssm-agent | tee -a ${HANA_LOG_FILE}
  systemctl start amazon-ssm-agent | tee -a ${HANA_LOG_FILE}
  zypper -n install nvme-cli | tee -a ${HANA_LOG_FILE}
  systemctl start amazon-ssm-agent | tee -a ${HANA_LOG_FILE}
  
  #Install unrar for media extraction
  zypper -n install unrar  | tee -a ${HANA_LOG_FILE}
  
  # Install GCC and GC++ compilers. GCC includes package libatomic1 that is required for all GCC 7 compiled apps, see OSS note 2593824.
  zypper -n install gcc | tee -a ${HANA_LOG_FILE}
  zypper -n install gcc-c++ | tee -a ${HANA_LOG_FILE}
  
  # Install most current libatomic1 if available
  zypper -n install libatomic1 | tee -a ${HANA_LOG_FILE}
  
  # Apply all Recommended HANA settings with SAPTUNE
  install_and_run_saptune

}

install_prereq_sles12sp2sapbyos() {
  # ------------------------------------------------------------------
  #          Install all the pre-requisites for SAP HANA
  # ------------------------------------------------------------------
  log "`date` - Install / Update OS Packages## "
  zypper -n install systemd 2>&1 | tee -a ${HANA_LOG_FILE}
  zypper -n install tuned  | tee -a ${HANA_LOG_FILE}
  zypper -n install saptune  | tee -a ${HANA_LOG_FILE}
  zypper -n install cpupower  | tee -a ${HANA_LOG_FILE}
  zypper -n install amazon-ssm-agent | tee -a ${HANA_LOG_FILE}
  zypper -n install nvme-cli | tee -a ${HANA_LOG_FILE}
  systemctl start amazon-ssm-agent | tee -a ${HANA_LOG_FILE}
  
  #Install unrar for media extraction
  zypper -n install unrar  | tee -a ${HANA_LOG_FILE}
  
  # Install GCC and GC++ compilers. GCC includes package libatomic1 that is required for all GCC 7 compiled apps, see OSS note 2593824.
  zypper -n install gcc | tee -a ${HANA_LOG_FILE}
  zypper -n install gcc-c++ | tee -a ${HANA_LOG_FILE}
  
  # Install most current libatomic1 if available
  zypper -n install libatomic1 | tee -a ${HANA_LOG_FILE}
  
  # Apply all Recommended HANA settings with SAPTUNE
  install_and_run_saptune

}

install_prereq_sles12sp3sapbyos() {
  # ------------------------------------------------------------------
  #          Install all the pre-requisites for SAP HANA
  # ------------------------------------------------------------------
  log "`date` - Install / Update OS Packages## "
  install_enable_ssm_agent
  zypper -n install systemd 2>&1 | tee -a ${HANA_LOG_FILE}
  zypper -n install tuned  | tee -a ${HANA_LOG_FILE}
  zypper -n install saptune  | tee -a ${HANA_LOG_FILE}
  zypper -n install cpupower  | tee -a ${HANA_LOG_FILE}
  zypper -n install nvme-cli | tee -a ${HANA_LOG_FILE}
  zypper -n install libopenssl0_9_8 | tee -a ${HANA_LOG_FILE}
  zypper -n install libgcc_s1 | tee -a ${HANA_LOG_FILE}
  zypper -n install libstdc++6  | tee -a ${HANA_LOG_FILE}
  
  #Install unrar for media extraction
  zypper -n install unrar  | tee -a ${HANA_LOG_FILE}
  
  # Install GCC and GC++ compilers. GCC includes package libatomic1 that is required for all GCC 7 compiled apps, see OSS note 2593824.
  zypper -n install gcc | tee -a ${HANA_LOG_FILE}
  zypper -n install gcc-c++ | tee -a ${HANA_LOG_FILE}
  
  # Install most current libatomic1 if available
  zypper -n install libatomic1 | tee -a ${HANA_LOG_FILE}
  
  # Install Python Six for compability
  zypper -n install python2-six | tee -a ${HANA_LOG_FILE}
  zypper -n install python3-six | tee -a ${HANA_LOG_FILE}
  
  # Apply all Recommended HANA settings with SAPTUNE 
  install_and_run_saptune
}

install_prereq_sles12sp4sapbyos() {
  # ------------------------------------------------------------------
  #          Install all the pre-requisites for SAP HANA
  # ------------------------------------------------------------------
  log "`date` - Install / Update OS Packages## "
  install_enable_ssm_agent
  zypper -n install systemd 2>&1 | tee -a ${HANA_LOG_FILE}
  zypper -n install tuned  | tee -a ${HANA_LOG_FILE}
  zypper -n install saptune  | tee -a ${HANA_LOG_FILE}
  zypper -n install cpupower  | tee -a ${HANA_LOG_FILE}
  zypper -n install nvme-cli | tee -a ${HANA_LOG_FILE}
  zypper -n install libopenssl0_9_8 | tee -a ${HANA_LOG_FILE}
  zypper -n install libgcc_s1 | tee -a ${HANA_LOG_FILE}
  zypper -n install libstdc++6  | tee -a ${HANA_LOG_FILE}
  zypper -n install supportutils-plugin-ha-sap | tee -a ${HANA_LOG_FILE}
  zypper -n install insserv-compat | tee -a ${HANA_LOG_FILE}
  zypper -n install libltdl7 | tee -a ${HANA_LOG_FILE}
  zypper -n install libssh2-1 | tee -a ${HANA_LOG_FILE}
  
  #Install unrar for media extraction
  zypper -n install unrar  | tee -a ${HANA_LOG_FILE}
  
  # Install GCC and GC++ compilers. GCC includes package libatomic1 that is required for all GCC 7 compiled apps, see OSS note 2593824.
  zypper -n install gcc | tee -a ${HANA_LOG_FILE}
  zypper -n install gcc-c++ | tee -a ${HANA_LOG_FILE}
  
  # Install most current libatomic1 if available
  zypper -n install libatomic1 | tee -a ${HANA_LOG_FILE}
  
  # Install Python Six for compability
  zypper -n install python2-six | tee -a ${HANA_LOG_FILE}
  zypper -n install python3-six | tee -a ${HANA_LOG_FILE}
  
  # Apply all Recommended HANA settings with SAPTUNE
  install_and_run_saptune
}

install_prereq_sles12sp5sapbyos() {
  # ------------------------------------------------------------------
  #          Install all the pre-requisites for SAP HANA
  # ------------------------------------------------------------------
  log "`date` - Install / Update OS Packages## "
  install_enable_ssm_agent
  zypper -n install systemd 2>&1 | tee -a ${HANA_LOG_FILE}
  zypper -n install tuned  | tee -a ${HANA_LOG_FILE}
  zypper -n install saptune  | tee -a ${HANA_LOG_FILE}
  zypper -n install cpupower  | tee -a ${HANA_LOG_FILE}
  zypper -n install nvme-cli | tee -a ${HANA_LOG_FILE}
  zypper -n install libopenssl0_9_8 | tee -a ${HANA_LOG_FILE}
  zypper -n install libgcc_s1 | tee -a ${HANA_LOG_FILE}
  zypper -n install libstdc++6  | tee -a ${HANA_LOG_FILE}
  zypper -n install supportutils-plugin-ha-sap | tee -a ${HANA_LOG_FILE}
  zypper -n install insserv-compat | tee -a ${HANA_LOG_FILE}
  zypper -n install libltdl7 | tee -a ${HANA_LOG_FILE}
  zypper -n install libssh2-1 | tee -a ${HANA_LOG_FILE}
  
  #Install unrar for media extraction
  zypper -n install unrar  | tee -a ${HANA_LOG_FILE}
  
  # Install GCC and GC++ compilers. GCC includes package libatomic1 that is required for all GCC 7 compiled apps, see OSS note 2593824.
  zypper -n install gcc | tee -a ${HANA_LOG_FILE}
  zypper -n install gcc-c++ | tee -a ${HANA_LOG_FILE}
  
  # Install most current libatomic1 if available
  zypper -n install libatomic1 | tee -a ${HANA_LOG_FILE}
  
  # Apply all Recommended HANA settings with SAPTUNE
  install_and_run_saptune
}

install_prereq_sles15sapbyos() {
  # ------------------------------------------------------------------
  #          Install all the pre-requisites for SAP HANA
  # ------------------------------------------------------------------
  log "`date` - Install / Update OS Packages## "
  install_enable_ssm_agent
  zypper -n install systemd 2>&1 | tee -a ${HANA_LOG_FILE}
  zypper -n install tuned  | tee -a ${HANA_LOG_FILE}
  zypper -n install saptune  | tee -a ${HANA_LOG_FILE}
  zypper -n install cpupower  | tee -a ${HANA_LOG_FILE}
  zypper -n install nvme-cli | tee -a ${HANA_LOG_FILE}
  zypper -n install supportutils-plugin-ha-sap | tee -a ${HANA_LOG_FILE}
  zypper -n install insserv-compat | tee -a ${HANA_LOG_FILE}
  zypper -n install libltdl7 | tee -a ${HANA_LOG_FILE}
  zypper -n install libssh2-1 | tee -a ${HANA_LOG_FILE}
  
  # Install GCC and GC++ compilers. GCC includes package libatomic1 that is required for all GCC 7 compiled apps, see OSS note 2593824.
  zypper -n install gcc | tee -a ${HANA_LOG_FILE}
  zypper -n install gcc-c++ | tee -a ${HANA_LOG_FILE}
  zypper -n install libgcc_s1 | tee -a ${HANA_LOG_FILE}
  zypper -n install libstdc++6  | tee -a ${HANA_LOG_FILE}
  
  # Install most current libatomic1 if available
  zypper -n install libatomic1 | tee -a ${HANA_LOG_FILE}
  
  # Install Python Six for compability
  zypper -n install python2-six | tee -a ${HANA_LOG_FILE}
  zypper -n install python3-six | tee -a ${HANA_LOG_FILE}
  
  # See OSS note 2788495
  zypper -n install libopenssl1_0_0 | tee -a ${HANA_LOG_FILE}
  
  # unrar has been replaced by unar in SLES 15, and is implemented as
  # a symbolic link to unar "unrar --> /usr/bin/unar.
  zypper -n install unrar_wrapper | tee -a ${HANA_LOG_FILE}

  # Chrony has replaced NTP for time server synchonization as of SLES 15, and
  # it's installed by default.                                                
  # Below command is only to update chrony to the most current version.
  zypper -n install chrony | tee -a ${HANA_LOG_FILE}

  # in SLES 15, command "ifconfig" has been replaced by "ip", and moved  
  # from package net-tools to net-tools-deprecated. "ip" is installed by  
  # default. Once "ifconfig" is completely removed we'll need to replace  
  # "ifconfig" by "ip" in all codes for SLES15.                           
  zypper -n install net-tools-deprecated | tee -a ${HANA_LOG_FILE}

  # See SLES15 for SAP install Guides
  zypper -n install patterns-sles-sap_server | tee -a ${HANA_LOG_FILE}

  # Apply all Recommended HANA settings with SAPTUNE
  install_and_run_saptune

}

install_prereq_sles15sp1sapbyos() {
  # ------------------------------------------------------------------
  #          Install all the pre-requisites for SAP HANA
  # ------------------------------------------------------------------
  log "`date` - Install / Update OS Packages## "
  install_enable_ssm_agent
  zypper -n install systemd 2>&1 | tee -a ${HANA_LOG_FILE}
  zypper -n install tuned  | tee -a ${HANA_LOG_FILE}
  zypper -n install saptune  | tee -a ${HANA_LOG_FILE}
  zypper -n install cpupower  | tee -a ${HANA_LOG_FILE}
  zypper -n install nvme-cli | tee -a ${HANA_LOG_FILE}
  zypper -n install supportutils-plugin-ha-sap | tee -a ${HANA_LOG_FILE}
  zypper -n install insserv-compat | tee -a ${HANA_LOG_FILE}
  zypper -n install libltdl7 | tee -a ${HANA_LOG_FILE}
  zypper -n install libssh2-1 | tee -a ${HANA_LOG_FILE}  
  
  
  # Install GCC and GC++ compilers. GCC includes package libatomic1 that is required for all GCC 7 compiled apps, see OSS note 2593824.
  zypper -n install gcc | tee -a ${HANA_LOG_FILE}
  zypper -n install gcc-c++ | tee -a ${HANA_LOG_FILE}
  zypper -n install libgcc_s1 | tee -a ${HANA_LOG_FILE}
  zypper -n install libstdc++6  | tee -a ${HANA_LOG_FILE}
  
  # Install most current libatomic1 if available
  zypper -n install libatomic1 | tee -a ${HANA_LOG_FILE}
  
  # See OSS note 2788495 
  zypper -n install libopenssl1_0_0 | tee -a ${HANA_LOG_FILE}

  ## unrar has been replaced by unar in SLES 15, and is implemented as 
  ## a symbolic link to unar "unrar --> /usr/bin/unar.                
  zypper -n install unrar_wrapper | tee -a ${HANA_LOG_FILE}

  # Chrony has replaced NTP for time server synchonization as of SLES 15, and 
  # it's installed by default.                                                
  # Below command is only to update chrony to the most current version.     
  zypper -n install chrony | tee -a ${HANA_LOG_FILE}

  # in SLES 15, command "ifconfig" has been replaced by "ip", and moved   
  # from package net-tools to net-tools-deprecated. "ip" is installed by  
  # default. Once "ifconfig" is completely removed we'll need to replace  
  # "ifconfig" by "ip" in all codes for SLES15.                           
  zypper -n install net-tools-deprecated | tee -a ${HANA_LOG_FILE}

  # See SLES15 for SAP install Guides
  zypper -n install patterns-sles-sap_server | tee -a ${HANA_LOG_FILE}

  # Apply all Recommended HANA settings with SAPTUNE
  install_and_run_saptune

}

install_prereq_sles15sp2sapbyos() {
  # ------------------------------------------------------------------
  #          Install all the pre-requisites for SAP HANA
  # ------------------------------------------------------------------
  log "`date` - Install / Update OS Packages## "
  install_enable_ssm_agent
  zypper -n install systemd 2>&1 | tee -a ${HANA_LOG_FILE}
  zypper -n install tuned  | tee -a ${HANA_LOG_FILE}
  zypper -n install saptune  | tee -a ${HANA_LOG_FILE}
  zypper -n install cpupower  | tee -a ${HANA_LOG_FILE}
  zypper -n install nvme-cli | tee -a ${HANA_LOG_FILE}
  zypper -n install supportutils-plugin-ha-sap | tee -a ${HANA_LOG_FILE}
  zypper -n install insserv-compat | tee -a ${HANA_LOG_FILE}
  zypper -n install libltdl7 | tee -a ${HANA_LOG_FILE}
  zypper -n install libssh2-1 | tee -a ${HANA_LOG_FILE}
  
  # Install GCC and GC++ compilers. GCC includes package libatomic1 that is required for all GCC 7 compiled apps, see OSS note 2593824.
  zypper -n install gcc | tee -a ${HANA_LOG_FILE}
  zypper -n install gcc-c++ | tee -a ${HANA_LOG_FILE}
  zypper -n install libgcc_s1 | tee -a ${HANA_LOG_FILE}
  zypper -n install libstdc++6  | tee -a ${HANA_LOG_FILE}
  
  # Install most current libatomic1 if available
  zypper -n install libatomic1 | tee -a ${HANA_LOG_FILE}
  
  # See OSS note 2788495 
  zypper -n install libopenssl1_0_0 | tee -a ${HANA_LOG_FILE}

  ## unrar has been replaced by unar in SLES 15, and is implemented as 
  ## a symbolic link to unar "unrar --> /usr/bin/unar.                
  zypper -n install unrar_wrapper | tee -a ${HANA_LOG_FILE}

  # Chrony has replaced NTP for time server synchonization as of SLES 15, and 
  # it's installed by default.                                                
  # Below command is only to update chrony to the most current version.     
  zypper -n install chrony | tee -a ${HANA_LOG_FILE}

  # in SLES 15, command "ifconfig" has been replaced by "ip", and moved   
  # from package net-tools to net-tools-deprecated. "ip" is installed by  
  # default. Once "ifconfig" is completely removed we'll need to replace  
  # "ifconfig" by "ip" in all codes for SLES15.                           
  zypper -n install net-tools-deprecated | tee -a ${HANA_LOG_FILE}

  # See SLES15 for SAP install Guides
  zypper -n install patterns-sles-sap_server | tee -a ${HANA_LOG_FILE}

  # Apply all Recommended HANA settings with SAPTUNE
  install_and_run_saptune

}

install_prereq_sles15sp3sapbyos() {
  # ------------------------------------------------------------------
  #          Install all the pre-requisites for SAP HANA
  # ------------------------------------------------------------------
  log "`date` - Install / Update OS Packages## "
  install_enable_ssm_agent
  zypper -n install systemd 2>&1 | tee -a ${HANA_LOG_FILE}
  zypper -n install tuned  | tee -a ${HANA_LOG_FILE}
  zypper -n install saptune  | tee -a ${HANA_LOG_FILE}
  zypper -n install cpupower  | tee -a ${HANA_LOG_FILE}
  zypper -n install nvme-cli | tee -a ${HANA_LOG_FILE}
  zypper -n install supportutils-plugin-ha-sap | tee -a ${HANA_LOG_FILE}
  zypper -n install insserv-compat | tee -a ${HANA_LOG_FILE}
  zypper -n install libltdl7 | tee -a ${HANA_LOG_FILE}
  zypper -n install libssh2-1 | tee -a ${HANA_LOG_FILE}
  
  # Install GCC and GC++ compilers. GCC includes package libatomic1 that is required for all GCC 7 compiled apps, see OSS note 2593824.
  zypper -n install gcc | tee -a ${HANA_LOG_FILE}
  zypper -n install gcc-c++ | tee -a ${HANA_LOG_FILE}
  zypper -n install libgcc_s1 | tee -a ${HANA_LOG_FILE}
  zypper -n install libstdc++6  | tee -a ${HANA_LOG_FILE}
  
  # Install most current libatomic1 if available
  zypper -n install libatomic1 | tee -a ${HANA_LOG_FILE}
  
  # See OSS note 2788495 
  zypper -n install libopenssl1_0_0 | tee -a ${HANA_LOG_FILE}

  ## unrar has been replaced by unar in SLES 15, and is implemented as 
  ## a symbolic link to unar "unrar --> /usr/bin/unar.                
  zypper -n install unrar_wrapper | tee -a ${HANA_LOG_FILE}

  # Chrony has replaced NTP for time server synchonization as of SLES 15, and 
  # it's installed by default.                                                
  # Below command is only to update chrony to the most current version.     
  zypper -n install chrony | tee -a ${HANA_LOG_FILE}

  # in SLES 15, command "ifconfig" has been replaced by "ip", and moved   
  # from package net-tools to net-tools-deprecated. "ip" is installed by  
  # default. Once "ifconfig" is completely removed we'll need to replace  
  # "ifconfig" by "ip" in all codes for SLES15.                           
  zypper -n install net-tools-deprecated | tee -a ${HANA_LOG_FILE}

  # See SLES15 for SAP install Guides
  zypper -n install patterns-sles-sap_server | tee -a ${HANA_LOG_FILE}

  # Apply all Recommended HANA settings with SAPTUNE
  install_and_run_saptune

}

install_prereq_sles11sp4() {
    # ------------------------------------------------------------------
    #          Install all the pre-requisites for SAP HANA
    # ------------------------------------------------------------------

    log "`date` - Install / Update OS Packages## "

    zypper -n install gtk2 2>&1 | tee -a ${HANA_LOG_FILE}
    zypper -n install java-1_6_0-ibm 2>&1 | tee -a ${HANA_LOG_FILE}
    zypper -n install libicu  | tee -a ${HANA_LOG_FILE}
    zypper -n install mozilla-xulrunner*  | tee -a ${HANA_LOG_FILE}
    zypper -n install ntp  | tee -a ${HANA_LOG_FILE}
    zypper -n install sudo  | tee -a ${HANA_LOG_FILE}
    zypper -n install syslog-ng  | tee -a ${HANA_LOG_FILE}
    zypper -n install tcsh libssh2-1 | tee -a ${HANA_LOG_FILE}
    zypper -n install autoyast2-installation | tee -a ${HANA_LOG_FILE}
    zypper -n install yast2-ncurses  | tee -a ${HANA_LOG_FILE}
    zypper -n install cpupower  | tee -a ${HANA_LOG_FILE}
    #Install unrar for media extraction
    zypper -n install unrar  | tee -a ${HANA_LOG_FILE}
    #SLES 12 installation fails with libnuma
    zypper -n install libnuma-devel | tee -a ${HANA_LOG_FILE}
    #Remove ulimit package
    zypper remove ulimit > /dev/null
    chkconfig boot.kdump  | tee -a ${HANA_LOG_FILE}
    chkconfig kdump off
    echo "net.ipv4.tcp_slow_start_after_idle=0" >> /etc/sysctl.conf
    sysctl -p /etc/sysctl.conf  | tee -a ${HANA_LOG_FILE}

    #ipcs -l  | tee -a ${HANA_LOG_FILE}
    echo "kernel.shmmni=65536" >> /etc/sysctl.conf
    sysctl -p /etc/sysctl.conf  | tee -a ${HANA_LOG_FILE}

    #error check and return
}

start_ntp() {
    # ------------------------------------------------------------------
    #          Configure and Start ntp server
    # ------------------------------------------------------------------

     echo "server 0.pool.ntp.org" >> /etc/ntp.conf
     echo "server 1.pool.ntp.org" >> /etc/ntp.conf
     echo "server 2.pool.ntp.org" >> /etc/ntp.conf
     echo "server 3.pool.ntp.org" >> /etc/ntp.conf
     service ntp start  | tee -a ${HANA_LOG_FILE}
     chkconfig ntp on  | tee -a ${HANA_LOG_FILE}

     #error check and return
}

start_fs() {
    # ------------------------------------------------------------------
    #          Issue: /hana/shared not getting mounted
    # ------------------------------------------------------------------

     chkconfig autofs on

    #error check and return
}

start_oss_configs() {

    #This section is from OSS #2205917 - SAP HANA DB: Recommended OS settings for SLES 12 / SLES for SAP Applications 12
    #and OSS #2684254 - SAP HANA DB: Recommended OS settings for SLES 15 / SLES for SAP Applications 15

    # Set Clocksource to tsc
    log "`date` Setting clocksource to tsc"
    # Checking for Nitro instances
    if grep tsc /sys/devices/system/clocksource/clocksource0/available_clocksource >> ${HANA_LOG_FILE} 2>&1
    then
        if grep tsc /sys/devices/system/clocksource/clocksource0/current_clocksource >> ${HANA_LOG_FILE} 2>&1
        then
            log "`date` Do nothing! Clocksource is already set to tsc"
        else
            echo "tsc" > /sys/devices/system/clocksource/clocksource0/current_clocksource
        fi
    fi
    
    ##Disable THP
    echo never > /sys/kernel/mm/transparent_hugepage/enabled

    #Disable AutoNUMA
    echo 0 > /proc/sys/kernel/numa_balancing

    #Disable KSM
    echo 0 > /sys/kernel/mm/ksm/run
    echo "echo 0 > /sys/kernel/mm/ksm/run" >> /etc/init.d/boot.local

    # Set GRUB configuration for required settings from
    #     SAP Note 2684254 and SAP Note 2205917
    cp -p /etc/default/grub /etc/default/grub.quickstart.save
    sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="[^"]*/& numa_balancing=disable transparent_hugepage=never intel_idle.max_cstate=1 processor.max_cstate=1 clocksource=tsc tsc=reliable/' /etc/default/grub
    cp -p /boot/grub2/grub.cfg /boot/grub2/grub.cfg.quickstart.save
    grub2-mkconfig -o /boot/grub2/grub.cfg
    #
    log "`date` Configuring C-State and P-State"
    cpupower frequency-set -g performance > /dev/null
    cpupower idle-set -d 6 > /dev/null
    cpupower idle-set -d 5 > /dev/null
    cpupower idle-set -d 4 > /dev/null
    cpupower idle-set -d 3 > /dev/null
    cpupower idle-set -d 2 > /dev/null
    echo "cpupower frequency-set -g performance" >> /etc/init.d/boot.local
    
}

disable_dhcp() {

    sed -i '/DHCLIENT_SET_HOSTNAME/ c\DHCLIENT_SET_HOSTNAME="no"' /etc/sysconfig/network/dhcp
    #restart network
    service network restart
    #error check and return
}

disable_hostname() {

    sed -i '/preserve_hostname/ c\preserve_hostname: true' /etc/cloud/cloud.cfg
    #error check and return
}

enable_resize_to_from_nitro() {
  #
  conf_file="/etc/dracut.conf.d/07-aws-type-switch.conf"
  rules_file="/etc/udev/rules.d/70-persistent-net.rules"
  
  if [ -f $rules_file ]; then
     log "`date`  File $rules_file exits - removing it"
     rm -fr $rules_file
  fi
  
  if [ -f $conf_file ]; then
     log "`date`  File $conf_file already exist so skipping the step to enable resize"
  else
     log "`date`  File $conf_file doesn't exist. Executing steps to enable resize"
     ## ----------------------------------------------------------------------------------------------- ##
     ## -- Added xfs to $conf_file for SLES 15                                                       -- ##
     ## -- SLES15 creates root file system as xfs, instead ext4 by earlier versions.                 -- ##
     ## -- Instances won't start after reboot as the root file system can't be mounted               -- ##
     ## ----------------------------------------------------------------------------------------------- ##
     echo 'drivers+="ena xfs ext4 nvme nvme-core virtio virtio_scsi xen-blkfront xen-netfront "' >> $conf_file
     mkinitrd | tee -a ${HANA_LOG_FILE}
  fi
}

fix_slesforsap_suse_repo() {
  # -------------------------------------------------------------------------- #
  # Temporary fix for the issue of unable to access SuSE repo issue - 07/06/19
  # -------------------------------------------------------------------------- #
    if ls -l /etc/products.d/baseproduct | grep -v "SLES_SAP.prod" 1> /dev/null
    then
        cd /etc/products.d >> ${HANA_LOG_FILE} 2>&1
        unlink baseproduct >> ${HANA_LOG_FILE} 2>&1
        ln -s SLES_SAP.prod baseproduct >> ${HANA_LOG_FILE} 2>&1
        registercloudguest --force-new >> ${HANA_LOG_FILE} 2>&1
    fi
}

install_enable_ssm_agent() {
  # Install and enable amazon-ssm-agent
  zypper -n install amazon-ssm-agent | tee -a ${HANA_LOG_FILE}
  systemctl enable amazon-ssm-agent | tee -a ${HANA_LOG_FILE}
  systemctl start amazon-ssm-agent | tee -a ${HANA_LOG_FILE}
}

install_and_run_saptune() {
  # Install and execute saptune and apply configs for SAP HANA
  zypper -n install saptune | tee -a ${HANA_LOG_FILE}
  log "`date` - Apply saptune HANA profile"
  saptune daemon start | tee -a ${HANA_LOG_FILE}
  saptune solution apply HANA | tee -a ${HANA_LOG_FILE}
  log "`date` - Apply saptune HANA profile"
}

#***END Functions***


# ------------------------------------------------------------------
#         Code Body section
# ------------------------------------------------------------------

#Call Functions

#Check if we are X1 instance type
X1=$(check_instancetype)

#Check the O.S. Version
KV=$(uname -r)

#Check to see if instance type is X1 and Kernel version is supported

if [ $(check_kernel) == 0 -a $(check_instancetype) == 1 ]
then
    log "`date` Calling signal-failure.sh from $0 @ `date` with INCOMPATIBLE parameter"
    log "`date` Instance Type $X1 and O.S. is not supported with Kernel $KV"
    /root/install/signal-failure.sh "INCOMPATIBLE"
    touch "$SIG_FLAG_FILE"
    sleep 300
    exit 1
fi

#Check to see if BYOS SLES registration is successful

if [[ ("$MyOS" =~ SLES) && ("$MyOS" =~ BYOS) ]];
then
    log "`date` Registering SUSE BYOS"
    SUSEConnect -r $SLESBYOSRegCode | tee -a ${HANA_LOG_FILE}
    CheckSLESRegistration=$(SUSEConnect -s | grep ACTIVE)
    if [ "$CheckSLESRegistration" ]
    then
        log "`date` SUSE BYOS registration was successful"
    else
        /root/install/signal-failure.sh "SUSECONNECTFAIL"
        log "`date` Exiting QuickStart, check SUSE registration code"
        touch "$SIG_FLAG_FILE"
        sleep 300
        exit 1
    fi
    #
    # Activating SUSE legacy and public cloud modules
    #
    log "`date` Adding ${MyOS} Public Cloud Module x86_64 extension"
    VERSION_ID=$(grep VERSION_ID /etc/os-release | cut -f2 -d= | sed -e s/\"//g)
    #
    if [[ "$MyOS" =~ 12 ]]
    then
        SUSEConnect -p sle-module-public-cloud/12/x86_64 | tee -a ${HANA_LOG_FILE}
    elif [[ "$MyOS" =~ 15 ]]
    then
        SUSEConnect -p sle-module-public-cloud/${VERSION_ID}/x86_64 && SUSEConnect -p sle-module-legacy/${VERSION_ID}/x86_64 | tee -a ${HANA_LOG_FILE}
    fi
    #
    if [ $? -eq 0 ]
    then
        log "`date` SUSE public cloud module activation SUCCEED"
    else
        /root/install/signal-failure.sh "ACTMODULEFAIL"
        touch "$SIG_FLAG_FILE"
        sleep 300
        exit 1
    fi
fi

# -------------------------------------------------------------------------- #

# -------------------------------------------------------------------------- #
# Check and set nvme_core.io_timeout.                                        #
# -------------------------------------------------------------------------- #
if grep nvme_core.io_timeout=4294967295 /etc/default/grub >> ${HANA_LOG_FILE} 2>&1
then
    log "`date` Do nothing. nvme_io_timeout is already set correctly"
fi

#Check to see if zypper repository is accessible

if [ $(check_zypper) == 0 ]
then
    log "`date` Calling signal-failure.sh from $0 @ `date` with ZYPPER parameter"
    log "`date` Instance Type = X1: $X1 and zypper repository is not correct."
    /root/install/signal-failure.sh "ZYPPER"
    touch "$SIG_FLAG_FILE"
    sleep 300
    exit 1
fi


case "$MyOS" in
  SLES11SP4HVM )
    log "`date` Start - Executing SLES 11 SP4 related pre-requisites"
    install_prereq_sles11sp4
    disable_dhcp
    disable_hostname
    start_ntp
    start_fs
    start_oss_configs
    log "`date` End - Executing SLES 11 SP4 related pre-requisites" ;;
  SLES12HVM )
    log "`date` Start - Executing SLES 12 related pre-requisites"
    install_prereq_sles12
    disable_dhcp
    disable_hostname
    start_ntp
    start_fs
    start_oss_configs
    log "`date` End - Executing SLES 12 related pre-requisites" ;;
  SLES12SP1HVM )
    log "`date` Start - Executing SLES 12 SP1 related pre-requisites"
    install_prereq_sles12sp1
    disable_dhcp
    disable_hostname
    start_ntp
    start_fs
    start_oss_configs
    log "`date` End - Executing SLES 12 SP1 related pre-requisites" ;;
  SLES12SP2HVM )
    log "`date` Start - Executing SLES 12 SP2 related pre-requisites"
    install_prereq_sles12sp2
    disable_dhcp
    disable_hostname
    start_ntp
    start_fs
    start_oss_configs
    enable_resize_to_from_nitro
    log "`date` End - Executing SLES 12 SP2 related pre-requisites" ;;
  SLES12SP3HVM )
    log "`date` Start - Executing SLES 12 SP3 related pre-requisites"
    install_prereq_sles12sp3
    disable_dhcp
    disable_hostname
    start_ntp
    start_fs
    start_oss_configs
    enable_resize_to_from_nitro
    log "`date` End - Executing SLES 12 SP3 related pre-requisites" ;;
  SLES12SP4HVM )
    log "`date` Start - Executing SLES 12 SP4 related pre-requisites"
    install_prereq_sles12sp4
    disable_dhcp
    disable_hostname
    start_ntp
    start_fs
    start_oss_configs
    enable_resize_to_from_nitro
    log "`date` End - Executing SLES 12 SP4 related pre-requisites" ;;
  SLES12SP5HVM )
    log "`date` Start - Executing SLES 12 SP5 related pre-requisites"
    install_prereq_sles12sp5
    disable_dhcp
    disable_hostname
    start_ntp
    start_fs
    start_oss_configs
    enable_resize_to_from_nitro
    log "`date` End - Executing SLES 12 SP5 related pre-requisites" ;;
  SLES15HVM )
    log "`date` Start - Executing SLES 15 related pre-requisites"
    install_prereq_sles15
    disable_dhcp
    disable_hostname
    start_fs
    start_oss_configs
    enable_resize_to_from_nitro
    log "`date` End - Executing SLES 15 related pre-requisites" ;;
  SLES15SP1HVM )
    log "`date` Start - Executing SLES 15 SP1 related pre-requisites"
    install_prereq_sles15sp1
    disable_dhcp
    disable_hostname
    start_fs
    start_oss_configs
    enable_resize_to_from_nitro
    log "`date` End - Executing SLES 15 SP1 related pre-requisites" ;;
  SLES15SP2HVM )
    log "`date` Start - Executing SLES 15 SP2 related pre-requisites"
    install_prereq_sles15sp1
    disable_dhcp
    disable_hostname
    start_fs
    start_oss_configs
    enable_resize_to_from_nitro
    log "`date` End - Executing SLES 15 SP2 related pre-requisites" ;;
  SLES15SP3HVM )
    log "`date` Start - Executing SLES 15 SP3 related pre-requisites"
    install_prereq_sles15sp1
    disable_dhcp
    disable_hostname
    start_fs
    start_oss_configs
    enable_resize_to_from_nitro
    log "`date` End - Executing SLES 15 SP3 related pre-requisites" ;;
  SLES12SP1SAPHVM )
    log "`date` Start - Executing SLES 12 SP1 for SAP related pre-requisites"
    install_prereq_sles12sp1sap
    disable_hostname
    log "`date` End - Executing SLES 12 SP1 for SAP related pre-requisites" ;;
  SLES12SP2SAPHVM )
    log "`date` Start - Executing SLES 12 SP2 for SAP related pre-requisites"
    install_prereq_sles12sp2sap
    start_oss_configs
    disable_hostname
    enable_resize_to_from_nitro
    log "`date` End - Executing SLES 12 SP2 for SAP related pre-requisites" ;;
  SLES12SP3SAPHVM )
    log "`date` Start - Executing SLES 12 SP3 for SAP related pre-requisites"
    install_prereq_sles12sp3sap
    start_oss_configs
    disable_hostname
    enable_resize_to_from_nitro
    fix_slesforsap_suse_repo
    log "`date` End - Executing SLES 12 SP3 for SAP related pre-requisites" ;;
  SLES12SP4SAPHVM )
    log "`date` Start - Executing SLES 12 SP4 for SAP related pre-requisites"
    install_prereq_sles12sp4sap
    start_oss_configs
    disable_hostname
    enable_resize_to_from_nitro
    fix_slesforsap_suse_repo
    log "`date` End - Executing SLES 12 SP4 for SAP related pre-requisites" ;;
  SLES12SP5SAPHVM )
    log "`date` Start - Executing SLES 12 SP5 for SAP related pre-requisites"
    install_prereq_sles12sp5sap
    start_oss_configs
    disable_hostname
    enable_resize_to_from_nitro
    fix_slesforsap_suse_repo
    log "`date` End - Executing SLES 12 SP5 for SAP related pre-requisites" ;;
  SLES15SAPHVM )
    log "`date` Start - Executing SLES 15 for SAP related pre-requisites"
    install_prereq_sles15sap
    start_oss_configs
    disable_hostname
    enable_resize_to_from_nitro
    fix_slesforsap_suse_repo
    log "`date` End - Executing SLES 15 for SAP related pre-requisites" ;;
  SLES15SP1SAPHVM )
    log "`date` Start - Executing SLES 15 SP1 for SAP related pre-requisites"
    install_prereq_sles15sp1sap
    start_oss_configs
    disable_hostname
    enable_resize_to_from_nitro
    fix_slesforsap_suse_repo
    log "`date` End - Executing SLES 15 SP1 for SAP related pre-requisites" ;;
  SLES15SP2SAPHVM )
    log "`date` Start - Executing SLES 15 SP2 for SAP related pre-requisites"
    install_prereq_sles15sp2sap
    start_oss_configs
    disable_hostname
    enable_resize_to_from_nitro
    fix_slesforsap_suse_repo
    log "`date` End - Executing SLES 15 SP2 for SAP related pre-requisites" ;;
  SLES15SP3SAPHVM )
    log "`date` Start - Executing SLES 15 SP3 for SAP related pre-requisites"
    install_prereq_sles15sp3sap
    start_oss_configs
    disable_hostname
    enable_resize_to_from_nitro
    fix_slesforsap_suse_repo
    log "`date` End - Executing SLES 15 SP3 for SAP related pre-requisites" ;;
  SLES12SP1SAPBYOSHVM )
    log "`date` Start - Executing SLES 12 SP1 for SAP BYOS related pre-requisites"
    install_prereq_sles12sp1sapbyos
    disable_dhcp
    disable_hostname
    start_ntp
    start_fs
    start_oss_configs
    log "`date` End - Executing SLES 12 SP1 for SAP BYOS related pre-requisites" ;;
  SLES12SP2SAPBYOSHVM )
    log "`date` Start - Executing SLES 12 SP2 for SAP BYOS related pre-requisites"
    install_prereq_sles12sp2sapbyos
    disable_dhcp
    disable_hostname
    start_ntp
    start_fs
    start_oss_configs
    enable_resize_to_from_nitro
    log "`date` End - Executing SLES 12 SP2 for SAP BYOS related pre-requisites" ;;
  SLES12SP3SAPBYOSHVM )
    log "`date` Start - Executing SLES 12 SP3 for SAP BYOS related pre-requisites"
    install_prereq_sles12sp3sapbyos
    disable_dhcp
    disable_hostname
    start_ntp
    start_fs
    start_oss_configs
    enable_resize_to_from_nitro
    log "`date` End - Executing SLES 12 SP3 for SAP BYOS related pre-requisites" ;;
  SLES12SP4SAPBYOSHVM )
    log "`date` Start - Executing SLES 12 SP4 for SAP BYOS related pre-requisites"
    install_prereq_sles12sp4sapbyos
    disable_dhcp
    disable_hostname
    start_ntp
    start_fs
    start_oss_configs
    enable_resize_to_from_nitro
    log "`date` End - Executing SLES 12 SP4 for SAP BYOS related pre-requisites" ;;
  SLES12SP5SAPBYOSHVM )
    log "`date` Start - Executing SLES 12 SP5 for SAP BYOS related pre-requisites"
    install_prereq_sles12sp5sapbyos
    disable_dhcp
    disable_hostname
    start_ntp
    start_fs
    start_oss_configs
    enable_resize_to_from_nitro
    log "`date` End - Executing SLES 12 SP5 for SAP BYOS related pre-requisites" ;;
  SLES15SAPBYOSHVM )
    log "`date` Start - Executing SLES 15 for SAP BYOS related pre-requisites"
    install_prereq_sles15sapbyos
    disable_dhcp
    disable_hostname
    start_fs
    start_oss_configs
    enable_resize_to_from_nitro
    log "`date` End - Executing SLES 15 for SAP BYOS related pre-requisites" ;;
  SLES15SP1SAPBYOSHVM )
    log "`date` Start - Executing SLES 15 SP1 for SAP BYOS related pre-requisites"
    install_prereq_sles15sp1sapbyos
    disable_dhcp
    disable_hostname
    start_fs
    start_oss_configs
    enable_resize_to_from_nitro
    log "`date` End - Executing SLES 15 SP1 for SAP BYOS related pre-requisites" ;;
  SLES15SP2SAPBYOSHVM )
    log "`date` Start - Executing SLES 15 SP2 for SAP BYOS related pre-requisites"
    install_prereq_sles15sp2sapbyos
    disable_dhcp
    disable_hostname
    start_fs
    start_oss_configs
    enable_resize_to_from_nitro
    log "`date` End - Executing SLES 15 SP2 for SAP BYOS related pre-requisites" ;;
  SLES15SP3SAPBYOSHVM )
    log "`date` Start - Executing SLES 15 SP2 for SAP BYOS related pre-requisites"
    install_prereq_sles15sp3sapbyos
    disable_dhcp
    disable_hostname
    start_fs
    start_oss_configs
    enable_resize_to_from_nitro
    log "`date` End - Executing SLES 15 SP3 for SAP BYOS related pre-requisites" ;;
esac

#install_prereq


log "`date` - Completed HANA Prerequisites installation ## "

exit 0
