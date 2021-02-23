#!/usr/bin/env bash
# This scripts runs an arbitrary Linux command against a list of servers.
# Please see bottomt of script for configuration and usage examples.

# Set shell constraints for safer execution
set -euo pipefail

function setUser() {
  user=$1
  cmd="$2"
  pass="$(<sudo.txt)"
}

function getHostName() {
  hostname
}

function execCmd() {
  echo "$1" >.temp.txt
  echo "Execute command  --  $2"
  echo "$(<~/.temp.txt)" | sudo -S $2
  rm ~/.temp.txt
}

function runCmd() {

  echo "#######################################################################"
  echo "START RUN CMD - $(date '+%Y-%m-%d %H:%M:%S')"
  echo "#######################################################################"

  for server in "${servers[@]}"; do
    echo ""
    echo "####-- Connecting to Server: $server with user $user --####"
    echo ""

    ssh -T -o ConnectTimeout=30 $user@$server <<EOSSH

    echo ""
    echo -n "#### Start Server: $server - "; $(declare -f getHostName); getHostName
    echo ""

    echo "Install Package:==========================================================>"
    $(declare -f execCmd); execCmd "$pass" "$cmd";

    echo ""
    echo -n "#### Finished Server: $server - "; $(declare -f getHostName); getHostName
    echo ""
EOSSH
  done

  echo "#######################################################################"
  echo "END RUN CMD - $(date '+%Y-%m-%d %H:%M:%S')"
  echo "#######################################################################"
  echo ""

}

# please create a txt file "sudo.txt" containing sudo password
# place this file next to syscmd.sh..  please remove this file when complete
# usage..
# ./sysycmd.sh "netstat -tlpn" | tee syscmd-log.txt

# declare indexed array of listed servers
declare -a servers=("localhost" "127.0.0.1" "localhost" "127.0.0.1")

# set Username and Linux command
setUser "someuser" "$1"

runCmd
