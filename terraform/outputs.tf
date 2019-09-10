###########################################
################# Outputs #################
###########################################

output "SSH" {
  value = tonumber(var.instance_count) >= 1 ? "SSH  Access: ssh -i hackathon-temp-key.pem ec2-user@${join(",",formatlist("%s", aws_instance.ATMFraudDetection.*.public_ip),)} " : "Confluent Cloud Platform on AWS is disabled" 
}
output "SSH_Tunnel" {
  value = tonumber(var.instance_count) >= 1 ? "With Tunnel: ssh -i hackathon-temp-key.pem -N -L 9022:${join(",", formatlist("%s", aws_instance.ATMFraudDetection.*.private_dns),)}:9021 ec2-user@${join(",", formatlist("%s", aws_instance.ATMFraudDetection.*.public_ip),)}" : "Confluent Cloud Platform on AWS is disabled"
}  