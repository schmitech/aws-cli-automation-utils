import * as ec2 from 'aws-cdk-lib/aws-ec2';
import * as iam from 'aws-cdk-lib/aws-iam';
import { Construct } from 'constructs';
import * as cdk from 'aws-cdk-lib';

interface Ec2InstanceProps {
  vpc: ec2.IVpc;
  securityGroup: ec2.ISecurityGroup;
  instanceType: ec2.InstanceType;
  machineImage: ec2.IMachineImage;
  availabilityZone: string;
  name: string;
  subnetId: string;
}

export class Ec2InstanceConstruct extends Construct {
  public readonly instance: ec2.Instance;
  public readonly instanceId: string;
  public readonly privateIpAddress: string;

  constructor(scope: Construct, id: string, props: Ec2InstanceProps) {
    super(scope, id);

    const role = new iam.Role(this, `${props.name}EC2Role`, {
      assumedBy: new iam.ServicePrincipal('ec2.amazonaws.com'),
    });

    role.addManagedPolicy(iam.ManagedPolicy.fromAwsManagedPolicyName('AmazonSSMManagedInstanceCore'));

    const subnet = ec2.Subnet.fromSubnetAttributes(this, `${props.name}Subnet`, {
      subnetId: props.subnetId,
      availabilityZone: props.availabilityZone
    });

    this.instance = new ec2.Instance(this, props.name, {
      vpc: props.vpc,
      instanceType: props.instanceType,
      machineImage: props.machineImage,
      securityGroup: props.securityGroup,
      availabilityZone: props.availabilityZone,
      vpcSubnets: { subnets: [subnet] },
      role: role,
      instanceInitiatedShutdownBehavior: ec2.InstanceInitiatedShutdownBehavior.TERMINATE,
      userData: ec2.UserData.forLinux(),
      requireImdsv2: true,
    });

    cdk.Tags.of(this.instance).add('Name', props.name);

    // Store the instance ID and private IP address
    this.instanceId = this.instance.instanceId;
    this.privateIpAddress = this.instance.instancePrivateIp;
  }
}