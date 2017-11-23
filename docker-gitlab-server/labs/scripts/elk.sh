#!/bin/sh 
sudo apt-get install apt-transport-https ca-certificates curl software-properties-common
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
sudo apt-get update
sudo apt-get install docker-ce -y
sudo groupadd docker
sudo usermod -aG docker leansoft

sudo curl -L "https://github.com/docker/compose/releases/download/1.11.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose  

cd /home/leansoft                                                                        
git clone https://github.com/lean-soft/elk.git                                      
cd /home/leansoft/elk                                                               
docker-compose -f docker-elk-only.yml up -d