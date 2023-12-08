# bash file to be used as user_data
data "template_file" "user_data" {
  template = filebase64("${path.module}/scripts/cloudinit.sh")
}

# example of data for dynamic AMI search

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["*-golden-ubuntu-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["ID"] 
}


# alb target group
resource "aws_alb_target_group" "PROJECT_NAME_ec2_tg" {
    name = "PROJECT_NAME-ec2"
    port = 8081
    protocol = "HTTP"
    vpc_id = var.vpcid
    slow_start = 30
    lifecycle {
        create_before_destroy = true
    }
}

# ALB
resource "aws_lb" "PROJECT_NAME_ec2_lb" {
    name = "PROJECT_NAME-ec2-lb"
    internal = true
    load_balancer_type = "application"
    security_groups = [aws_security_group.PROJECT_NAME_ec2_lb_sg.id]
    subnets = var.subnetids


    tags = {
        name = "PROJECT_NAME-ec2-lb"
    }
}

# ALB listener

resource "aws_lb_listener" "redirect" {
    load_balancer_arn = aws_lb.PROJECT_NAME_ec2_lb.arn
    port = "80"
    protocol = "HTTP"

    default_action {
      type = "redirect"
      redirect {
        port = "443"
        protocol = "HTTPS"
        status_code = "HTTP_301"
      }
    }
}


resource "aws_lb_listener" "app" {
    load_balancer_arn = aws_lb.PROJECT_NAME_ec2_lb.arn
    port = "443"
    protocol = "HTTPS"
    ssl_policy = var.ssl_policy
    certificate_arn = var.certificate_arn
    default_action {
        type = "forward"
        target_group_arn = aws_alb_target_group.PROJECT_NAME_ec2_tg.arn
    }
}

# ALB Security Group
resource "aws_security_group" "PROJECT_NAME_ec2_lb_sg" {
    description = "Allows PROJECT_NAME access"
    name = "PROJECT_NAME-ec2-lb-sg"
    tags = {}
    vpc_id = var.vpcid
    ingress {
        cidr_blocks = var.cidrb
        description = "http"
        from_port = 80
        protocol = "tcp"
        to_port = 80
    }
    ingress {
        cidr_blocks = var.cidrb
        description = "https"
        from_port = 443
        protocol = "tcp"
        to_port = 443
    }
    egress {
        cidr_blocks = [
            "0.0.0.0/0"
        ]
        from_port = 0
        protocol = "-1"
        to_port = 0
    }
}




# EC2 Security Group
resource "aws_security_group" "PROJECT_NAME_ec2_ec2_sg" {
    description = "Allows PROJECT_NAME access"
    name = "PROJECT_NAME-ec2-ec2-sg"
    tags = {}
    vpc_id = var.vpcid
    ingress {
        cidr_blocks = var.cidrb
        description = "SSH"
        from_port = 22
        protocol = "tcp"
        to_port = 22
    }

    ingress {
        cidr_blocks = var.cidrb
        description = "Load Balancer"
        from_port = 0
        protocol = "tcp"
        to_port = 65535
        security_groups = [aws_security_group.PROJECT_NAME_ec2_lb_sg.id]
    }
    egress {
        cidr_blocks = [
            "0.0.0.0/0"
        ]
        from_port = 0
        protocol = "-1"
        to_port = 0
    }
}


# Launch Template
resource "aws_launch_template" "asg_conf" {
    name = "asgconf-PROJECT_NAME-ec2"
    iam_instance_profile {
        name = var.instance_profile
    }
    # image_id = var.amiid
    image_id = data.aws_ami.ubuntu.id
    instance_type = var.instancetype
    key_name = var.keyname
    
    monitoring {
        enabled = true
    }

    # disk
    block_device_mappings {
        device_name = "/dev/xvda"
        ebs {
            volume_size = 10
            encrypted = true
        }
    }

    # IMDSv2
    metadata_options {
        http_endpoint               = "enabled"
        http_put_response_hop_limit = 1
        http_tokens                 = "required"
    }

    network_interfaces {
        associate_public_ip_address = false
        security_groups = [ aws_security_group.PROJECT_NAME_ec2_ec2_sg.id, ]
    }

    # cloud-init
    user_data = data.template_file.user_data.rendered

    tag_specifications {
        resource_type = "instance"

        tags = {
            Name = "PROJECT_NAME-ec2-cluster"
        }
    }

    tag_specifications {
     resource_type = "instance"

     tags = merge({ Name = "PROJECT_NAME-ec2-cluster" }, var.default_tags)
   }

   dynamic "tag_specifications" {
    for_each = toset(var.to_tag)
    content {
       resource_type = tag_specifications.key
       tags = {
         cloud-cost-center = "",
         Name = "PROJECT_NAME-ec2-cluster"
       }
    }
  } 

    lifecycle {
        create_before_destroy = true
    }
}


# ASG
resource "aws_autoscaling_group" "asg" {
    name = "asg-PROJECT_NAME-ec2"
    launch_template {
        id = aws_launch_template.asg_conf.id
        version = "$Latest"
    }
    min_size = 1
    max_size = 2
    desired_capacity = 1
    health_check_grace_period = 300
    health_check_type = "EC2"
    force_delete = true
    vpc_zone_identifier = var.subnetids

    tag {
        key = "PROJECT_NAME-ec2-asg"
        value = "AutoScale"
        propagate_at_launch = true
    }

    dynamic "tag" {
     for_each = var.default_tags
     content {
       key = tag.key
       propagate_at_launch = true
       value = tag.value
     }
   }

    lifecycle {
        create_before_destroy = true
    }
}

# Attach ALB to Auto Scaling Group machines

resource "aws_autoscaling_attachment" "as_attach" {
    autoscaling_group_name = aws_autoscaling_group.asg.id
    lb_target_group_arn = aws_alb_target_group.PROJECT_NAME_ec2_tg.arn
}