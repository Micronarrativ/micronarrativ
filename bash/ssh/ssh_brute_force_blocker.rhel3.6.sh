#!/bin/bash
# === [*Introduction*]
#
# Source: http://seclists.org/fulldisclosure/2005/Sep/27
#
# ssh_brute_blocker
#
# === [*Credits*]
#
# 05/07/2004 15:05 - Michael L. Benjamin
# 21/08/2014 08:46 - Daniel Roos (updated)
#
#
# === [*Limitations*]
#
# Tested on RHEL 3.6
#
#
# === [*Parameters*]
#
# The parameters are being set in the script, no handed over through the
# command line.
#
# [*SCRIPT_NAME*]
#   Name of the script file. Shows up in `/var/log/messages` as source of the
#   entry.
#
# [*DEBUG*]
#   Boolean switch (0/1) to switch on/off additional debugging messages on the
#   console.
#
# [*SLEEPSECONDS*]
#   Integer with number of seconds between the checks.
#
# [*PRIVATE_NETWORKS*]
#   Array with network address ranges to be ignored. This will avoud locking
#   yourself out of the server if you are coming from a private IP.
#
# [*LOG_FILE*]
#   Path to the log file to monitor. Usually this is `/var/log/secure`.
#
# [*DENY_FILE*]
#   Path to the hosts.deny file. Usually this is `/etc/hosts.deny`.
#
# [*TMP_FILE*]
#   Path to a temporary file. This value is created randomly.
#
# [*INBOUND_IP*]
#   Variable containing the inbound IP address from the logfile to monitor.
#   Initially this variable is empty.
#
# [*GUESS_COUNT*]
#   Integer variable containing the number of SSH credentials guesses found in the
#   logfile. Initially this variable is zero
#
# [*PERMIT_GUESS*]
#   Integer variable containing the number of maximal wrong guesses allowed before
#   the host will be blocked.
#
# === [*Usage*]
#
# Add it to `/etc/rc.local` to get it running in the background like this:
#
#   /etc/rc.local
#   ------------
#   /usr/local/scripts/ssh_brute_blocker &
#
SCRIPT_NAME=$(basename $0)
DEBUG=1
SLEEPSECONDS=10
PRIVATE_NETWORKS=(
    '10.'
    '169.254'
    '172.16.'
    '172.17.'
    '172.18.'
    '172.19.'
    '172.20.'
    '172.21.'
    '172.22.'
    '172.23.'
    '172.24.'
    '172.25.'
    '172.26.'
    '172.27.'
    '172.28.'
    '172.29.'
    '172.30.'
    '172.31.'
    '192.168.'
    )
LOG_FILE="/var/log/secure"
DENY_FILE="/etc/hosts.deny"
TMP_FILE=$(mktemp)
INBOUND_IP=''
GUESS_COUNT=0
PERMIT_GUESS=4

touch ${TMP_FILE}
chmod 700 ${TMP_FILE}
chown root:root ${TMP_FILE}

[ $DEBUG -eq 1 ] && echo "Debugging enabled"
while :
do

  tail -1000 ${LOG_FILE} | awk -F"from" '/Failed password for illegal user/'{'print $2'} | awk {'print $1'}| uniq > ${TMP_FILE}

  while read -r INBOUND_IP
  do
    for i in ${PRIVATE_NETWORKS}; do

        if [[ `echo ${INBOUND_IP} | grep -E "${i}"` ]]; then            # Bash on RHEL is too old to know '=~'
            [ $DEBUG -eq 1 ] && echo "Inbound IP (${INBOUND_IP}) triggered, but is a private Network. Ignoring."
            continue 2
        fi
    done

    GUESS_COUNT=$(grep 'Failed password for .*'"from ${INBOUND_IP}" /var/log/secure | wc -l)
    [ $DEBUG -eq 1 ] && GUESS_COUNT=$(grep ${INBOUND_IP} ${LOG_FILE} | wc -l)
    [ $DEBUG -eq 1 ] && echo "IP: ${INBOUND_IP} made ${GUESS_COUNT} guesses against our server."

    if [ ${GUESS_COUNT} -ge ${PERMIT_GUESS} ]; then
        if grep ${INBOUND_IP} ${DENY_FILE} > /dev/null; then
           [ $DEBUG -eq 1 ] && echo "${INBOUND_IP} is already listed in ${DENY_FILE}"
            echo > /dev/null
        else
           [ $DEBUG -eq 1 ] && echo "${INBOUND_IP} is not listed. Adding host ${INBOUND_IP} to ${DENY_FILE}."
            echo "ALL: ${INBOUND_IP}" >> ${DENY_FILE}
            /usr/bin/logger -t ssh_brute_blocker -is ${SCRIPT_NAME}: Added SSH attacking host ${INBOUND_IP} to ${DENY_FILE} [${GUESS_COUNT} attempts].
        fi
    else
        [ $DEBUG -eq 1 ] && echo "Ignoring host ${INBOUND_IP} less than ${PERMIT_GUESS} wrong guesses."
        echo > /dev/null
    fi

  done < ${TMP_FILE}

  sleep ${SLEEPSECONDS}

  rm -f ${TMP_FILE}

done

exit 0
