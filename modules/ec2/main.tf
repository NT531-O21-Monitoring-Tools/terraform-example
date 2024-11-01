# Get Ubuntu 20.04 AMI
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

locals {
  ec2_ami = var.ami != "" ? var.ami : data.aws_ami.ubuntu.id
}
# Public EC2 Instance
resource "aws_instance" "public_instances" {
  count         = var.public_instance_count
  ami           = local.ec2_ami
  instance_type = var.instance_type

  subnet_id              = var.public_subnets_id[count.index % length(var.public_subnets_id)]
  vpc_security_group_ids = var.public_sgs_id
  key_name               = var.key_name
  user_data = file("../../scripts/add-pub-ssh-key.sh")
  tags = {
    Name = "${var.name}-public-instance-${count.index}"
  }
}

resource "null_resource" "public_instance_provisioner" {
  depends_on = [
    aws_instance.public_instances
  ]
  triggers = {
    "always_run" = timestamp()
  }
  connection {
    type        = "ssh"
    user        = "ubuntu"
    host        = aws_instance.public_instances[0].public_ip
    private_key = file("${path.root}/${var.key_name}.pem")
    agent = false
  }
  provisioner "file" {
    source      = "../../scripts/init-script.sh"
    destination = "/home/ubuntu/init-script.sh"
  }
  provisioner "remote-exec" {
    inline = [
      "chmod +x /home/ubuntu/init-script.sh",
      "sudo /home/ubuntu/init-script.sh"
    ]
  }
}

# Private EC2 Instance
resource "aws_instance" "private_instances" {
  count         = var.private_instance_count
  ami           = local.ec2_ami
  instance_type = var.instance_type

  subnet_id              = var.private_subnets_id[count.index % length(var.private_subnets_id)]
  vpc_security_group_ids = var.private_sgs_id
  key_name               = var.key_name
  tags = {
    Name = "${var.name}-private-instance-${count.index}"
  }
}
