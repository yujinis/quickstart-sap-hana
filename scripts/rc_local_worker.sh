#!/bin/bash
# ------------------------------------------------------------------
#
#          Install SAP HANA Master Node
#		   invoked once via cloudformation call through user-data
# ------------------------------------------------------------------

sleep 20

SCRIPT_DIR=/root/install/

[ -e /root/install/jq ] && export JQ_COMMAND=/root/install/jq
[ -z ${JQ_COMMAND} ] && export JQ_COMMAND=/home/ec2-user/jq
export PATH=${PATH}:/sbin:/usr/sbin:/usr/local/sbin:/root/bin:/usr/local/bin:/usr/bin:/bin:/usr/bin/X11:/usr/X11R6/bin:/usr/games:/usr/lib/AmazonEC2/ec2-api-tools/bin:/usr/lib/AmazonEC2/ec2-ami-tools/bin:/usr/lib/mit/bin:/usr/lib/mit/sbin
myInstance=$(curl -s http://169.254.169.254/latest/dynamic/instance-identity/document/ | ${JQ_COMMAND} '.instanceType' | \
			 sed 's/"//g')

[ -e /root/install/config.sh ] && source /root/install/config.sh
[ -e /root/install/os.sh ] && source /root/install/os.sh

# ------------------------------------------------------------------
#          Choose default log file
# ------------------------------------------------------------------

log() {
	echo $* 2>&1 | tee -a ${HANA_LOG_FILE}
}

if [ -z "${HANA_LOG_FILE}" ] ; then
    HANA_LOG_FILE=${SCRIPT_DIR}/install.log
fi

MyHostname=$(hostname)
GetSecretCmd="aws secretsmanager get-secret-value --secret-id ${MyStackName} --output json --region ${REGION}"
HANAMasterPass=$(${GetSecretCmd} | ${JQ_COMMAND} .SecretString | sed -e 's/\"//g')

sh /root/install/cluster-watch-engine.sh -c
sh /root/install/cluster-watch-engine.sh -i "DomainName=${DomainName}"
sh /root/install/cluster-watch-engine.sh -i "MyHostname=${MyHostname}"
sh /root/install/cluster-watch-engine.sh -i "MyRole=Worker"
sh /root/install/cluster-watch-engine.sh -i "HostCount=${HostCount}"
sh /root/install/cluster-watch-engine.sh -s "PRE_INSTALL_COMPLETE"
sh /root/install/reconcile-ips.sh ${HostCount}
sh /root/install/fence-cluster.sh -w "PRE_INSTALL_COMPLETE_ACK=${HostCount}"
sh /root/install/wait-for-master.sh
sh /root/install/install-worker.sh -s ${SID} -p ${HANAMasterPass} -n ${HANAMasterHostname} -d ${DomainName}
sh /root/install/cluster-watch-engine.sh -s "WORKER_NODE_COMPLETE"
sh /root/install/wait-for-workers.sh ${HostCount}
sh /root/install/cleanup.sh &

if [ -f /etc/init.d/boot.local.bkup.QS ]; then
	# Restore original file
	rm -fr /etc/init.d/boot.local
	mv -f /etc/init.d/boot.local.bkup.QS /etc/init.d/boot.local
elif [ -f /etc/rc.d/rc.local.bkup.QS ]; then
	# Restore original file
	rm -fr /etc/rc.d/rc.local
	mv -f /etc/init.d/rc.local.bkup.QS /etc/rc.d/rc.local
fi
