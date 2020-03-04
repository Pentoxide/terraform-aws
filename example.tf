provider "aws" {
  profile    = "default"
  region     = var.region
}

data "aws_vpcs" "example" {
  filter {
    name = "isDefault"
    values = ["true"]
  }
}

data "aws_subnet_ids" "example" {
  vpc_id = tolist(data.aws_vpcs.example.ids)[0]
}

resource "aws_security_group" "example-http-in" {
  name = "allow_http"
  description = "Allow http for hosts"
  vpc_id = tolist(data.aws_vpcs.example.ids)[0]
  ingress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}

resource "aws_security_group" "example-local-http" {
  name = "local_http"
  description = "Allow local http"
  vpc_id = tolist(data.aws_vpcs.example.ids)[0]
  ingress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["192.168.0.0/16", "172.16.0.0/12", "10.0.0.0/8"]
  }
}

resource "aws_security_group" "example-ssh-in" {
  name = "allow_ssh"
  description = "Allow ssh for hosts"
  vpc_id = tolist(data.aws_vpcs.example.ids)[0]
  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}

resource "aws_security_group" "example-all-out" {
  name = "allow_all_out"
  description = "Allow all outgoing traffic"
  vpc_id = tolist(data.aws_vpcs.example.ids)[0]
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}

resource "aws_instance" "example" {
  for_each = data.aws_subnet_ids.example.ids
  subnet_id = each.value
  ami           = var.images[var.region]
  instance_type = var.instances[var.region]
  credit_specification {
    cpu_credits = "standard"
  }
  security_groups = [
    aws_security_group.example-local-http.id,
    aws_security_group.example-ssh-in.id,
    aws_security_group.example-all-out.id
  ]
  tags = {
    Name = "Backend-${each.value}"
  }
  key_name = "myEC2"
  connection {
    type = "ssh"
    user = "ec2-user"
    private_key = var.private_key
    host = self.public_ip
  }
  provisioner "remote-exec" {
    inline = [
      "sudo yum install nginx -y",
      "sudo sh -c 'echo $HOSTNAME > /usr/share/nginx/html/index.html'",
      "sudo systemctl start nginx"
    ]
  }
}

resource "aws_lb" "example" {
  name = "terraform-test-frontend"
  internal = false
  load_balancer_type = "application"
  enable_deletion_protection = false
  security_groups = [
    aws_security_group.example-http-in.id,
    aws_security_group.example-all-out.id
  ]
  subnets = [for s in data.aws_subnet_ids.example.ids: s]
}

resource "aws_lb_listener" "frontend" {
  load_balancer_arn = aws_lb.example.arn
  port = 80
  protocol = "HTTP"
  default_action {
    type = "forward"
    target_group_arn = aws_lb_target_group.example.arn
  }
}

resource "aws_lb_target_group" "example" {
  name = "test-tg-frontend"
  port = 80
  protocol = "HTTP"
  vpc_id = tolist(data.aws_vpcs.example.ids)[0]
}

resource "aws_lb_target_group_attachment" "example" {
  for_each = data.aws_subnet_ids.example.ids
  target_group_arn = aws_lb_target_group.example.arn
  target_id = aws_instance.example[each.value].id
  port = 80
}

output "alb_dns_name" {
  value = aws_lb.example.dns_name
}
