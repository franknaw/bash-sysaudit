#!/usr/bin/env bash

# Set shell constraints for safer execution
set -euo pipefail


function setAuth() {
  user=$1
  pass="$(<~/.sdo)"
}
function listCronEntries() {
  echo "tail -n 100 /var/spool/cron/*" > ~/runTemp.sh
  chmod 755 ~/runTemp.sh
  echo "$2" > ~/.temp.txt
  echo $(<.temp.txt) | sudo -S ~/runTemp.sh
  rm ~/runTemp.sh
  rm ~/.temp.txt
}
function getHostName() {
  hostname
}
function checkDiskUsage() {
  df -$1
}
function checkDiskUsageAlert() {
  used=$(df -Ph | awk '0+$5 >= 75 {print}')
 if [[ $used = *[!\ ]* ]]; then
  echo "ALERT Disk Space: $1 (`hostname`) $used"
 fi
}
function checkProcesses() {
  echo "$1" > ~/.temp.txt
  echo $(<.temp.txt) | sudo -S netstat -tlpn
  rm ~/.temp.txt
}
function checkProcessesAlert() {
#results=$(echo "$1" | sudo -S sudo lsof -i :$port)
  for port in $(echo $2 | tr "|" "\n")
  do
    results=$(netstat -tln | grep $port)
    if [ -z "$results" ]; then
      echo "ALERT Expected Port: $port for $1 (`hostname`) - NOT RUNNING"

#      if [[ $port == "8443" ]]; then
#        echo "Restart Jetty for (`hostname`)"
#
#        echo "service jetty stop" > runTemp.sh
#        chmod 755 runTemp.sh
#        echo "$2" > .temp.txt
#        echo $(<.temp.txt) | sudo -S /home/$1/runTemp.sh
#
#        echo "service jetty start" > runTemp.sh
#        chmod 755 runTemp.sh
#        echo "$2" > .temp.txt
#        echo $(<.temp.txt) | sudo -S /home/$1/runTemp.sh
#
#        rm runTemp.sh
#        rm .temp.txt
#      fi

    fi
  done
}
function listLastUsers() {
  echo "last | head -20" > ~/runTemp.sh
  chmod 755 runTemp.sh
  echo "$2" > .temp.txt
  echo $(<.temp.txt) | sudo -S ~/runTemp.sh
  rm ~/runTemp.sh
  rm ~/.temp.txt
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
function checkHttpServer() {
 for server in "${webServers[@]}"
 do
  echo -n "HTTP Server Check - $server - "
  echo -n "Status Code = "; curl -s -o /dev/null -w "%{http_code}" $server
  echo ""
  #echo "Finished HTTP Server Check - $server"
 done
}
function checkAppServer() {
 for server in "${webServers[@]}"
 do
  if [[ $server == *"test"* ]]; then
   uri="cisng/login.LoginForm.doserv"
  else
   uri="cis/login.LoginForm.doserv"
  fi
  echo -n "APP Server Check - $server/$uri - "
  echo -n "Status Code = "; curl -s -o /dev/null -w "%{http_code}" "$server/$uri"
  echo ""
  #echo "Finished APP Server Check - $server/$uri"
 done
}

function runCheck() {

echo "#######################################################################"
echo "START HEALTH CHECK - `date '+%Y-%m-%d %H:%M:%S'`"
echo "#######################################################################"

  echo ""
  checkHttpServer
  checkAppServer
  echo ""

for server in "${servers[@]}"
 do
   echo "Connecting user $user to $server...."

ssh -T -o ConnectTimeout=30 $user@$server <<EOSSH
    echo -n "#### Start Server: $server - "; $(declare -f getHostName); getHostName
    echo ""
    echo "Disk Check:===============================================================>"
    echo "**By Block: "; $(typeset -f checkDiskUsage); checkDiskUsage h;
    echo "**By Inodes: "; $(typeset -f checkDiskUsage); checkDiskUsage ih;
    echo ""
    echo "Cron Entries:=============================================================>"
    $(declare -f listCronEntries); listCronEntries $user $pass;
    echo ""
    echo "Check Processes:==========================================================>"
    $(declare -f checkProcesses); checkProcesses $pass;
    echo ""
    echo "Last Users:===============================================================>"
    $(declare -f listLastUsers); listLastUsers $user $pass;
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
    $(typeset -f checkDiskUsageAlert); checkDiskUsageAlert $server;
    $(declare -f checkProcessesAlert); checkProcessesAlert $server "${ports[$server]}";
    echo ""
    echo -n "#### Finished Server: $server - "; $(declare -f getHostName); getHostName
    echo ""
EOSSH
done


  echo "#######################################################################"
  echo "END HEALTH CHECK - `date '+%Y-%m-%d %H:%M:%S'`"
  echo "#######################################################################"
  echo ""

}
function emailAlerts() {
  alertLogFile=$(ls -t logs/HealthCheckAlert* | head -1)
  logFile=$(ls -t logs/HealthCheck-* | head -1)

  if [ -n "$alertLogFile" ]; then
    if [ -s "$alertLogFile" ]; then
      echo "Email $alertLogFile"
      cat $alertLogFile | mail -s "ALERT ALERT - Health Check" $email
    fi
  fi

  if [ -n "$logFile" ]; then
    echo "Email $logFile"
    cat $logFile | mail -s "Health Check Log" $email
  fi

  #rm $alertLogFile
  #rm $logFile
}


#################################################
# Set server ip's, app servers, log file name with out/err/console
# prod app, prod web, prod db, test web, test db, backup, cas, test app
declare -a servers=("dcis-app-prod" "dcis-app-test")
declare -a webServers=("https://dcis.hhs.gov" "https://test.dcis.hhs.gov")
declare -A ports=(["dcis-app-prod"]="443|80|11529|8443|8080" ["dcis-app-test"]="1521|10225")
logFile="HealthCheck-`date '+%Y-%m-%d_%H-%M-%S'`.log"
alertLogFile="HealthCheckAlert-`date '+%Y-%m-%d_%H-%M-%S'`.log"
setAuth "dcisalert"
email=user@atsomeemail.com
#setAuth $1 $2

# Check arguments
if [ "$1" == "alert" ]; then
  emailAlerts
elif [ $# -eq 2 ]; then
  runCheck | tee "logs/$logFile" | grep "ALERT" >> "logs/$alertLogFile"
else
  echo "Please enter a username and password!"
  echo "Example: $0 myuser mypass"
fi