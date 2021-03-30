#!/bin/bash

# ------------------------------------------------------------------
#	   This script installs HANA, configures HANA instance
# ------------------------------------------------------------------

SCRIPT_DIR=/root/install/

usage() {
    cat <<EOF
    Usage: $0 [options]
	-h print usage
	-p HANA MASTER PASSWD
	-s HANA SID
	-i HANA Instance Number
	-n HANA Master Hostname
	-d Domain
	-l HANA_LOG_FILE [optional]
EOF
    exit 1
}

export USE_NEW_STORAGE=1

# ------------------------------------------------------------------
#	   Read all inputs
# ------------------------------------------------------------------

while getopts ":h:p:s:i:n:d:l:" o; do
    case "${o}" in
	h) usage && exit 0
	    ;;
	p) HANAPASSWORD=${OPTARG}
	    ;;
	s) SID=${OPTARG}
	    ;;
	i) INSTANCE=${OPTARG}
	    ;;
	n) MASTER_HOSTNAME=${OPTARG}
	    ;;
	d) DOMAIN=${OPTARG}
	    ;;
	l)
	   HANA_LOG_FILE=${OPTARG}
	    ;;
	*)
	    usage
	    ;;
    esac
done

# ------------------------------------------------------------------
#	   Make sure all input parameters are filled
# ------------------------------------------------------------------

