resource "aws_instance" "ATMFraudDetection" {
  ami           = "${data.aws_ami.ami.id}"
  count         = var.instance_count
  instance_type = var.instance_type_resource
  key_name      = var.ssh_key_name
  user_data = data.template_file.ATMFraudDetection_instance.rendered

  root_block_device {
    volume_type = "gp2"
    volume_size = 8
  }

  tags = {
    Name = "ATMFraudDetection"
  }
}