#!/bin/bash
yum update -y
yum install wget -y
yum install unzip -y
yum install java-1.8.0-openjdk-devel.x86_64 -y
# install docker
yum install -y docker
usermod -a -G docker ec2-user
service docker start
chkconfig docker on
curl -L https://github.com/docker/compose/releases/download/1.21.0/docker-compose-`uname -s`-`uname -m` | sudo tee /usr/local/bin/docker-compose > /dev/null
chmod +x /usr/local/bin/docker-compose
ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose

# install ATM Demo
mkdir -p /home/ec2-user/software
chown ec2-user:ec2-user /home/ec2-user/software
cd /home/ec2-user/software
wget ${atmfrauddetectiondemo}
unzip master.zip
chown ec2-user:ec2-user /home/ec2-user/software/hackathon-ksql-master/
rm master.zip
cd hackathon-ksql-master/
rm -r terraform/*

# config bash_profile for ec2-user
echo "export PATH=/usr/local/bin:\$PATH" >> /home/ec2-user/.bash_profile
chown ec2-user:ec2-user /home/ec2-user/.bash_profile
echo "export PATH=/usr/local/bin:\$PATH" >> /root/.bash_profile

