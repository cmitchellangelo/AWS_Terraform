variable "aws_region" {
  default = "us-east-1"
}

variable "aws_profile" {}

data "aws_availability_zones" "available" {}

variable "vpc_cidr" {}

variable "cidrs" {
  type = "map"
}

variable "localip" {}

variable "domain_name" {}

variable "k8s-master_instance_type" {}

variable "k8s-master_ami" {}

variable "k8s-node_instance_type" {}

variable "k8s-node_ami" {}

variable "public_key_path" {}

variable "key_name" {}

variable "public_key_path2" {}

variable "key_name2" {}

variable "MasterCount" {}

variable "NodeCount" {}

variable "elb_healthy_threshold" {}

variable "elb_unhealthy_threshold" {}

variable "elb_timeout" {}

variable "elb_interval" {}
