import * as cdk from 'aws-cdk-lib';
import * as ec2 from 'aws-cdk-lib/aws-ec2';
import * as lambda from 'aws-cdk-lib/aws-lambda';
import * as iam from 'aws-cdk-lib/aws-iam';
import * as cr from 'aws-cdk-lib/custom-resources';
import { Construct } from 'constructs';
import * as yaml from 'js-yaml';
import * as fs from 'fs';
import * as path from 'path';
import { Ec2InstanceConstruct } from './ec2-instance-construct';

interface Ec2Config {
  name: string;
  instance_class: keyof typeof ec2.InstanceClass;
  instance_size: keyof typeof ec2.InstanceSize;
  ami_id: string;
  security_group_id: string;
  subnet_id: string;
  availability_zone: string;
}

interface CommonConfig {
  vpc_id: string;
  region: string;
  account: string;
}

interface StackConfig {
  common: CommonConfig;
  ec2_instances: Ec2Config[];
}

export class Ec2Stack extends cdk.Stack {
  private instanceInfo: { [key: string]: { instanceId: string; privateIpAddress: string } } = {};

  constructor(scope: Construct, id: string, props?: cdk.StackProps) {
    super(scope, id, props);

    const configPath = path.join(__dirname, '..', 'ec2-config.yaml');
    const config = yaml.load(fs.readFileSync(configPath, 'utf8')) as StackConfig;

    const vpc = ec2.Vpc.fromLookup(this, 'vpc', { vpcId: config.common.vpc_id });

    const instances = config.ec2_instances.map((instanceConfig, index) => {
      try {
        const securityGroup = ec2.SecurityGroup.fromSecurityGroupId(
          this,
          `security-group-${index}`,
          instanceConfig.security_group_id
        );

        const instance = new Ec2InstanceConstruct(this, `EC2Instance${index}`, {
          vpc,
          securityGroup,
          instanceType: ec2.InstanceType.of(
            ec2.InstanceClass[instanceConfig.instance_class],
            ec2.InstanceSize[instanceConfig.instance_size]
          ),
          machineImage: ec2.MachineImage.genericLinux({
            [config.common.region]: instanceConfig.ami_id
          }),
          availabilityZone: instanceConfig.availability_zone,
          name: instanceConfig.name,
          subnetId: instanceConfig.subnet_id,
        });

        this.instanceInfo[instanceConfig.name] = {
          instanceId: instance.instanceId,
          privateIpAddress: instance.privateIpAddress,
        };

        return instance.instance;
      } catch (error) {
        console.error(`Failed to create EC2 instance ${instanceConfig.name}:`, error);
        return null;
      }
    }).filter((instance): instance is ec2.Instance => instance !== null);

    // Create a Lambda function to check instance status
    const checkInstanceStatusLambda = new lambda.Function(this, 'CheckInstanceStatusLambda', {
      runtime: lambda.Runtime.PYTHON_3_9,
      handler: 'index.handler',
      code: lambda.Code.fromAsset(path.join(__dirname, '..', 'lambda')),
      timeout: cdk.Duration.minutes(15),
    });

    // Grant the Lambda function permission to describe EC2 instances
    checkInstanceStatusLambda.addToRolePolicy(new iam.PolicyStatement({
      actions: ['ec2:DescribeInstances', 'ec2:DescribeInstanceStatus'],
      resources: ['*'],
    }));

    // Create a custom resource to wait for all instances to be ready
    const waitForInstancesResource = new cr.AwsCustomResource(this, 'WaitForInstancesResource', {
      onUpdate: {
        service: 'Lambda',
        action: 'invoke',
        parameters: {
          FunctionName: checkInstanceStatusLambda.functionName,
          Payload: JSON.stringify({ instanceIds: instances.map(i => i.instanceId) }),
        },
        physicalResourceId: cr.PhysicalResourceId.of('WaitForInstances'),
      },
      policy: cr.AwsCustomResourcePolicy.fromStatements([
        new iam.PolicyStatement({
          actions: ['lambda:InvokeFunction'],
          resources: [checkInstanceStatusLambda.functionArn],
        }),
      ]),
    });

    // Ensure the custom resource waits for the Lambda function to be created
    waitForInstancesResource.node.addDependency(checkInstanceStatusLambda);

    // Output the instance information
    new cdk.CfnOutput(this, 'InstanceInfo', {
      value: JSON.stringify(this.instanceInfo, null, 2),
      description: 'EC2 Instance Information',
    });
  }
}