[[ -z "$HANAPASSWORD" ]]  && echo "input MASTER PASSWD missing" && usage;
[[ -z "$SID" ]]  && echo "input SID missing" && usage;
[[ -z "$INSTANCE" ]]  && echo "input Instance Number missing" && usage;
[[ -z "$MASTER_HOSTNAME" ]]  && echo "input Hostname missing" && usage;
[[ -z "$DOMAIN" ]]  && echo "input Domain name missing" && usage;
shift $((OPTIND-1))
[[ $# -gt 0 ]] && usage;

# ------------------------------------------------------------------
#	   Choose default log file
# ------------------------------------------------------------------

if [ -z "${HANA_LOG_FILE}" ] ; then
    HANA_LOG_FILE=${SCRIPT_DIR}/install.log
fi

# ------------------------------------------------------------------
#	   Pick the right HANA Media!
# ------------------------------------------------------------------

HANAMEDIA=$(/usr/bin/find /media -type d -name "DATA_UNITS")
CUSTOM_CFG_DIR="${SCRIPT_DIR}/custom_config_dir"
mkdir -p ${CUSTOM_CFG_DIR}


log() {
    echo $* 2>&1 | tee -a ${HANA_LOG_FILE}
}

log `date` BEGIN install-hana-master

source /root/install/config.sh

# ------------------------------------------------------------------
#	   Generate Install Files
# ------------------------------------------------------------------

#Password File
PASSFILE=${SCRIPT_DIR}/passwords.xml
echo "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" > ${PASSFILE}
echo "<Passwords>" >> ${PASSFILE}
echo "<password>${HANAPASSWORD}</password>" >> ${PASSFILE}
echo "<sapadm_password>${HANAPASSWORD}</sapadm_password>" >> ${PASSFILE}
echo "<system_user_password>${HANAPASSWORD}</system_user_password>" >> ${PASSFILE}
echo "<root_password>${HANAPASSWORD}</root_password>" >> ${PASSFILE}
echo "</Passwords>" >> ${PASSFILE}


echo '[persistence]' >> ${CUSTOM_CFG_DIR}/global.ini
echo 'basepath_shared = no' >> ${CUSTOM_CFG_DIR}/global.ini
echo 'savepoint_interval_s = 300' >> ${CUSTOM_CFG_DIR}/global.ini
echo 'basepath_databackup = /backup/data/'${SID} >> ${CUSTOM_CFG_DIR}/global.ini
echo 'basepath_logbackup = /backup/log/'${SID} >> ${CUSTOM_CFG_DIR}/global.ini

if [[ "${FastRestartEnabled}" == "Yes" ]]; then
   #
   TMPFS=$(mount | grep '/hana/tmpfs' |  awk '{print $3 }' | xargs | sed -e 's/ /;/g')
   echo 'basepath_persistent_memory_volumes = ' ${TMPFS} >>  ${CUSTOM_CFG_DIR}/global.ini
fi

echo '[communication]' >> ${CUSTOM_CFG_DIR}/global.ini
echo 'listeninterface = .global' >> ${CUSTOM_CFG_DIR}/global.ini
echo 'ssl = systempki' >> ${CUSTOM_CFG_DIR}/global.ini

echo '[scriptserver]' >> ${CUSTOM_CFG_DIR}/daemon.ini
echo 'instances = 1' >> ${CUSTOM_CFG_DIR}/daemon.ini

log '================================================================='
log '================Installing and configuring HANA=================='
log '================================================================='

chmod 777 ${HANAMEDIA}/HDB_LCM_LINUX_X86_64/hdblcm

cat ${PASSFILE} | ${HANAMEDIA}/HDB_LCM_LINUX_X86_64/hdblcm \
    --action=install \
    --components=client,server \
    --batch \
    --autostart=1 \
    --sid=${SID}  \
    --hostname=${MASTER_HOSTNAME} \
    --number=${INSTANCE}  \
    --logpath=/hana/log/${SID} \
    --datapath=/hana/log/${SID} \
    --custom_cfg=${CUSTOM_CFG_DIR} \
    --read_password_from_stdin=xml >> ${HANA_LOG_FILE} 2>&1

# extract the gid used, populate /hana/shared
if (( ${USE_NEW_STORAGE} == 1 )); then
	MISC_CFG_DIR=/hana/shared/${SID}/aws/
else
	MISC_CFG_DIR=/hana/shared/${SID}/aws/
fi
SAPSYS_GROUPID=$(cat /etc/group | grep sapsys | awk -F':' '{print $3}')
log `date` "MASTER NODE picked SAPSYS groupid ${SAPSYS_GROUPID}"
mkdir -p ${MISC_CFG_DIR}
if (( ${USE_NEW_STORAGE} == 1 )); then
	echo "export SAPSYS_GROUPID=${SAPSYS_GROUPID}" >> /hana/shared/${SID}/aws/awscfg.sh
else
	echo "export SAPSYS_GROUPID=${SAPSYS_GROUPID}" >> /hana/shared/${SID}/aws/awscfg.sh
fi
    
#Remove Password file
rm ${PASSFILE}

# ------------------------------------------------------------------
#	   Post HANA install
# ------------------------------------------------------------------

log "$(date) __ done installing HANA DB."..
log "$(date) __ changing the mode of the HANA folders..."

sid=`echo ${SID} | tr '[:upper:]' '[:lower:]'}`
adm="${sid}adm"

chown ${adm}:sapsys -R /backup/data/${SID}
chown ${adm}:sapsys -R /backup/log/${SID}

v_global="/usr/sap/${SID}/SYS/global/hdb/custom/config/global.ini"
v_daemon="/usr/sap/${SID}/SYS/global/hdb/custom/config/daemon.ini"


su - $adm -c "hdbsql  -i ${INSTANCE} \
        -d SystemDB \
        -u SYSTEM \
        -p ${HANAPASSWORD} \
        \"ALTER SYSTEM ALTER CONFIGURATION ('global.ini','SYSTEM') SET ('communication','ssl') = 'systempki' WITH RECONFIGURE\""

#if [ -e "$v_global" ] ; then
#   log "$(date) __ deleting the old entries in $v_global"
#   sed -i '/^\[persistence\]/d' $v_global
#   sed -i '/^basepath_shared/d' $v_global
#   sed -i '/^savepoint_interval_s/d' $v_global
#   sed -i '/^basepath_logbackup/d' $v_global
#   sed -i '/^basepath_databackup/d'  $v_global
#   sed -i '/^basepath_datavolumes/d' $v_global
#   sed -i '/^basepath_logvolumes/d' $v_global
#   sed -i '/^\[communication\]/d' $v_global
#   sed -i '/^listeninterface /d' $v_global
#
#      SP11 FIX
#   sed -i '/^ssl /d' $v_global
#
#fi

#log "$(date) __ inserting the new entries in $v_global"
#echo '[persistence]' >> $v_global
#echo 'basepath_shared = no' >> $v_global
#echo 'savepoint_interval_s = 300' >> $v_global
#echo 'basepath_datavolumes = /hana/data/'${SID} >> $v_global
#echo 'basepath_logvolumes = /hana/log/'${SID} >> $v_global
#echo 'basepath_databackup = /backup/data/'${SID} >> $v_global
#echo 'basepath_logbackup = /backup/log/'${SID} >> $v_global
#echo '' >> $v_global
#echo '[communication]' >> $v_global
#echo 'listeninterface = .global' >> $v_global
#echo 'ssl = systempki' >> $v_global

# Add SSL Configuration parameter for internal communication OSS Note 2175672
# if (( ${HANAVERSION} >=  110 )); then
# echo 'ssl = systempki' >> $v_global
# fi

#if [ -e "$v_daemon" ] ; then
#   log "$(date) __ deleting the old entries in $v_daemon"
#   sed -i '/^\[scriptserver\]/d' $v_daemon
#   sed -i '/^instances/d' $v_daemon
#fi

#log "$(date) __ inserting the new entries in $v_daemon"
#echo '[scriptserver]' >> $v_daemon
#echo 'instances = 1' >> $v_daemon

#chown ${adm}:sapsys $v_daemon

log $(date)' __ done configuring HANA DB!'

su - $adm -c "hdbnsutil -reconfig --hostnameResolution=global"

#Restart after final config
log "Restarting HANA DB after customizing global.ini"
su - ${adm} -c "HDB stop 2>&1"
systemctl restart sap-hana-tmpfs
su - ${adm} -c "HDB start 2>&1"


log `date` END install-hana-master
