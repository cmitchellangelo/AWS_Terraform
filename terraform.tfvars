aws_profile = "Terraform"
aws_region = "us-east-1"
vpc_cidr   = "172.41.0.0/16"
cidrs      = {
   us1-k8s = "172.41.32.0/19"
}

localip = "0.0.0.0/0"
domain_name = "tangoe"

k8s-master_instance_type = "m4.xlarge"
k8s-master_ami = "ami-0998c07366c6b3237"

k8s-node_instance_type = "m4.xlarge"
k8s-node_ami = "ami-0163098fcf8e79d14"

public_key_path = "~/.ssh/Kubernetes.pub"
key_name = "Kubernetes"

public_key_path2 = "~/.ssh/Kubernetes2.pub"
key_name2 = "Kubernetes2"

MasterCount = "1"
NodeCount = "2"

elb_healthy_threshold   = "2"
elb_unhealthy_threshold = "2"
elb_timeout 		= "5"
elb_interval		= "10"
