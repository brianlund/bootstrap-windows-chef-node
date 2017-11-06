UPDATE 2017-11-06: AWS now includes a userdata.ps1 script with their OpsWorks for Chef Automate starter_kit. You probably want to use that instead. The main difference in functionality is that they use the embedded openssl from chef - a much better solution (which I would have used if I knew it was included..)

# Adding Nodes Automatically in AWS OpsWorks for Chef Automate
Associate a new instance with a chef server from AWS userdata.

Powershell version of the script provided at http://docs.aws.amazon.com/opsworks/latest/userguide/opscm-unattend-assoc.html

This script allows you to automatically add nodes to AWS OpsWorks for Chef Automate. Simply provide it as userdata to an AWS instance and launch the instance.
You can also add the the script to the userdata section of an Auto Scaling group launch configurations, or an AWS CloudFormation template to automatically associate new instances in an autoscaling group with a Chef server.

## Requirements

Your IAM instance profile must allow the following as a minimum:

    {
        "Version": "2012-10-17",
            "Statement": [
            {
                "Action": [
                    "opsworks-cm:AssociateNode",
                    "opsworks-cm:DescribeNodeAssociationStatus"
                    ],
                "Effect": "Allow",
                "Resource": [
                    "*"
                    ]
            }
        ]
    }

## Usage

Wrap the script in &lt;powershell>&lt;/powershell> tags and add it to userdata when launching an instance, either from the AWS console, an autoscaling launch configuration or cloudformation.
There is a bit more info about the script here: https://cze.dk/bootstrapping-windows-ec2-instances-with-chef-for-autoscaling-groups/

## Challenge in actually using it in userdata from anywhere but console

Cloudformation unfortunately has some limitations on how long a string you can pass as userdata and if you base64 encode the script, it's too large.
If you just paste it into a parameter field when launching a CF you need to add ; to the end of each line as it messes up formatting. I'm currently working on better options.



### Excuses

The script requires OpenSSL to generate a private/public keypair.
OpenSSL typically doesn't exist on Windows instances, so a binary is downloaded and installed in the Windows temp directory ($env:temp), this could certainly be done smarter.

