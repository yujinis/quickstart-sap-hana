#!/bin/bash


# ------------------------------------------------------------------
# 			Creates volume and waits for it to finish
#			Input specified as #Vols x #size x #Type x #starting dir
# ------------------------------------------------------------------



[ -e /root/install/jq ] && export JQ_COMMAND=/root/install/jq
[ -z ${JQ_COMMAND} ] && export JQ_COMMAND=/home/ec2-user/jq

export PATH=${PATH}:/sbin:/usr/sbin:/usr/local/sbin:/root/bin:/usr/local/bin:/usr/bin:/bin:/usr/bin/X11:/usr/X11R6/bin:/usr/games:/usr/lib/AmazonEC2/ec2-api-tools/bin:/usr/lib/AmazonEC2/ec2-ami-tools/bin:/usr/lib/mit/bin:/usr/lib/mit/sbin

usage() {
    cat <<EOF
Usage: $0 #size:Type:{#PIOPS}:DeviceStart:Name
Examples: 20:gp2:/dev/sdb:node [ 1 gp2 EBS, 20 GB , /dev/sdb
Examples: 12:standard:/dev/sdb:node [ 1 standard EBS, 12 GB , /dev/sdb
Examples: 12:io1:5000:/dev/sdb:node [ 1 PIOPS vol, 5000 IoPS, 12 GB , /dev/sdb
EOF
    exit 0
}


# ------------------------------------------------------------------
#          Read all inputs
# ------------------------------------------------------------------

[[ $# -ne 1 ]] && usage;
ARGS_LIST=$1

[ -e /root/install/config.sh ] && source /root/install/config.sh
export AWS_DEFAULT_REGION=${REGION}
export AWS_DEFAULT_AVAILABILITY_ZONE=${AVAILABILITY_ZONE}


if [ -z ${AWS_DEFAULT_REGION} ]; then
	 export AWS_DEFAULT_REGION=$(curl -s http://169.254.169.254/latest/dynamic/instance-identity/document \
					| ${JQ_COMMAND} '.region'  \
					| sed 's/^"\(.*\)"$/\1/' )
fi
if [ -z ${AWS_DEFAULT_AVAILABILITY_ZONE} ]; then
	 export AWS_DEFAULT_AVAILABILITY_ZONE=$(curl -s http://169.254.169.254/latest/dynamic/instance-identity/document \
						| ${JQ_COMMAND} '.availabilityZone' \
						| sed 's/^"\(.*\)"$/\1/' )
fi

if [ -z ${AWS_INSTANCEID} ]; then
	 export AWS_INSTANCEID=$(curl -s http://169.254.169.254/latest/dynamic/instance-identity/document \
						| ${JQ_COMMAND} '.instanceId' \
						| sed 's/^"\(.*\)"$/\1/' )
fi


# ------------------------------------------------------------------
#          remove double quotes, if any. cli doesn't like it!
# ------------------------------------------------------------------

export AWS_DEFAULT_REGION=$(echo ${AWS_DEFAULT_REGION} | sed 's/^"\(.*\)"$/\1/' )
export AWS_DEFAULT_AVAILABILITY_ZONE=$(echo ${AWS_DEFAULT_AVAILABILITY_ZONE} | sed 's/^"\(.*\)"$/\1/' )
export AWS_INSTANCEID=$(echo ${AWS_INSTANCEID} | sed 's/^"\(.*\)"$/\1/' )

export AWS=${AWSCLI_BIN}

# ------------------------------------------------------------------
#          Choose default log file
# ------------------------------------------------------------------
SCRIPT_DIR=/root/install/
SCRIPT_DIR=./
if [ -z "${HANA_LOG_FILE}" ] ; then
    HANA_LOG_FILE=${SCRIPT_DIR}/install.log
fi
log() {
	if [ -e /root/install/config.sh ]; then
		echo $* 2>&1 |  tee -a ${HANA_LOG_FILE}
	else
		echo $* 2>&1
	fi
}


# ------------------------------------------------------------------
#          Wait until volume status says "ok"
# ------------------------------------------------------------------
wait_for_volume_create () {
   local volumeid="$1"
    while true; do
		status=$(${AWS} ec2 describe-volume-status --volume-ids ${volumeid}  | \
				${JQ_COMMAND} '.VolumeStatuses[].VolumeStatus.Status' )
		echo ${volumeid}:${status}
        case "$status" in
			*ok* ) break;;
        esac
		sleep 10
	done
	log ${volumeid}:"ok"
}

# ------------------------------------------------------------------
#          Wait until volume attach to say "okay"
# ------------------------------------------------------------------
wait_for_attach_volume () {
   local volumeid="$1"
    while true; do
		status=$(${AWS} ec2 describe-volumes --volume-ids ${volumeid}  | \
				${JQ_COMMAND} '.Volumes[].Attachments[].State' )
		echo ${volumeid}:${status}
        case "$status" in
			*attached* ) break;;
        esac
		sleep 10
	done
	log ${volumeid}:"attached"
}


# ------------------------------------------------------------------
#          Wait until volume attach to say "okay"
# ------------------------------------------------------------------
attach_and_wait_for_attach_volume () {
   local volumeid="$1"
   local device="$2"

   counter=0
   MAX_COUNTER=24

    while true; do
    	((counter++))
    	if (( counter > MAX_COUNTER))
    	then
    		echo "MAX_COUNTER Violated in attach_and_wait_for_attach_volume"
    		break
    	else
	#  This will throw an error and it's okay. See too soon issue below
			status=$(${AWS} ec2 describe-volumes --volume-ids ${volumeid}  | \
					${JQ_COMMAND} '.Volumes[].Attachments[].State' )
			echo ${volumeid}:${status}
	        case "$status" in
				*attached* ) break;;
	        esac
	        if [ "${status}" != "attaching" ]
	        then
	        	echo "Will try attaching vol now"
		    	echo "${AWS} ec2 attach-volume --volume-id ${volumeid} --instance-id ${AWS_INSTANCEID} --device ${device}"
		    	${AWS} ec2 attach-volume --volume-id ${volumeid} --instance-id ${AWS_INSTANCEID} --device ${device}
		    fi
			sleep 10
		fi
	done
	log ${volumeid}:"attached"
}

# ------------------------------------------------------------------
#          Change device attribute to "delete on termination"
# ------------------------------------------------------------------
set_device_delete_ontermination () {
	local device="$1"
    blkdev_template='"[{\"DeviceName\":\"DEVICE_STRING\",\"Ebs\":{\"DeleteOnTermination\":true}}]"'

	blkdev_json=$(echo -n ${blkdev_template} | sed "s:DEVICE_STRING:$device:")
	echo ${AWS} ec2 modify-instance-attribute --instance-id ${AWS_INSTANCEID} --block-device-mappings ${blkdev_json} | sh
	log ${device}->"DeleteOnTermination:True"
}

# ------------------------------------------------------------------
#          Find NVME device ID if Applicable
# ------------------------------------------------------------------
find_nvme_device_id() {
nvme_vol_id=$(echo $1 | sed -e 's/-//g')
nvme_id=$(nvme list | grep $nvme_vol_id | awk '{print $1}')
if [ ! -z "$nvme_id" ]
then
    echo $nvme_id > /root/install/nvme_id
else
    rm /root/install/nvme_id
fi
}

log `date` BEGIN Creating Volumes and Attaching ${ARGS_LIST}

ARGS_LIST_ARRAY=(${ARGS_LIST//:/ })
VOL_SIZE=${ARGS_LIST_ARRAY[0]}
VOL_TYPE=${ARGS_LIST_ARRAY[1]}
VOL_PIOPS=


[ -z ${VOL_SIZE} ] && usage;
[ -z ${VOL_TYPE} ] && usage;

if [[ "${VOL_TYPE}" == "io1" || "${VOL_TYPE}" == "io2" ]] ; then
    VOL_PIOPS=${ARGS_LIST_ARRAY[2]}
	DEVICE_START=${ARGS_LIST_ARRAY[3]}
	VOL_NAME=${ARGS_LIST_ARRAY[4]}
	[ -z ${VOL_PIOPS} ] && usage;
elif [[ "${VOL_TYPE}" == "gp3" ]]; then
    VOL_PIOPS=${ARGS_LIST_ARRAY[2]}
    VOL_THROUGHPUT=${ARGS_LIST_ARRAY[3]}
    DEVICE_START=${ARGS_LIST_ARRAY[4]}
    VOL_NAME=${ARGS_LIST_ARRAY[5]}
    [ -z ${VOL_PIOPS} ] && usage;
    [ -z ${VOL_THROUGHPUT} ] && usage;
else
	DEVICE_START=${ARGS_LIST_ARRAY[2]}
	VOL_NAME=${ARGS_LIST_ARRAY[3]}
fi

[ -z ${DEVICE_START} ] && usage;
[ -z ${VOL_NAME} ] && usage;

MyInstanceType=$(${AWSCLI_BIN} cloudformation describe-stacks --stack-name ${MyStackId}  --region ${REGION}  \
				| /root/install/jq '.Stacks[0].Parameters[] | select(.ParameterKey=="MyInstanceType") | .ParameterValue' \
				| sed 's/"//g')

MyEncryption=$(${AWSCLI_BIN} cloudformation describe-stacks --stack-name ${MyStackId}  --region ${REGION}  \
				| /root/install/jq '.Stacks[0].Parameters[] | select(.ParameterKey=="Encryption") | .ParameterValue' \
				| sed 's/"//g')

if [[ ${MyEncryption} == "No" ]];
then
	if [[ "${VOL_TYPE}" == "io1" || "${VOL_TYPE}" == "io2" ]]; then
		volumeid=$(${AWS} ec2 create-volume \
					--region ${AWS_DEFAULT_REGION} \
					--availability-zone ${AWS_DEFAULT_AVAILABILITY_ZONE} \
					--size ${VOL_SIZE} \
					--volume-type ${VOL_TYPE} --iops ${VOL_PIOPS} \
					--tag-specification ResourceType=volume,Tags=[\{Key=SAPHANAQuickStart,Value=${MyStackId}\}] \
					| ${JQ_COMMAND} '.VolumeId' )
    elif [[ "${VOL_TYPE}" == "gp3" ]]; then
               volumeid=$(${AWS} ec2 create-volume \
                    --region ${AWS_DEFAULT_REGION} \
                    --availability-zone ${AWS_DEFAULT_AVAILABILITY_ZONE} \
                    --size ${VOL_SIZE} \
                    --iops ${VOL_PIOPS} \
                    --throughput ${VOL_THROUGHPUT} \
                    --volume-type ${VOL_TYPE} \
                    --tag-specification ResourceType=volume,Tags=[\{Key=SAPHANAQuickStart,Value=${MyStackId}\}] \
                    | ${JQ_COMMAND} '.VolumeId')
	else
		volumeid=$(${AWS} ec2 create-volume \
					--region ${AWS_DEFAULT_REGION} \
					--availability-zone ${AWS_DEFAULT_AVAILABILITY_ZONE} \
					--size ${VOL_SIZE} \
					--volume-type ${VOL_TYPE} \
					--tag-specification ResourceType=volume,Tags=[\{Key=SAPHANAQuickStart,Value=${MyStackId}\}] \
					| ${JQ_COMMAND} '.VolumeId')
	fi
else
	if [[ "${VOL_TYPE}" == "io1" || "${VOL_TYPE}" == "io2" ]]; then
		volumeid=$(${AWS} ec2 create-volume \
					--region ${AWS_DEFAULT_REGION} \
					--availability-zone ${AWS_DEFAULT_AVAILABILITY_ZONE} --encrypted \
					--size ${VOL_SIZE} \
					--volume-type ${VOL_TYPE} --iops ${VOL_PIOPS} \
					--tag-specification ResourceType=volume,Tags=[\{Key=SAPHANAQuickStart,Value=${MyStackId}\}] \
					| ${JQ_COMMAND} '.VolumeId')
    elif [[ "${VOL_TYPE}" == "gp3" ]]; then
               volumeid=$(${AWS} ec2 create-volume \
                    --region ${AWS_DEFAULT_REGION} \
                    --availability-zone ${AWS_DEFAULT_AVAILABILITY_ZONE} --encrypted \
                    --size ${VOL_SIZE} \
                    --iops ${VOL_PIOPS} \
                    --throughput ${VOL_THROUGHPUT} \
                    --volume-type ${VOL_TYPE} \
                    --tag-specification ResourceType=volume,Tags=[\{Key=SAPHANAQuickStart,Value=${MyStackId}\}] \
                    | ${JQ_COMMAND} '.VolumeId')
	else
		volumeid=$(${AWS} ec2 create-volume \
					--region ${AWS_DEFAULT_REGION} \
					--availability-zone ${AWS_DEFAULT_AVAILABILITY_ZONE} --encrypted \
					--size ${VOL_SIZE} \
					--volume-type ${VOL_TYPE}\
					--tag-specification ResourceType=volume,Tags=[\{Key=SAPHANAQuickStart,Value=${MyStackId}\}] \
					| ${JQ_COMMAND} '.VolumeId')
	fi
fi

	volumeid=$(echo ${volumeid} | sed 's/^"\(.*\)"$/\1/')
	log "Creating new volume ${volumeid}. Waiting for create"
	wait_for_volume_create ${volumeid}
	device=${DEVICE_START}
#	Attach volume to the instance and expose with the specified device name
	log "Attaching new volume ${volumeid} as ${device}. Waiting for attach"

# ------------------------------------------------------------------
#  Note: Wierd "too soon" issue
#   At the time of writing, there seems to be an issue attaching a volume
#   right after getting okay from create. Wierd.
#   I loop attach on same device, thought it will throw an error
# ------------------------------------------------------------------

	#${AWS} ec2 attach-volume --volume-id ${volumeid} --instance-id ${AWS_INSTANCEID} --device ${device}
	#wait_for_attach_volume ${volumeid}
	attach_and_wait_for_attach_volume ${volumeid} ${device}
	log "setting device attribute  ${device}:DeleteOnTermination"
	set_device_delete_ontermination ${device}
	log "setting device name  ${device}:$VOL_NAME"
	${AWS} ec2 create-tags --resources ${volumeid}  --tags Key=Name,Value=${VOL_NAME}
    find_nvme_device_id ${volumeid}

  log `date` END Creating Volumes and Attaching ${ARGS_LIST}
