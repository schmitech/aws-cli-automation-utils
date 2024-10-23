import * as cdk from 'aws-cdk-lib';
import { Template, Match } from 'aws-cdk-lib/assertions';
import * as ec2 from 'aws-cdk-lib/aws-ec2';
import * as path from 'path';
import { Ec2Stack } from '../lib/ec2-stack';
import { DefaultStackSynthesizer } from 'aws-cdk-lib';
import * as yaml from 'js-yaml';
import * as fs from 'fs';

// Load actual test config file
const configPath = path.join(__dirname, 'ec2-config-test.yaml');
const config = yaml.load(fs.readFileSync(configPath, 'utf8')) as {
  common: {
    bootstrap_s3_bucket_name: string;
    vpc_id: string;
    region: string;
    account: string;
  };
  ec2_instances: Array<{
    name: string;
    instance_class: string;
    instance_size: string;
    ami_id: string;
    subnet_id: string;
    security_group_id: string;
    availability_zone: string;
  }>;
};

// Mock VPC lookup
jest.mock('aws-cdk-lib/aws-ec2', () => {
  const originalModule = jest.requireActual('aws-cdk-lib/aws-ec2');
  return {
    ...originalModule,
    Vpc: {
      ...originalModule.Vpc,
      fromLookup: jest.fn().mockImplementation((scope, id, props) => {
        return new originalModule.Vpc(scope, id, {
          maxAzs: 2,
          natGateways: 1,
        });
      }),
    },
  };
});

describe('Ec2Stack', () => {
  let app: cdk.App;
  let stack: Ec2Stack;
  let template: Template;

  beforeEach(() => {
    app = new cdk.App();
    stack = new Ec2Stack(app, 'TestStack', {
      env: {
        account: config.common.account,
        region: config.common.region
      },
      synthesizer: new DefaultStackSynthesizer({
        fileAssetsBucketName: config.common.bootstrap_s3_bucket_name
      })
    });
    template = Template.fromStack(stack);
  });

  test('creates EC2 instances with correct configurations', () => {
    template.resourceCountIs('AWS::EC2::Instance', config.ec2_instances.length);

    template.hasResourceProperties('AWS::EC2::Instance', {
      InstanceType: Match.stringLikeRegexp('t3\..*'),
      AvailabilityZone: Match.stringLikeRegexp('ca-central-1[a-z]'),
      IamInstanceProfile: Match.objectLike({
        Ref: Match.stringLikeRegexp('.*InstanceProfile.*')
      }),
      InstanceInitiatedShutdownBehavior: 'terminate',
    });
  });

  test('creates IAM roles with correct policies', () => {
    template.resourceCountIs('AWS::IAM::Role', 8);

    template.hasResourceProperties('AWS::IAM::Role', {
      AssumeRolePolicyDocument: {
        Statement: [
          {
            Action: 'sts:AssumeRole',
            Effect: 'Allow',
            Principal: {
              Service: 'ec2.amazonaws.com'
            }
          }
        ],
        Version: '2012-10-17'
      },
      ManagedPolicyArns: Match.arrayWith([
        {
          'Fn::Join': [
            '',
            Match.arrayWith([
              Match.stringLikeRegexp('.*'),
              {
                Ref: 'AWS::Partition'
              },
              ':iam::aws:policy/AmazonSSMManagedInstanceCore'
            ])
          ]
        }
      ])
    });
  });

  test('creates Lambda function for instance status check', () => {
    template.resourceCountIs('AWS::Lambda::Function', 2);

    template.hasResourceProperties('AWS::Lambda::Function', {
      Handler: 'index.handler',
      Runtime: 'python3.9',
      Timeout: 900
    });
  });

  test('creates custom resource for instance status check', () => {
    template.hasResourceProperties('Custom::AWS', {
      ServiceToken: Match.objectLike({
        'Fn::GetAtt': Match.arrayWith([
          Match.stringLikeRegexp('AWS679f53fac002430cb0da5b7982bd2287.*')
        ])
      })
    });
  });

  test('creates stack outputs', () => {
    template.hasOutput('InstanceInfo', {});
  });

  test('stack has correct number of resources', () => {
    const resources = template.toJSON().Resources;
    expect(Object.keys(resources).length).toBeGreaterThan(0);

    template.resourceCountIs('AWS::EC2::Instance', 6);
    template.resourceCountIs('AWS::IAM::Role', 8);
    template.resourceCountIs('AWS::Lambda::Function', 2);
  });

  test('verifies instance types', () => {
    template.hasResourceProperties('AWS::EC2::Instance', {
      InstanceType: 't3.xlarge'
    });

    template.hasResourceProperties('AWS::EC2::Instance', {
      InstanceType: 't3.large'
    });

    template.hasResourceProperties('AWS::EC2::Instance', {
      InstanceType: 't3.2xlarge'
    });
  });

  test('verifies security groups and subnets exist', () => {
    template.hasResourceProperties('AWS::EC2::Instance', {
      SecurityGroupIds: Match.arrayWith([Match.stringLikeRegexp('sg-.*')]),
      SubnetId: Match.stringLikeRegexp('subnet-.*')
    });
  });
});