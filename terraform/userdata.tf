###########################################
######## Confluent 5.3 Dev Instance ##########
###########################################

data "template_file" "ATMFraudDetection_instance" {
  template = file("utils/instance.sh")

  vars = {
    atmfrauddetectiondemo = var.atmfrauddetectiondemo
    confluent_home_value  = var.confluent_home_value
  }
}
