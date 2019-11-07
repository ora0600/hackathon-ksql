#!/bin/bash
yum update -y
yum install wget -y
yum install unzip -y
yum install java-1.8.0-openjdk-devel.x86_64 -y
# install docker
yum install -y docker
# set environment
echo vm.max_map_count=262144 >> /etc/sysctl.conf
sysctl -w vm.max_map_count=262144
echo "    *       soft  nofile  65535
    *       hard  nofile  65535" >> /etc/security/limits.conf
sed -i -e 's/1024:4096/65536:65536/g' /etc/sysconfig/docker
# enable docker    
usermod -a -G docker ec2-user
service docker start
chkconfig docker on
curl -L https://github.com/docker/compose/releases/download/1.21.0/docker-compose-`uname -s`-`uname -m` | sudo tee /usr/local/bin/docker-compose > /dev/null
chmod +x /usr/local/bin/docker-compose
ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose

# install ATM Demo
mkdir -p /home/ec2-user/software
chown ec2-user:ec2-user -R /home/ec2-user/software
cd /home/ec2-user/software
wget ${atmfrauddetectiondemo}
unzip master.zip
chown ec2-user:ec2-user -R /home/ec2-user/software/hackathon-ksql-master/
rm master.zip
cd hackathon-ksql-master/
chown ec2-user:ec2-user -R *
rm -r terraform/*

# set PUBLIC IP and change the Data in docker-compose.yaml
ATMPUBIP=`curl http://169.254.169.254/latest/meta-data/public-ipv4`
cd /home/ec2-user/software/hackathon-ksql-master
SCRIPT="sed -i 's/CONTROL_CENTER_KSQL_ADVERTISED_URL: \"http:\/\/localhost:8088\"/CONTROL_CENTER_KSQL_ADVERTISED_URL: \"http:\/\/$ATMPUBIP:8088\"/g' docker-compose.yml;"
# change ocker-compose file 
bash -c "$SCRIPT"
# Start environment
docker-compose up -d


# config bash_profile for ec2-user
echo "export PATH=/usr/local/bin:\$PATH" >> /home/ec2-user/.bash_profile
chown ec2-user:ec2-user /home/ec2-user/.bash_profile
echo "export PATH=/usr/local/bin:\$PATH" >> /root/.bash_profile
