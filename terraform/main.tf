resource "aws_security_group" "atmfraud" {
  name        = "atmfraudSecGroup"
  description = "ATM Fraud Det. Sec. Group"

  # SSH access from anywhere
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTP access from the VPC
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
# KSQL Server Port
  ingress {
    from_port   = 8088
    to_port     = 8088
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  # outbound internet access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "ATMFraudDetection" {
  ami           = "${data.aws_ami.ami.id}"
  count         = var.instance_count
  instance_type = var.instance_type_resource
  key_name      = var.ssh_key_name
  vpc_security_group_ids = ["${aws_security_group.atmfraud.id}"]
  user_data = data.template_file.ATMFraudDetection_instance.rendered

  root_block_device {
    volume_type = "gp2"
    volume_size = 50
  }

  tags = {
    Name = "KSQL Hackathon",
    owner = "youremail@confluent.io"

  }
}
