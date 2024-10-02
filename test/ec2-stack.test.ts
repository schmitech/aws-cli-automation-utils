import * as cdk from 'aws-cdk-lib';
import { Template } from 'aws-cdk-lib/assertions';
import * as ec2 from 'aws-cdk-lib/aws-ec2';
import * as Ec2Stack from '../lib/ec2-stack';

describe('Ec2Stack', () => {
  let stack: cdk.Stack;
  let template: Template;

  beforeAll(() => {
    const app = new cdk.App();
    stack = new Ec2Stack.Ec2Stack(app, 'MyTestStack');

    // Mock VPC lookup
    jest.spyOn(ec2.Vpc, 'fromLookup').mockImplementation((scope: any, id: string, options: any) => {
      return new ec2.Vpc(scope, id);
    });

    // Mock subnet selection
    jest.spyOn(ec2.Vpc.prototype, 'selectSubnets').mockImplementation(() => {
      return {
        subnets: [
          {
            subnetId: 'mock-subnet-id',
            availabilityZone: 'ca-central-1b',
          },
        ],
      } as any;
    });

    // Mock security group lookup
    jest.spyOn(ec2.SecurityGroup, 'fromSecurityGroupId').mockImplementation((scope: any, id: string, securityGroupId: string) => {
      return new ec2.SecurityGroup(scope, id, { vpc: new ec2.Vpc(scope, 'MockVpc') });
    });

    template = Template.fromStack(stack);
  });

  test('EC2 Instance Created', () => {
    template.hasResourceProperties('AWS::EC2::Instance', {
      InstanceType: 'c5.large',
      AvailabilityZone: 'ca-central-1b',
    });
  });

  test('EC2 Instance Uses Correct AMI', () => {
    template.hasResourceProperties('AWS::EC2::Instance', {
      ImageId: {
        'Fn::FindInMap': [
          'AmiMap',
          {
            Ref: 'AWS::Region',
          },
          'ami',
        ],
      },
    });
  });

  test('No VPC Created', () => {
    template.resourceCountIs('AWS::EC2::VPC', 0);
  });

  test('No Security Group Created', () => {
    template.resourceCountIs('AWS::EC2::SecurityGroup', 0);
  });
});