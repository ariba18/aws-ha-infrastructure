# High-Availability AWS 3-Tier Web Architecture (Terraform)

This repository contains the Infrastructure-as-Code (IaC) configuration to deploy a secure, fault-tolerant, and auto-scaling 3-tier web application architecture in Amazon Web Services (AWS) using **Terraform**.

## Architecture Diagram

The infrastructure deploys a high-availability network design across two Availability Zones (AZs) in a custom VPC:

```
                          [ Internet ]
                               │
                       [ Internet Gateway ]
                               │
                     [ Public Load Balancer ]
                    (Spans Public Subnet 1 & 2)
                               │
               ┌───────────────┴───────────────┐
        (AZ-1 / ap-south-1a)           (AZ-2 / ap-south-1b)
               │                               │
       [ Public Subnet 1 ]             [ Public Subnet 2 ]
       - NAT Gateway 1                 - NAT Gateway 2
               │                               │
       [ Private Subnet 1 ]            [ Private Subnet 2 ]
       - App Server (EC2)              - App Server (EC2)
       └───────────────────────┬───────────────────────┘
                               │
                    [ Auto Scaling Group ]
                               │
                [ S3 Endpoint / SSM / DynamoDB ]
```

## Features

1. **High Availability (Multi-AZ)**:
   * Traffic is distributed across two Availability Zones using an **Application Load Balancer (ALB)**.
   * Compute instances are managed by an **Auto Scaling Group (ASG)** which automatically replaces unhealthy nodes and maintains a minimum capacity of 2 instances.
2. **Network Security & DMZ Isolation**:
   * The application servers are placed in **Private Subnets**, entirely hidden from public inbound traffic.
   * Access to the internet for security updates/patching is handled securely outbound via **NAT Gateways**.
   * Communication to Amazon S3 goes through a **Gateway VPC Endpoint**, routing traffic over the internal AWS network, reducing latency and avoiding NAT data transfer costs.
3. **Security Firewalls (Least Privilege)**:
   * The ALB's Security Group allows HTTP port 80 traffic from anywhere (`0.0.0.0/0`).
   * The EC2 instance Security Group allows ingress traffic **only** from the ALB's Security Group, preventing direct external probing.
4. **Credential & Config Management**:
   * Application configuration parameters are stored in **AWS Systems Manager (SSM) Parameter Store**.
   * Database credentials are saved securely in **AWS Secrets Manager**.
   * IAM Roles with the least-privilege policies are assigned to EC2 servers via an Instance Profile, avoiding hardcoded access keys in code.

---

## Infrastructure Components (Terraform Files)

* `providers.tf`: Configures the AWS and Random provider versions.
* `variables.tf`: Defines standard inputs (region, VPC CIDR blocks, subnet sizes, and server types).
* `vpc.tf`: Provisions the custom VPC, subnets, Route Tables, Internet Gateway, NAT Gateways, and S3 VPC Endpoint.
* `security_groups.tf`: Provisions security group firewalls for the ALB and EC2 servers.
* `iam.tf`: Provisions IAM roles and custom security policy attachments for the compute layer.
* `database.tf`: Provisions the S3 Storage bucket, DynamoDB tables, SSM Parameter Store config, and Secrets Manager database keys.
* `alb.tf` & `asg.tf`: Provisions the load balancer, health check target groups, launch template (with user data startup script), and the Auto Scaling Group.
* `outputs.tf`: Prints the Load Balancer DNS name upon successful deployment.

---

## Getting Started

### Prerequisites
1. Install [Terraform](https://developer.hashicorp.com/terraform/downloads).
2. Install the [AWS CLI](https://aws.amazon.com/cli/).
3. Configure AWS credentials by running:
   ```bash
   aws configure
   ```

### Deployment Steps
1. Initialize the directory to download the providers:
   ```bash
   terraform init
   ```
2. Preview the resources that will be created:
   ```bash
   terraform plan
   ```
3. Deploy the infrastructure to your AWS account:
   ```bash
   terraform apply
   ```
4. Type `yes` to confirm. Once completed, copy the `alb_dns_name` URL output and paste it into your browser to view the live website.

### Cleanup
To avoid ongoing AWS costs, tear down all the created resources with:
```bash
terraform destroy
```
