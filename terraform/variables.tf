# AWS Config

variable "aws_access_key" {
  default = "your key"
}

variable "aws_secret_key" {
  default = "your secret"
}

variable "aws_region" {
  default = "eu-central-1"
}

variable "ssh_key_name" {
  default = "hackathon-temp-key"
}

variable "instance_type_resource" {
  default = "t2.large"
}

variable "instance_count" {
    default = "1"
  }

variable "atmfrauddetectiondemo" {
  default = "https://github.com/ora0600/hackathon-ksql/archive/master.zip"
}

variable "confluent_home_value" {
  default = "/home/ec2-user/software"
}
