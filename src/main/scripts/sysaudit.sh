#!/usr/bin/env bash

# Set shell constraints for safer execution
set -euo pipefail

# This bash script will connect to a defined list of servers and checks the following server information.
# Disk usage, active processes, server up time, server name and kernel version, memory usage and last access users.
# Additionally the script will provide an Alert status if drive space reaches 75% and if a defined list of expected
# ports are not running for specified servers.

# This script runs a heartbeat check each Monday at 5:30 AM and sends out the status info listed above.
# Cron setting - run every monday at 5:30am
# 30 5 * * 1 ~/sysaudit.sh sysuser heartbeat

# Additionally, every four hours the script performs an Alert check and if necessary will send an email alerting the sysadmin.
# Cron setting - every 4 hours
# 0 */4 * * * ~/sysaudit.sh sysuser

# An audit run log is generated for each run. "audit-run.txt"

function setUser() {
  user=$1
}

function checkDiskUsageAlert() {
  while read -r line
  do
    echo "ALERT Disk Space: $1 (`hostname`) $line"
  done < <(timeout 10s df -Ph | awk '0+$5 >= 75 {print}')
}

function checkDiskUsage() {
  timeout 10s df -$1
}

function lastUsers() {
  last | head -$1
}

function checkProcesses() {
  netstat -tlpn
}

function upTime() {
  uptime
}

function uName() {
  uname -a
}

function checkMem() {
  free
}

function getHostName() {
  hostname
}

function checkProcessesAlert() {
  for port in $(echo $2 | tr "|" "\n")
  do
    results=$(netstat -tln | grep $port)
    if [ -z "$results" ]; then
      echo "ALERT Expected Port: $port for $1 (`hostname`) - NOT RUNNING"
    fi
  done
}

function getSSLInfo() {
 host=$1
 port=$2
 echo "####-- Start Get SSL Info --####"
 echo ""
 keytool -printcert -sslserver $host:$port
 echo ""
 echo "Protocol"
 openssl s_client -connect aicig.net:443 | grep "Protocol"
 echo ""
 echo "Cipher"
 openssl s_client -connect aicig.net:443 | grep "Cipher"
 echo ""
 echo "####-- Finish Get SSL Info --####"
}

function serverAlive() {
 port=$1
 echo "####-- Start Check if servers are Online --####"
 echo ""
 for server in "${servers[@]}"
 do
  nc -v -z -w 3 $server $port &> /dev/null && echo "$server Online" || echo "$server Offline"
 done
 echo ""
 echo "####-- Finish Check if servers are Online --####"
}

function runCheck() {

echo "#######################################################################"
echo "START AUDIT CHECK - `date '+%Y-%m-%d %H:%M:%S'`"
echo "#######################################################################"

echo ""
serverAlive 22
echo ""
getSSLInfo localhost 3001
echo ""

for server in "${servers[@]}"
 do
    echo ""
    echo "####-- Connecting to Server: $server with user $user --####"
    echo ""

ssh -T -o ConnectTimeout=30 $user@$server <<EOSSH

    echo ""
    echo -n "#### Start Server: $server - "; $(declare -f getHostName); getHostName
    echo ""

    ## RUN ALERTS for disk space and expected application ports
    $(typeset -f checkDiskUsageAlert); checkDiskUsageAlert $server;
    $(declare -f checkProcessesAlert); checkProcessesAlert $server "${ports[$server]}";
    echo ""

    echo "Mem Check:================================================================>"
    $(typeset -f checkMem); checkMem;
    echo ""

    echo "UpTime Check:==============================================================>"
    $(typeset -f upTime); upTime;
    echo ""

    echo "UName Check:===============================================================>"
    $(typeset -f uName); uName;
    ## RUN ALERTS for disk space and application ports
    echo ""

    echo "Disk Check:===============================================================>"
    $(typeset -f checkDiskUsage); checkDiskUsage h;
    echo ""

    echo "Processes Check:===============================================================>"
    $(typeset -f checkProcesses); checkProcesses;
    echo ""

    echo "Last Users:===============================================================>"
    $(declare -f lastUsers); lastUsers 5;
    echo ""

    echo -n "#### Finished Server: $server - "; $(declare -f getHostName); getHostName
    echo ""
EOSSH
done

  echo "#######################################################################"
  echo "END AUDIT CHECK - `date '+%Y-%m-%d %H:%M:%S'`"
  echo "#######################################################################"
  echo ""

}

# declare indexed array
declare -a servers=("localhost" "127.0.0.1")
# declare associative array
declare -A ports=(["localhost"]="22|53" ["127.0.0.1"]="27017")
setUser $1

auditCheck=$(runCheck)
echo "$auditCheck" > audit-log.txt

if [ $# -eq 2 ]; then
  echo "`date '+%Y-%m-%d %H:%M:%S'` - Send Heartbeat Email" | tee -a audit-run.txt
  java -jar ~/A2T/dev/a2t-audit-email/target/sendemail-a2t-audit-jar-with-dependencies.jar \
     ~/A2T/dev/a2t-audit-email/mail.properties ~/A2T/dev/a2t-audit-email/src/main/scripts/audit-log.txt
elif [[ $auditCheck = *ALERT* ]]
then
  echo "`date '+%Y-%m-%d %H:%M:%S'` - Send Alert Email" | tee -a audit-run.txt
  java -jar ~/A2T/dev/a2t-audit-email/target/sendemail-a2t-audit-jar-with-dependencies.jar \
     ~/A2T/dev/a2t-audit-email/mail.properties ~/A2T/dev/a2t-audit-email/src/main/scripts/audit-log.txt
else
  echo "`date '+%Y-%m-%d %H:%M:%S'` - No Alert Email Needed" | tee -a audit-run.txt
fi

