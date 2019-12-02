#!/usr/bin/env bash
#:: Blademaster

ver_to_download=v0.2

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

echo $(date)
echo ""
echo "Brought to you by Blademaster"
echo -e "${GREEN}== scribe $ver_to_download ==${NC}"
echo
echo "Good day. This is automated cold masternode setup for scribe project. Auto installer was tested on specific environment. Don't try to install masternode with undocumented operating system!"
echo ""
echo "Installation content:"
echo "scribe core $ver_to_download code"
echo

echo ""
wanip=$(curl -s 4.ipquail.com/ip)
if [ -z "${wanip}" ]; then
    echo -e "${RED}Sorry, we don't know your external IPv4 addr${NC}" && echo ""
    echo -e "${GREEN}Input your IPv4 addr manually:${NC}" && read wanip
fi


echo "Your external IP is $wanip y/n?"
read wan
            if [ "$wan" != "y" ]; then
					echo "Please enter your custom IP:"
					read wancustom
					wanip=${wancustom}
            fi

# Download scribe sources //
echo ""
echo -e "${GREEN}1/10 Downloading scribe sources...${NC}" 
echo ""
cd ~
rm -fr scribe*.tar.gz

wget https://github.com/scribenetwork/scribe/releases/download/${ver_to_download}/scribe-ubuntu-16.04-x64.tar.gz
            
# Manage coin daemon and configuration //

#unzip -o scribe*.zip
tar -xvf scribe-ubuntu-16.04-x64.tar.gz
echo ""
sudo cp -fr ./scribe-ubuntu-16.04-x64/usr/local/bin/scribed /usr/bin/
sudo cp -fr ./scribe-ubuntu-16.04-x64/usr/local/bin/scribe-cli /usr/bin/
rm -fr ./scribe-ubuntu-16.04-x64/
mkdir -p ~/.scribecore/
touch ~/.scribecore/scribe.conf
cat << EOF > ~/.scribecore/scribe.conf
rpcuser=scribeuser
rpcpassword=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 32 ; echo '')
rpcallow=127.0.0.1
server=1
listen=1
daemon=1
bind=$wanip
EOF

#Create scribecore.service
echo -e "${GREEN}2/10 Create scribe.service for systemd${NC}"
echo ""
echo \
"[Unit]
Description=Scribe Core Wallet daemon & service
After=network.target

[Service]
User=root
Type=forking
ExecStart=/usr/bin/scribed -daemon -pid=$(echo $HOME)/.scribecore/scribed.pid --datadir=$(echo $HOME)/.scribecore/
PIDFile=$(echo $HOME)/.scribecore/scribed.pid
ExecStop=/usr/bin/scribe-cli stop
Restart=always
RestartSec=3600
TimeoutStopSec=60s
TimeoutStartSec=10s
StartLimitInterval=120s
StartLimitBurst=5

[Install]
WantedBy=default.target" | sudo tee /etc/systemd/system/scribe.service

sudo chmod 664 /etc/systemd/system/scribe.service

sudo systemctl enable scribe

real_user=$(echo $USER) 

sudo chown -R $real_user:$real_user $(echo $HOME)/.scribecore/

# Check if user is root? If not create sudoers files to manage systemd services
echo ""
echo -e "${GREEN}3/10 Check if user is root? If not create sudoers files to manage systemd services${NC}"
if [ "$EUID" -ne 0 ]; then
sudo echo \
"%$real_user ALL= NOPASSWD: /bin/systemctl start scribe
%$real_user ALL= NOPASSWD: /bin/systemctl stop scribe
%$real_user ALL= NOPASSWD: /bin/systemctl restart scribe" | sudo tee /tmp/$real_user
sudo mv /tmp/$(echo $real_user) /etc/sudoers.d/
fi

# Start scribe daemon, wait for wallet creation //
sudo systemctl start scribe &&
echo "" ; echo "Please wait for few minutes..."
sleep 120 &
PID=$!
i=1
sp="/-\|"
echo -n ' '
while [ -d /proc/$PID ]
do
  printf "\b${sp:i++%${#sp}:1}"
done
echo ""
sudo systemctl stop scribe &&
echo ""
echo -e "Shutting down daemon, reconfiguring scribe.conf, we want to know your cold wallet ${GREEN}masternodeprivkey${NC} (example: 7UwDGWAKNCAvyy9MFEnrf4JBBL2aVaDm2QzXqCQzAugULf7PUFD), please input now:"
echo""
read masternodeprivkey
privkey=$(echo $masternodeprivkey)
checkpriv_key=$(echo $masternodeprivkey | wc -c)
if [ "$checkpriv_key" -ne "52" ];
then
	echo ""
	echo "Looks like your $privkey is not correct, it should cointain 52 symbols, please paste it one more time"
	read masternodeprivkey
privkey=$(echo $masternodeprivkey)
checkpriv_key=$(echo $masternodeprivkey | wc -c)

if [ "$checkpriv_key" -ne "52" ];
then
        echo "Something wrong with masternodeprivkey, cannot continue" && exit 1
fi
fi
echo ""
echo "Give some time to shutdown the wallet..."
echo ""
sleep 60 &
PID=$!
i=1
sp="/-\|"
echo -n ' '
while [ -d /proc/$PID ]
do
  printf "\b${sp:i++%${#sp}:1}"
done
cat << EOF > ~/.scribecore/scribe.conf
rpcuser=scribeuser
rpcpassword=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 32 ; echo '')
rpcallow=127.0.0.1
server=1
listen=1
daemon=1
maxconnections=16
masternode=1
bind=$wanip
externalip=$wanip
masternodeaddr=$wanip:8800
masternodeprivkey=$privkey
EOF

# Firewall //
echo -e "${GREEN}4/5 Update firewall rules${NC}"
echo ""
sudo /usr/sbin/ufw limit ssh/tcp comment 'Rate limit for openssh server' 
sudo /usr/sbin/ufw allow 8800/tcp comment 'Scribe Wallet daemon'
sudo /usr/sbin/ufw --force enable
echo ""

# Final start
echo ""
echo -e "${GREEN}5/5 Masternode config done, storADE platform installed - starting scribe again${NC}"
echo ""
sudo systemctl start scribe
echo -e "${RED}The blockchain is syncing from scratch. You have to wait few hours to sync all the blocks!${NC}"
echo ""
echo "Setup summary:"
echo "Masternode privkey: $privkey"
echo "Your external IPv4 addr: $wanip"
echo "Installation log: ~/scribe_masternode_installation.log"
echo "scribe Core datadir: "$(echo $HOME/.scribecore/)""
echo ""
echo "In order to start a masternode from Cold Wallet check your current block with explorer block by typing in the terminal:"
echo -e "${GREEN}scribe-cli getinfo | grep blocks${NC}"
echo "https://explorer.scribe.network/api/getblockcount"
echo ""
echo "Please start a masternode from Cold Wallet if explorer.scribecore.cc block matches with yours."
echo "Overall setup completed successfully"
echo -e "${NC}"
echo ""
echo -e "${GREEN}©2018-2019 brought to you by Blademaster${NC}"
