#!/usr/bin/env node
import 'source-map-support/register';
import * as cdk from 'aws-cdk-lib';
import { Ec2Stack } from '../lib/ec2-stack';
import { DefaultStackSynthesizer } from 'aws-cdk-lib';
import * as yaml from 'js-yaml';
import * as fs from 'fs';
import * as path from 'path';

interface CommonConfig {
  account: string;
  region: string;
  bootstrap_s3_bucket_name: string;
}

interface StackConfig {
  common: CommonConfig;
  ec2_instances: any[];
}

const app = new cdk.App();

const configPath = path.join(__dirname, '..', 'ec2-config.yaml');
const config = yaml.load(fs.readFileSync(configPath, 'utf8')) as StackConfig;

const customSynthesizer = new DefaultStackSynthesizer({
  fileAssetsBucketName: config.common.bootstrap_s3_bucket_name
});

new Ec2Stack(app, 'Ec2Stack', {
  env: {
    account: config.common.account,
    region: config.common.region
  },
  synthesizer: customSynthesizer
});

app.synth();