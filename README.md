# AWS Infrastructure for CSYE 6225
Terraform template for CSYE 6225 Fall 2020 to create AWS infrastructure with following resources:
- VPC
- Subnets (x3) in different AZs of a region
- Internet gateway
- Public route table with a public route

# Usage

### Expected Variables
|          Parameter Name          |                                  Description                                 |               Default               |
|:--------------------------------:|:----------------------------------------------------------------------------:|:-----------------------------------:|
| profile                          | AWS CLI profile                                                              | default                             |
| region                           | AWS region for infrastructure                                                | us-east-1                           |
| vpc_name                         | Name of VPC                                                                  | csye6225-vpc                        |
| vpc_name                         | Name of VPC                                                                  | csye6225-vpc                        |
| cidr_block                       | CIDR block for VPC                                                           | 10.0.0.0/16                         |
| cidrs                            | CIDR block for each subnet (comma-delimited)                                 | 10.0.0.0/24,10.0.1.0/24,10.0.2.0/24 |
| azs                              | AZs for each subnet (comma-delimited)                                        | a,b,c                               |

#### Initialize a Terraform working directorye
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
