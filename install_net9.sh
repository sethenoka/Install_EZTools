#!/bin/bash
GREEN=$'\e[0;32m'
RED=$'\e[0;31m'
NC=$'\e[0m'

clear

echo "--------------------------------------------------------------------------------------------"
echo "Installing prereqs..." 1>&2

if sudo apt-get update > /dev/null && sudo apt-get install -y wget apt-transport-https software-properties-common > /dev/null; then
    echo "${GREEN}Prereqs installed.${NC}" 1>&2
else
    echo "${RED}ERROR: Couldn't install prereqs.${NC}" 1>&2
fi

echo "--------------------------------------------------------------------------------------------"
echo "Installing .NET9..." 1>&2
if wget https://builds.dotnet.microsoft.com/dotnet/scripts/v1/dotnet-install.sh -O dotnet-install.sh -q > /dev/null && chmod +x dotnet-install.sh && ./dotnet-install.sh --channel 9.0 > /dev/null && rm -r dotnet-install.sh && echo "alias dotnet='~/.dotnet/dotnet'" >> ~/.bashrc; then
    echo "${GREEN}.NET9 installed.${NC}" 1>&2
else
    echo "${RED}ERROR: Couldn't install .NET9.${NC}" 1>&2
fi

# Download a zip file, unzip into a destination, and remove the zip
download_and_unzip() {
  local url="$1"
  local dest_dir="$2"
  local zip_name=$(basename "$url")
  echo "--------------------------------------------------------------------------------------------" 1>&2
  echo "Downloading ${zip_name}..." 1>&2
  if wget "$url" -q && sudo unzip "$zip_name" -d "$dest_dir" > /dev/null 2>&1 && rm -f "$zip_name"; then
    echo "${GREEN}${zip_name} installed.${NC}" 1>&2
  else
    echo "${RED}ERROR: Couldn't install ${zip_name}.${NC}" 1>&2
  fi
}

# Install MFTECmd, PECmd, RECmd using download_and_unzip
download_and_unzip "https://download.ericzimmermanstools.com/net9/MFTECmd.zip" "/opt/MFTEcmd"
download_and_unzip "https://download.ericzimmermanstools.com/net9/PECmd.zip" "/opt/PECmd"
download_and_unzip "https://download.ericzimmermanstools.com/net9/RECmd.zip" "/opt/"
download_and_unzip "https://download.ericzimmermanstools.com/net9/EvtxECmd.zip" "/opt/"

echo "--------------------------------------------------------------------------------------------"
echo "Finalising..."
export PATH="$PATH:/opt"
echo "alias pecmd='dotnet /opt/PECmd/PECmd.dll'" >> ~/.bashrc
echo "alias mftecmd='dotnet /opt/MFTEcmd/MFTECmd.dll'" >> ~/.bashrc
echo "alias recmd='dotnet /opt/RECmd/RECmd.dll'" >> ~/.bashrc
echo "alias evtxecmd='dotnet /opt/EvtxeCmd/EvtxECmd.dll'" >> ~/.bashrc

. ~/.bashrc
read -p "Installation complete. You may need to exit the terminal for the relevant aliases to work. Press any key to exit script..."
