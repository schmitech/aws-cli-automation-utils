import * as cdk from 'aws-cdk-lib';
import * as ec2 from 'aws-cdk-lib/aws-ec2';
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
  constructor(scope: Construct, id: string, props?: cdk.StackProps) {
    super(scope, id, props);

    const configPath = path.join(__dirname, '..', 'ec2-config.yaml');
    const config = yaml.load(fs.readFileSync(configPath, 'utf8')) as StackConfig;

    const vpc = ec2.Vpc.fromLookup(this, 'vpc', { vpcId: config.common.vpc_id });

    config.ec2_instances.forEach((instanceConfig, index) => {
      try {
        const securityGroup = ec2.SecurityGroup.fromSecurityGroupId(
          this,
          `security-group-${index}`,
          instanceConfig.security_group_id
        );

        new Ec2InstanceConstruct(this, `EC2Instance${index}`, {
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
      } catch (error) {
        console.error(`Failed to create EC2 instance ${instanceConfig.name}:`, error);
      }
    });
  }
}