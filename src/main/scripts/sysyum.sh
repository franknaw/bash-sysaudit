#!/usr/bin/env bash
# This scripts helps install RPM updates.
# Prefered way is to setup a local repo but for now this script will do.
# Please see bottomt of script for usage examples.

# Set shell constraints for safer execution
set -euo pipefail

function setUser() {
  user=$1
  rpmPath=$2
  rpmDir=$3
  pass="$(<sudo.txt)"
}

function checkDir() {
  if [ ! -d "$1/$2" ]; then
    echo "Error: Directory $1/$2 DOES NOT exists."
    exit 1
  fi
}

function getHostName() {
  hostname
}

function installPackage() {
  echo "$1" >.temp.txt
  cd "$2/$3"
  for pkgFile in "$2/$3/pkglist"*; do
    echo "Processing $pkgFile"
    echo "yum install  --  " $(echo "$(cat $pkgFile)")
    echo "$(<~/.temp.txt)" | sudo -S /usr/bin/yum -y --nogpgcheck localinstall $(echo "$(cat $pkgFile)")
  done
  rm ~/.temp.txt
}

function runYum() {

  echo "#######################################################################"
  echo "START YUM UPDATE - $(date '+%Y-%m-%d %H:%M:%S')"
  echo "#######################################################################"

  for server in "${servers[@]}"; do
    echo ""
    echo "####-- Connecting to Server: $server with user $user --####"
    echo ""

    ssh -T -o ConnectTimeout=30 $user@$server <<EOSSH

    echo ""
    echo -n "#### Start Server: $server - "; $(declare -f getHostName); getHostName
    echo ""

    echo "Check checkDir:==========================================================>"
    $(declare -f checkDir); checkDir $rpmPath $rpmDir;

    echo ""
    echo ""

    echo "Install Package:==========================================================>"
    $(declare -f installPackage); installPackage $pass $rpmPath $rpmDir;

    echo ""
    echo -n "#### Finished Server: $server - "; $(declare -f getHostName); getHostName
    echo ""
EOSSH
  done

  echo "#######################################################################"
  echo "END YUM UPDATE - $(date '+%Y-%m-%d %H:%M:%S')"
  echo "#######################################################################"
  echo ""

}

# please create a txt file "sudo.txt" containing sudo password
# place this file next to sysyum.sh..  please remove this file when complete

# usage = ./sysyum.sh the-rpm-dir
# ./sysyum.sh 20200125

# declare indexed array
#declare -a servers=("localhost" "127.0.0.1")
declare -a servers=("localhost")

# set Username, RPM Path and RPM Dir
setUser "someuser" "/home/someuser/somepath/bash-sysaudit/src/main/scripts/rpm" $1

runYum=$(runYum)
echo "$runYum" | tee sysyum-log.txt
