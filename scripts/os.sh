# ------------------------------------------------------------------
#          RHEL or SLES
# ------------------------------------------------------------------

source /root/install/config.sh

isRHEL() {
  if [[ "$MyOS" =~ "RHEL" ]]; then
    echo 1
  else
    echo 0
  fi
}

isSLES() {
  if [[ "$MyOS" =~ "SLES" ]]; then
    echo 1
  else
    echo 0
  fi
}


isRHEL6() {
  if [[ "$MyOS" =~ "RHEL6" ]]; then
    echo 1
  else
    echo 0
  fi
}

isRHEL7() {
  if [[ "$MyOS" =~ "RHEL7" ]]; then
    echo 1
  else
    echo 0
  fi
}

isRHEL8() {
  if [[ "$MyOS" =~ "RHEL8" ]]; then
    echo 1
  else
    echo 0
  fi
}

isSLES11SP4() {
    if [ "$MyOS" == "SLES11SP4HVM" ]; then
      echo 1
    else
      echo 0
    fi
}

isSLES12() {
    if [ "$MyOS" == "SLES12HVM" ]; then
      echo 1
    else
      echo 0
    fi
}

isSLES12SP1() {
    if [ "$MyOS" == "SLES12SP1HVM" ]; then
      echo 1
    else
      echo 0
    fi
}

isSLES12SP2() {
    if [ "$MyOS" == "SLES12SP2HVM" ]; then
      echo 1
    else
      echo 0
    fi
}

isSLES12SP4() {
    if [ "$MyOS" == "SLES12SP4HVM" ]; then
      echo 1
    else
      echo 0
    fi
}

isSLES12SP5() {
    if [ "$MyOS" == "SLES12SP5HVM" ]; then
      echo 1
    else
      echo 0
    fi
}

isSLES15() {
    if [ "$MyOS" == "SLES15HVM" ]; then
      echo 1
    else
      echo 0
    fi
}

isSLES15SP1() {
    if [ "$MyOS" == "SLES15SP1HVM" ]; then
      echo 1
    else
      echo 0
    fi
}

isSLES15SP2() {
    if [ "$MyOS" == "SLES15SP2HVM" ]; then
      echo 1
    else
      echo 0
    fi
}

isSLES15SP3() {
    if [ "$MyOS" == "SLES15S32HVM" ]; then
      echo 1
    else
      echo 0
    fi
}

isSLES12SP1SAP() {
    if [ "$MyOS" == "SLES12SP1SAPHVM" ]; then
      echo 1
    else
      echo 0
    fi
}

isSLES12SP2SAP() {
    if [ "$MyOS" == "SLES12SP2SAPHVM" ]; then
      echo 1
    else
      echo 0
    fi
}

isSLES12SP3SAP() {
    if [ "$MyOS" == "SLES12SP3SAPHVM" ]; then
      echo 1
    else
      echo 0
    fi
}

isSLES12SP4SAP() {
    if [ "$MyOS" == "SLES12SP4SAPHVM" ]; then
      echo 1
    else
      echo 0
    fi
}

isSLES12SP5SAP() {
    if [ "$MyOS" == "SLES12SP5SAPHVM" ]; then
      echo 1
    else
      echo 0
    fi
}

isSLES15SAP() {
    if [ "$MyOS" == "SLES15SAPHVM" ]; then
      echo 1
    else
      echo 0
    fi
}

isSLES15SP1SAP() {
    if [ "$MyOS" == "SLES15SP1SAPHVM" ]; then
      echo 1
    else
      echo 0
    fi
}

isSLES15SP2SAP() {
    if [ "$MyOS" == "SLES15SP2SAPHVM" ]; then
      echo 1
    else
      echo 0
    fi
}

isSLES15SP3SAP() {
    if [ "$MyOS" == "SLES15SP3SAPHVM" ]; then
      echo 1
    else
      echo 0
    fi
}

isSLES12SP1SAPBYOS() {
    if [ "$MyOS" == "SLES12SP1SAPBYOSHVM" ]; then
      echo 1
    else
      echo 0
    fi
}

isSLES12SP2SAPBYOS() {
    if [ "$MyOS" == "SLES12SP2SAPBYOSHVM" ]; then
      echo 1
    else
      echo 0
    fi
}

isSLES12SP3SAPBYOS() {
    if [ "$MyOS" == "SLES12SP3SAPBYOSHVM" ]; then
      echo 1
    else
      echo 0
    fi
}

isSLES12SP4SAPBYOS() {
    if [ "$MyOS" == "SLES12SP4SAPBYOSHVM" ]; then
      echo 1
    else
      echo 0
    fi
}

isSLES12SP5SAPBYOS() {
    if [ "$MyOS" == "SLES12SP5SAPBYOSHVM" ]; then
      echo 1
    else
      echo 0
    fi
}

isSLES15SAPBYOS() {
    if [ "$MyOS" == "SLES15SAPBYOSHVM" ]; then
      echo 1
    else
      echo 0
    fi
}

isSLES15SP1SAPBYOS() {
    if [ "$MyOS" == "SLES15SP1SAPBYOSHVM" ]; then
      echo 1
    else
      echo 0
    fi
}

isSLES15SP2SAPBYOS() {
    if [ "$MyOS" == "SLES15SP2SAPBYOSHVM" ]; then
      echo 1
    else
      echo 0
    fi
}

isSLES15SP3SAPBYOS() {
    if [ "$MyOS" == "SLES15SP3SAPBYOSHVM" ]; then
      echo 1
    else
      echo 0
    fi
}

isSLESBYOS() {
  if [[ ("$MyOS" =~ SLES) && ("$MyOS" =~ BYOS) ]]; then
    echo 1
  else
    echo 0
  fi
}

issignal_check() {
    if [ -e "$SIG_FLAG_FILE" ]; then
      echo 1
    else
      echo 0
    fi
}
