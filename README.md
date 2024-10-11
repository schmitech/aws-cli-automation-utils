# Cloud Automation Project

This is a project for CDK development with TypeScript to automate the provisioning of cloud resources.

## Prerequisites

Ensure you have the following installed:

Node.js (Latest stable version)

Install npm (comes with Node.js)

Install AWS CLI

Install AWS CDK CLI

```
npm install -g aws-cdk
```

## AWS Account Setup

Login to AWS with your account if you've already configured an AWS SSO profile:

aws sso login --profile your-profile-name

Otherwise you will need to follow these steps. Before beginning, copy the URL from the AccessKeys link on the landing page that is shown after accessing AWS though the MS365 or office.com AWS app.

Open a terminal and run this command:

```
aws configure sso
```

You will be prompted to enter the following:

```
SSO session name (Recommended): your-session-name
SSO start URL [None]: start url copied above
SSO region [None]: ca-central-1
SSO registration scopes [sso:account:access]: leave blank

There are 3 AWS accounts available to you. (select the account of choice using arrow keys, then pressing enter)
Using the account ID XXXXXXXX
The only role available to you is: RoleName
Using the role name RoleName"
CLI default client Region [ca-central-1]: (leave blank)
CLI default output format [None]: (leave blank)
CLI profile name [profile-name-XXXXXXX]: (Specify your own or leave blank for default)
```

Test access to AWS by specifing the profile name using --profile, for example:

```
aws s3 ls --profile profile-name-XXXXXXX
```

Make sure files have been created under yout aws config directory in your home directory. You should see 3 files: sso, config and cli:

```
ls -lrt ~/.aws/                    
```

To obtain account details, issue this command:
```
aws sts get-caller-identity --profile profile-name-XXXXXXX
```

Test configuration exists:

```
aws configure list
```

## Building the Project
Go to project directory and run this command:

Then install the libraries:

```
npm install
```

If you encounter TypeScript errors, ensure your tsconfig.json is correctly set up and run npm run build before cdk commands.

## Deploying the CDK Workflow

Update parameters defined in ec2-config.yaml with your own values.

Run cdk comnand to generate the CDK bootstrap. Use the account selected in previous SSO configuration step (replace AdministratorAccess-1234567 with your own):
```
cdk bootstrap --cloudformation-execution-policies arn:aws:iam::aws:policy/AdministratorAccess aws://XXXXXXX/ca-central-1 --profile profile-name-XXXXXXX --bootstrap-bucket-name your-s3-bucket-name
```

Synthesize your stack to make sure there are no issues:

```
cdk synth
```

Run this command to update CDK Bootstrap whenever you update the code under lib folder (i.e. ec2-stack.ts): 

```
cdk diff --profile profile-name-XXXXXXX
```

Deploy the stack (replace profile with your own as shown previously):

```
cdk deploy --profile profile-name-XXXXXXX
```

To check the status of the stack:
```
aws cloudformation describe-stacks --stack-name Ec2Stack --profile profile-name-XXXXXXX --query 'Stacks[0].StackStatus' --output text
```

## Removing the stack
Run this comnand to remove the stack and associatd resources:
```
./destroy-and-cleanup.sh [your-profile-name]
```
