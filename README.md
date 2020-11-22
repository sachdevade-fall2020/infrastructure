# AWS Infrastructure for CSYE 6225
Terraform template for CSYE 6225 Fall 2020 to create AWS infrastructure with following resources:
- VPC
- Subnets (x3) in different AZs of a region
- Internet gateway
- Public route table with a public route
- Application security table
- Database security table
- S3 Bucket
- IAM role with policy to access S3 bucket from EC2 (webapp & codedeploy)
- DB subnet group
- RDS instance for DB
- EC2 instance for application
- DynamoDB table
- Codedeploy application with deployment group
- IAM role for codedeploy application
- IAM user policy for ghactions to create deployment

# Usage

### Expected Variables
|          Variable Name           |                                  Description                                 |               Default               |
|:--------------------------------:|:----------------------------------------------------------------------------:|:-----------------------------------:|
| profile                          | AWS CLI profile                                                              | default                             |
| region                           | AWS region for infrastructure                                                | us-east-1                           |
| account_id                       | AWS account id                                                               | -                                   |
| vpc_name                         | Name of VPC                                                                  | csye6225-vpc                        |
| cidr_block                       | CIDR block for VPC                                                           | 10.0.0.0/16                         |
| cidrs                            | CIDR block for each subnet (comma-delimited)                                 | 10.0.0.0/24,10.0.1.0/24,10.0.2.0/24 |
| azs                              | AZs for each subnet (comma-delimited)                                        | a,b,c                               |
| bucket_name                      | Name of s3 bucket                                                            | webapp.deepansh.sachdeva            |
| bucket_acl                       | ACL for s3 bucket                                                            | private                             |
| db_identifier                    | Identifier for RDS                                                           | csye6225-f20                        |
| db_storage_size                  | Storage size for RDS                                                         | 20                                  |
| db_instance_class                | Instance class for RDS                                                       | db.t3.micro                         |
| db_engine                        | DB engine for RDS                                                            | mysql                               |
| db_engine_version                | DB engine version for RDS                                                    | 5.7.22                              |
| db_name                          | DB name for RDS                                                              | csye6225                            |
| db_username                      | DB username for RDS                                                          | csye6225fall2020                    |
| db_password                      | DB password for RDS                                                          | *REDACTED*                          |
| db_public_access                 | DB public accessibility for RDS                                              | false                               |
| db_multiaz                       | DB multi az for RDS                                                          | false                               |
| instance_type                    | EC2 instance type                                                            | t2.micro                            |
| instance_vol_type                | EC2 volume type                                                              | gp2                                 |
| instance_vol_size                | EC2 volume size                                                              | 20                                  |
| instance_subnet                  | EC2 subnet serial                                                            | 1                                   |
| key_name                         | SSH key name                                                                 | -                                   |
| dynamodb_table                   | DynamoDB table                                                               | csye6225                            |
| dynamodb_key                     | DynamoDB hash key table                                                      | id                                  |
| codedeploy_bucket                | S3 bucket for codedeploy builds                                              | codedeploy.deepanshsachdeva.me      |
| ghactions_user                   | Username for github actions                                                  | ghactions                           |
| root_domain                      | Root domain for hosted zone                                                  | deepanshsachdeva.me                 |
| lambda_handler                   | Handler for lambda function                                                  | index.handler                       |
| lambda_runtime                   | Runtime for lambda function                                                  | nodejs12.x                          |
| lambda_memory                    | Memory limit for lambda functio                                              | 256                                 |
| lambda_timeout                   | Timeout for lambda function                                                  | 60                                  |
| lambda_zip                       | Zip code for lambda code                                                     | function_code.zip                   |

#### Initialize a Terraform working directory
```
terraform init
```

#### Validates the Terraform files
```
terraform validate
```

#### Format files to canonical format
```
terraform fmt
```

#### Generate and show an execution plan
```
terraform plan
```

#### Build or change infrastructure
```
terraform apply
```

#### Destroy infrastructure
```
terraform destroy
```

# Author
Deepansh Sachdeva (NUID 001399788)
