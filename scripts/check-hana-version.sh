#!/bin/bash

# ------------------------------------------------------------------
#          This script checks SAP HANA version and compatibility
#           return codes:
#               0 - success
#               1 - error
#               2 - warning
# ------------------------------------------------------------------

[ -e /root/install/config.sh ] && source /root/install/config.sh
[ -e /root/install/os.sh ] && source /root/install/os.sh

# ------------------------------------------------------------------
# Global vars...
# ------------------------------------------------------------------

SCRIPT_DIR=/root/install/
HANAMEDIA=$(/usr/bin/find /media -type d -name "DATA_UNITS")
DB_FILE="support_matrix.db"
DB="support_matrix"
EXTRACT_DIR=/media/extracted/
COMPRESS_DIR=/media/compressed/
HANA_MEDIA_EXE_FILE=$(/usr/bin/find ${COMPRESS_DIR}  -iname '*.exe')
HANA_MEDIA_ZIP_FILE=$(/usr/bin/find ${COMPRESS_DIR}  -iname '*.zip')
OS=$(echo ${MyOS} | sed -E -e 's/SAP.*|HVM$//g')

# ------------------------------------------------------------------
#          Choose default log file
# ------------------------------------------------------------------

if [ -z "${HANA_LOG_FILE}" ] ; then
    HANA_LOG_FILE=${SCRIPT_DIR}/install.log
fi

# ------------------------------------------------------------------
#          Basic functions
# ------------------------------------------------------------------

usage() {
    cat <<EOF
    Usage: $0 [options]
        -h print usage
        -v return SAP HANA version
        -s return SAP HANA SPS version
        -r return SAP HANA rev version
        -c check SAP HANA compatibility with OS
EOF
    exit 1
}

log() {
    echo $* 2>&1 | tee -a ${HANA_LOG_FILE} > /dev/null
}

detect_HANA_info() {
    #
    info_needed=$1
    #
    if [[ ! -z ${HANA_MEDIA_EXE_FILE} ]] ; then
        # It is a RAR file
        if [[ ${info_needed} == "rev" ]]; then
            /usr/bin/unrar p ${HANA_MEDIA_EXE_FILE} */CDLABEL.ASC | egrep -oi 'rev[0-9][0-9]|rev[[:space:]][0-9][0-9]'
        elif [[ ${info_needed} == "SPS" ]]; then
            /usr/bin/unrar p ${HANA_MEDIA_EXE_FILE} */CDLABEL.ASC | egrep -oi 'SPS[0-9][0-9]|SPS[[:space:]][0-9][0-9]'
        elif [[ ${info_needed} == "version" ]]; then
            /usr/bin/unrar p ${HANA_MEDIA_EXE_FILE} */CDLABEL.ASC | egrep -ow '1.0|2.0'
        fi
    elif [[ ! -z ${HANA_MEDIA_ZIP_FILE} ]] ; then
        # It is a ZIP file
        if [[ ${info_needed} == "rev" ]]; then
            unzip -p ${HANA_MEDIA_ZIP_FILE} CDLABEL.ASC | egrep -oi 'rev[0-9][0-9]|rev[[:space:]][0-9][0-9]'
        elif [[ ${info_needed} == "SPS" ]]; then
            unzip -p ${HANA_MEDIA_ZIP_FILE} CDLABEL.ASC | egrep -oi 'SPS[0-9][0-9]|SPS[[:space:]][0-9][0-9]'
        elif [[ ${info_needed} == "version" ]]; then
            unzip -p ${HANA_MEDIA_ZIP_FILE} CDLABEL.ASC | egrep -ow '1.0|2.0'
        fi
    fi
}

check_hana_compat() {
    #
    HANA_SPS=$(detect_HANA_info "SPS")
    HANA_SPS_VER=$(echo ${HANA_SPS} | tr [:lower:] [:upper:] | tr -d 'SPS')
    HANA_REV=$(detect_HANA_info "rev" | tr [:upper:] [:lower:] | tr -d 'rev')
    HANA_REV=${HANA_REV:=00}
    MIN_SPS=$(sqlite3 ${DB_FILE} "select HANASPS from ${DB} where OS='${OS}'" | grep -o ${HANA_SPS})
    MIN_SPS_VER=$(echo ${MIN_SPS} | tr -d 'SPS')
    MIN_REV=$(sqlite3 ${DB_FILE} "select REV from ${DB} where OS='${OS}' and HANASPS='${MIN_SPS}'")
    MIN_REV=${MIN_REV:=00}
    #
    if [ ! -z ${MIN_SPS} ]; then
        #
        if [[ ! -n ${MIN_REV} || ${HANA_REV} == 00 ]]; then
        log "`date` - check-hana-version No revision to check"
        elif [ ${HANA_REV} -ge ${MIN_REV} ]; then
            log "`date` - check-hana-version - SAP HANA revision is supported with ${OS}"
        else
            log "`date` - check-hana-version - WARNING: SAP HANA SPS Revision is not supported with ${OS}"
            log "`date` END check-hana-version"
            exit 2
        fi
        #
        if [ ${HANA_SPS_VER} -ge ${MIN_SPS_VER} ]; then
            log "`date` - check-hana-version - SAP HANA SPS is supported with ${OS}"
        else
            log "`date` - check-hana-version - WARNING: HANA SPS is not supported with ${OS}"
            log `date` END - check-hana-version
            exit 2
        fi
    else
        log "`date` - check-hana-version - WARNING: HANA SPS is not supported with ${OS}"
        log `date` END - check-hana-version
        exit 2
    fi
}

print_info() {
   #
   log "SAP HANA SPS detected on media.....: ${HANA_SPS}"
   log "SAP HANA SPS supported.............: ${MIN_SPS} (${OS})"
   #
   log "SAP HANA Rev detected on media.....: ${HANA_REV}"
   log "SAP HANA Rev supported.............: ${MIN_REV} (${OS})"
   #
}

# ------------------------------------------------------------------
#          Make sure all input parameters are filled
# ------------------------------------------------------------------

[[ -z "${OS}" ]]  && echo "input Operating System name missing" && exit 1;

log `date` - BEGIN check-hana-version

while getopts ":hvsrc" o; do
    case "${o}" in
                h)
                        usage && exit 0
                        ;;
                v)
                        detect_HANA_info "version"
                        ;;
                s)
                        detect_HANA_info "SPS"
                        ;;
                r)
                        detect_HANA_info "rev"
                        ;;
                c)
                        check_hana_compat
                        ;;
                *)
                        usage && exit 0
                        ;;
    esac;
done

shift $((OPTIND-1))

# ------------------------------------------------------------------

log `date` END - check-hana-version
exit 0