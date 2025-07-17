# Secure Cloud Lab: AWS Environment for Cloud Security Practice

## Overview

This project provisions a secure, isolated AWS cloud environment designed to simulate real-world cloud security scenarios. It allows users to safely practice penetration testing and hands-on cloud defense techniques in a controlled infrastructure. The lab is suitable for security professionals, cloud engineers, and students looking to build practical experience in AWS security.

## Core Use Case: Penetration Testing OWASP Juice Shop

The environment deploys OWASP Juice Shop -- a deliberately vulnerable web application -- on a private EC2 instance within a hardened VPC. Users can access it through a bastion host using SSH tunneling or via AWS Systems Manager (SSM). This setup enables:

- Web application scanning with tools like Nmap, Nikto, Burp Suite, and OWASP ZAP
- Practical exploitation of common vulnerabilities in a safe, reproducible environment
- Simulation of real-world attacks within AWS

## Architecture Overview

- VPC with both public and private subnets
- Bastion host (public subnet) for secured access
- Application host (private subnet) running OWASP Juice Shop
- Optional Kali Linux EC2 instance for internal testing
- Encrypted S3 buckets for Terraform state, logs, and general-purpose storage
- CloudTrail, GuardDuty, AWS Config, and CloudWatch for logging, threat detection, and compliance
- IAM roles and policies following the principle of least privilege
- AWS KMS for encryption of EBS volumes, S3 objects, and RDS databases
- Lambda functions for automated incident response and budget savings

## Security Scenarios You Can Practice

| Category                  | Practical Tasks                                              |
|---------------------------|--------------------------------------------------------------|
| Identity Management       | Create and test IAM policies, roles, and user permissions    |
| Network Security          | Configure and test Security Groups, NACLs, and VPC flow logs |
| Storage Security          | Harden S3 access policies and test misconfiguration risks    |
| Monitoring and Detection  | Log activity using CloudTrail, detect threats with GuardDuty |
| Penetration Testing       | Exploit Juice Shop through Bastion or Kali EC2 instance      |
| Incident Response         | Use EventBridge and Lambda to automate security workflows    |
| Encryption                | Encrypt storage, simulate unauthorized access attempts       |
