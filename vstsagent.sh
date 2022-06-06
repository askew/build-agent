#!/bin/bash

usage() { echo "Usage: vstsagent.sh -s <azuredevopsserver> -k <keyVault> -t <PATtoken> -a <agentname> [-p <agentpool>]" 1>&2; exit 1; }

declare server=""
declare pattoken=""
declare agentname=""
declare agentpool="Default"
declare agentgroup="buildagents"
declare agentuser="vstsagent"
declare token=""
declare keyvault=""
declare vnetid=""
declare public_ip=""

# Initialize parameters specified from command line
while getopts ":s:k:t:a:p:v:" arg; do
  case "${arg}" in
    s)
      server=${OPTARG}
    ;;
    k)
      keyvault=${OPTARG}
    ;;
    t)
      pattoken=${OPTARG}
    ;;
    a)
      agentname=${OPTARG}
    ;;
    p)
      agentpool=${OPTARG}
    ;;
    v)
      vnetid=${OPTARG}
    ;;
  esac
done

if [[ -z "$server" ]]; then
  echo "No Azure DevOps Server URL specifed"
  exit 0
fi

set -v
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y apt-transport-https lsb-release gnupg curl
set +v

# Get an access token for KeyVault using the VM managed idenity
token=$(curl 'http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https%3A%2F%2Fvault.azure.net' -H Metadata:true -s | jq -r '.access_token')

if [[ -n "$token" ]]; then
  pattoken=$(curl "https://$keyvault.vault.azure.net/secrets/$pattoken?api-version=7.0" -H Authorization:"Bearer $token" -s | jq -r '.value')
fi

if [[ -z "$pattoken" ]]; then
  echo "Please specify the Azure DevOps PAT token"
  exit 1
fi

if [[ -z "$agentname" ]]; then
  echo "Please specify a name for the agent"
  exit 1
fi

if [[ "$EUID" -ne 0 ]]; then
  echo "The script needs to be run as root..."
  exit 1
fi

getent group $agentgroup > /dev/null
if [ $? -ne 0 ]; then
  groupadd $agentgroup
fi

getent passwd $agentuser > /dev/null
if [ $? -ne 0 ]; then
  useradd -m -g $agentgroup -G docker $agentuser
fi

# Make the docker socket available to the build agents so that docker-in-docker will work.
chown root:$agentgroup /var/run/docker.sock

hdrs="Accept:application/vnd.github.v3+json"
assetsurl=$(curl https://api.github.com/repos/Microsoft/azure-pipelines-agent/releases/latest -H $hdrs -s | jq -r '.assets[] | select(.name == "assets.json") | .browser_download_url')
download=$(curl $assetsurl -L -s | jq -r '.[] | select(.platform == "linux-x64") | select(.name | startswith("vsts-agent"))')
filename="/home/$agentuser/$(echo $download | jq -r '.name')"
agentdownloadurl=$(echo $download | jq -r '.downloadUrl')

su -c "curl $agentdownloadurl -s -o $filename" $agentuser

su -c "cd ~ && tar -zxf $filename && rm $filename" $agentuser

/home/$agentuser/bin/installdependencies.sh

su -c "echo 'VNETID=$vnetid' >> ~/.env" $agentuser

# Get the outbound public IP, if configured.
if [[ $(curl -s -H 'Metadata:true' -w "%{http_code}" "http://169.254.169.254/metadata/loadbalancer?api-version=2021-02-01" -o /dev/null) -eq 200 ]]; then
  public_ip=$(curl -s "http://169.254.169.254:80/metadata/loadbalancer?api-version=2021-02-01" -H 'Metadata:true' | jq -r '.loadbalancer.outboundRules | select(any)[0].frontendIpAddress')
  if [[ -n $public_ip ]]; then
    su -c "echo 'PUBLIC_IP=$public_ip' >> ~/.env" $agentuser
  fi
fi

su -l -c "/home/$agentuser/config.sh --unattended --acceptTeeEula --url \"$server\" --auth PAT --token \"$pattoken\" --pool \"$agentpool\" --agent \"$agentname\" --replace" $agentuser

cd /home/$agentuser/
./svc.sh install $agentuser
./svc.sh start
cd -
