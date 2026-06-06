data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# EC2 Launch Template
resource "aws_launch_template" "app_lt" {
  name_prefix   = "ha-app-launch-template-"
  image_id      = data.aws_ami.amazon_linux_2023.id
  instance_type = var.instance_type

  network_interfaces {
    associate_public_ip_address = false
    security_groups             = [aws_security_group.ec2_sg.id]
  }

  iam_instance_profile {
    name = aws_iam_instance_profile.ec2_profile.name
  }

  user_data = base64encode(<<-EOF
              #!/bin/bash
              # Update system and install Apache web server and AWS CLI
              dnf update -y
              dnf install -y httpd awscli

              # Start Apache and enable it to run on startup
              systemctl start httpd
              systemctl enable httpd

              # Retrieve metadata about the instance (availability zone and instance ID)
              TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
              INSTANCE_ID=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/instance-id)
              AZ=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/placement/availability-zone)

              # Fetch configuration value from SSM Parameter Store
              AWS_REGION=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/placement/region)
              WELCOME_MSG=$(aws ssm get-parameter --name "/app/config/welcome_message" --region $AWS_REGION --query "Parameter.Value" --output text)

              # Write HTML page
              cat <<HTML > /var/www/html/index.html
              <!DOCTYPE html>
              <html lang="en">
              <head>
                  <meta charset="UTF-8">
                  <meta name="viewport" content="width=device-width, initial-scale=1.0">
                  <title>High Availability App</title>
                  <style>
                      body {
                          font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
                          background: linear-gradient(135deg, #1f4068, #162447);
                          color: #ffffff;
                          display: flex;
                          justify-content: center;
                          align-items: center;
                          height: 100vh;
                          margin: 0;
                      }
                      .card {
                          background: rgba(255, 255, 255, 0.1);
                          backdrop-filter: blur(10px);
                          border-radius: 15px;
                          padding: 40px;
                          box-shadow: 0 8px 32px 0 rgba(0, 0, 0, 0.3);
                          border: 1px solid rgba(255, 255, 255, 0.2);
                          text-align: center;
                          max-width: 600px;
                      }
                      h1 {
                          color: #00adb5;
                          margin-bottom: 20px;
                      }
                      .info {
                          background: rgba(0, 0, 0, 0.2);
                          padding: 15px;
                          border-radius: 8px;
                          margin-top: 20px;
                          font-family: monospace;
                          text-align: left;
                          color: #eee;
                      }
                      .status {
                          display: inline-block;
                          padding: 5px 10px;
                          border-radius: 20px;
                          background-color: #4caf50;
                          font-size: 0.9em;
                          margin-bottom: 20px;
                      }
                  </style>
              </head>
              <body>
                  <div class="card">
                      <div class="status">HEALTHY & ACTIVE</div>
                      <h1>AWS HA Architecture Demo</h1>
                      <p>$WELCOME_MSG</p>
                      <div class="info">
                          <strong>Instance ID:</strong> $INSTANCE_ID<br>
                          <strong>Availability Zone:</strong> $AZ<br>
                          <strong>Region:</strong> $AWS_REGION
                      </div>
                  </div>
              </body>
              </html>
              HTML
              EOF
  )

  lifecycle {
    create_before_destroy = true
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "ha-app-instance"
    }
  }
}

# Auto Scaling Group
resource "aws_autoscaling_group" "app_asg" {
  name_prefix         = "ha-app-asg-"
  desired_capacity    = 2
  max_size            = 4
  min_size            = 2
  vpc_zone_identifier = [aws_subnet.private_1.id, aws_subnet.private_2.id]
  target_group_arns   = [aws_lb_target_group.app_tg.arn]

  launch_template {
    id      = aws_launch_template.app_lt.id
    version = "$Latest"
  }

  health_check_type         = "ELB"
  health_check_grace_period = 300

  force_delete = true

  lifecycle {
    create_before_destroy = true
  }

  tag {
    key                 = "Name"
    value               = "ha-asg-server"
    propagate_at_launch = true
  }
}
