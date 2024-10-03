import * as ec2 from 'aws-cdk-lib/aws-ec2';
import * as iam from 'aws-cdk-lib/aws-iam';
import { Construct } from 'constructs';
import * as cdk from 'aws-cdk-lib';

interface VolumeConfig {
  deviceName: string;
  sizeGb: number;
  volumeType: ec2.EbsDeviceVolumeType;
  deleteOnTermination: boolean;
}

interface Ec2InstanceProps {
  vpc: ec2.IVpc;
  securityGroup: ec2.ISecurityGroup;
  instanceType: ec2.InstanceType;
  machineImage: ec2.IMachineImage;
  availabilityZone: string;
  name: string;
  subnetId: string;
  volumes: VolumeConfig[];
}

export class Ec2InstanceConstruct extends Construct {
  public readonly instance: ec2.Instance;

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

    const blockDevices: ec2.BlockDevice[] = props.volumes.map(volume => ({
      deviceName: volume.deviceName,
      volume: ec2.BlockDeviceVolume.ebs(volume.sizeGb, {
        volumeType: volume.volumeType,
        deleteOnTermination: volume.deleteOnTermination,
      }),
    }));

    this.instance = new ec2.Instance(this, props.name, {
      vpc: props.vpc,
      instanceType: props.instanceType,
      machineImage: props.machineImage,
      securityGroup: props.securityGroup,
      availabilityZone: props.availabilityZone,
      vpcSubnets: { subnets: [subnet] },
      role: role,
      instanceInitiatedShutdownBehavior: ec2.InstanceInitiatedShutdownBehavior.STOP,
      userData: ec2.UserData.forLinux(),
      requireImdsv2: true,
      blockDevices: blockDevices,
    });

    cdk.Tags.of(this.instance).add('Name', props.name);
  }
}