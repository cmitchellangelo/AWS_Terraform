provider "aws" {
  region  = "${var.aws_region}"
  profile = "${var.aws_profile}"
}

#--------------------------------------------VPC-----------------------------------------------------
resource "aws_vpc" "opt-us1-k8s" {
  cidr_block           = "${var.vpc_cidr}"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags {
    Name = "opt-us1-k8s"
  }
}

#-----Internet gateway-----

resource "aws_internet_gateway" "opt-us1-k8s_internet_gateway" {
  vpc_id = "${aws_vpc.opt-us1-k8s.id}"

  tags {
    Name = "opt-us1-k8s_igw"
  }
}

#-----Route table-----

resource "aws_route_table" "opt-us1-k8s_routetable" {
  vpc_id = "${aws_vpc.opt-us1-k8s.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.opt-us1-k8s_internet_gateway.id}"
  }

  tags {
    Name = "opt-us1-k8s_routetable"
  }
}

#-----Subnets-----

resource "aws_subnet" "opt-us1-k8s" {
  vpc_id                  = "${aws_vpc.opt-us1-k8s.id}"
  cidr_block              = "${var.cidrs["us1-k8s"]}"
  map_public_ip_on_launch = true
  availability_zone       = "${data.aws_availability_zones.available.names[0]}"

  tags {
    Name = "opt-us1-k8s"
  }
}

#-----Subnet associations to route tables-----

resource "aws_route_table_association" "opt-us1-k8s_assoc" {
  subnet_id      = "${aws_subnet.opt-us1-k8s.id}"
  route_table_id = "${aws_route_table.opt-us1-k8s_routetable.id}"
}

#-----Security Groups-----

resource "aws_security_group" "opt-us1-k8s_sg" {
  name        = "opt-us1-k8s_sg"
  description = "Used for access to the Kubernetes instances"
  vpc_id      = "${aws_vpc.opt-us1-k8s.id}"

  #SSH

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${var.localip}"]
  }

  #HTTPS
  
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["${var.localip}"]
  }

  #HTTP

  ingress {
    from_port = 80
    to_port   = 80
    protocol  = "tcp"
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

#-----Public Security Group--------

resource "aws_security_group" "api-elb-opt-us1-k8s_sg" {
  name        = "api-elb-opt-us1-k8s_sg"
  description = "Used for the elastic load balancer for HTTP/HTTPS access"
  vpc_id      = "${aws_vpc.opt-us1-k8s.id}"

  #HTTP

  ingress {
    from_port   = "80"
    to_port     = "80"
    protocol    = "tcp"
    cidr_blocks = ["${var.localip}"]
  }

  #HTTPS

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["${var.localip}"]
  }

  #Outbound internet access

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

#-----------------------------Kubernetes Master & Worker Node Server Creations----------------------------

#-----key pair for Workernodes-----

resource "aws_key_pair" "k8s-node_auth" {
  key_name   = "${var.key_name2}"
  public_key = "${file(var.public_key_path2)}"
}

#-----Workernodes-----

resource "aws_instance" "nodes-opt-us1-k8s" {
  instance_type = "${var.k8s-node_instance_type}"
  ami           = "${var.k8s-node_ami}"
  count         = "${var.NodeCount}"

  tags {
    Name = "nodes-opt-us1-k8s"
  }

  key_name               = "${aws_key_pair.k8s-node_auth.id}"
  vpc_security_group_ids = ["${aws_security_group.opt-us1-k8s_sg.id}"]
  subnet_id              = "${aws_subnet.opt-us1-k8s.id}"

  #-----Link Terraform worker nodes to Ansible playbooks-----

  provisioner "local-exec" {
    command = <<EOD
cat <<EOF >> workers
[workers]
${self.public_ip}
EOF
EOD
  }
}

#-----key pair for Masternodes-----

#key pair

resource "aws_key_pair" "k8s-master_auth" {
  key_name   = "${var.key_name}"
  public_key = "${file(var.public_key_path)}"
}

#-----Masternodes-----

resource "aws_instance" "master-opt-us1-k8s" {
  instance_type = "${var.k8s-master_instance_type}"
  ami           = "${var.k8s-master_ami}"
  count         = "${var.MasterCount}"

  tags {
    Name = "master-opt-us1-k8s"
  }

  key_name               = "${aws_key_pair.k8s-master_auth.id}"
  vpc_security_group_ids = ["${aws_security_group.opt-us1-k8s_sg.id}"]
  subnet_id              = "${aws_subnet.opt-us1-k8s.id}"

  #-----Link Terraform Master to Ansible playbooks

  provisioner "local-exec" {
    command = <<EOD
cat <<EOF >> master
[master]
${self.public_ip}
EOF
EOD
  }
}

#-----Load Balancer-----

resource "aws_elb" "master_elb" {
  name = "${var.domain_name}-elb"

  subnets = ["${aws_subnet.opt-us1-k8s.id}"]

  security_groups = ["${aws_security_group.api-elb-opt-us1-k8s_sg.id}"]

  listener {
    instance_port     = 443
    instance_protocol = "http"
    lb_port           = 443
    lb_protocol       = "http"
  }

  health_check {
    healthy_threshold   = "${var.elb_healthy_threshold}"
    unhealthy_threshold = "${var.elb_unhealthy_threshold}"
    timeout             = "${var.elb_timeout}"
    target              = "TCP:443"
    interval            = "${var.elb_interval}"
  }

  instances                   = ["${aws_instance.master-opt-us1-k8s.id}"]
  cross_zone_load_balancing   = true
  idle_timeout                = 400
  connection_draining         = true
  connection_draining_timeout = 400

  tags {
    Name = "${var.domain_name}-master-opt-us1-k8s-elb"
  }
}
