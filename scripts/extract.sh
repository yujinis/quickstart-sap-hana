#!/bin/bash

# ------------------------------------------------------------------
#          This script extracts media from /media/compressed
# ------------------------------------------------------------------

SCRIPT_DIR=/root/install/

usage() {
    cat <<EOF
    Usage: $0 [options]
        -h print usage
EOF
    exit 1
}

if [ -z "${HANA_LOG_FILE}" ] ; then
    HANA_LOG_FILE=${SCRIPT_DIR}/install.log
fi

log() {
    echo $* 2>&1 | tee -a ${HANA_LOG_FILE}
}

command_exists () {
    type "$1" &> /dev/null ;
}

EXTRACT_DIR=/media/extracted/
COMPRESS_DIR=/media/compressed/
source /root/install/config.sh
HANA_MEDIA_EXE_FILE=$(/usr/bin/find ${COMPRESS_DIR}  -iname '*.exe')
HANA_MEDIA_ZIP_FILE=$(/usr/bin/find ${COMPRESS_DIR}  -iname '*.zip')

mkdir -p ${EXTRACT_DIR}

if [[ ! -z ${HANA_MEDIA_EXE_FILE} ]] ; then
  if command_exists unrar ; then
    /usr/bin/unrar x ${HANA_MEDIA_EXE_FILE} ${EXTRACT_DIR}
  else
# ------------------------------------------------------------------
#   At the time of writing, marketplace RHEL and marketplace SLES
#	did not have unrar package. As a workaround, we download as below
#   TODO: This is a temporary workaround and needs to be fixed in AMI
# ------------------------------------------------------------------
     log "`date` Downloading from repoforge."
     mkdir -p /root/install/misc
     wget http://www.rarlab.com/rar/unrar-5.0-RHEL5x64.tar.gz -O /root/install/misc/unrar-5.0-RHEL5x64.tar.gz
     (cd /root/install/misc && tar xvf /root/install/misc/unrar-5.0-RHEL5x64.tar.gz && chmod 755 /root/install/misc/unrar)
     /root/install/misc/unrar x ${HANA_MEDIA_EXE_FILE} ${EXTRACT_DIR}
  fi
elif [[ ! -z ${HANA_MEDIA_ZIP_FILE} ]] ; then
  log "`date` Extracting SAP HANA Media files"
  unzip ${HANA_MEDIA_ZIP_FILE} -d ${EXTRACT_DIR}
else
  log "`date` Warning - Correct SAP HANA media files not found in compressed directory. Check your media folder."
fi
