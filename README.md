# Cloud Automation Project

This is a project for CDK development with TypeScript to automate the provisioning of cloud resources.

## Prerequisites (only for first time setup)

Ensure you have the following installed:

Node.js (Latest stable version)

Install npm (comes with Node.js)

Install AWS CLI

Install AWS CDK CLI

Install AWS Session Manager Plugin (https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html)

Install Node dependencies:
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

## Access pre-configured EC2 dev instance

There is a instance in DEV account can use as testing environment. The instance is called 'dr-automation-solution'. You can connect to it via CloudShell or locally using AWS session manager. If using CloudShell, you can use the DEV account ID (something like 12345678109) as SSO has already been configured following the previous steps (replace i-1234567 with real instance id):

```
aws ssm start-session --target i-1234567 --profile profile-name-XXXXXXX --region ca-central-1
```

Once connected, you need to change to ec2-user and login to aws using SSO profile (used previous steps to create one if it doesn't exist):
```
sudo su - ec2-user
aws sso login  --profile profile-name-XXXXXXX
```

The project is under 'dr-automation' folder in home directory.

## Building the Project
Go to project directory and run this command:

Then install the libraries:

```
npm install
```

If you encounter TypeScript errors, ensure your tsconfig.json is correctly set up and run npm run build before cdk commands.

## Deploying EC2 Instances

First you need to update parameters in ec2-config.yaml with your own values (AMI IDs as well as Snapshot IDs). Save the file, then generate the CDK bootstrap. Use the account selected in previous SSO configuration step (replace profile-name-XXXXXXX with your own):
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
script deployment_output.txt cdk deploy --profile profile-name-XXXXXXX
```

Output will be saved in deployment_output.txt, including the IDs and IP addresses of each instance created. You will need this information for the rest of DR steps.

## Removing the stack
Once you are done with the DR environment and you determine is no longer needed, you may now remove it from AWS. Run this command to remove the stack and associatd resources:
```
./destroy-and-cleanup.sh [your-profile-name]
```