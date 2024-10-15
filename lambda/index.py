import boto3
import time

def handler(event, context):
    ec2 = boto3.client('ec2')
    instance_ids = event['instanceIds']
    
    max_attempts = 60
    attempt = 0
    
    while attempt < max_attempts:
        response = ec2.describe_instance_status(InstanceIds=instance_ids)
        
        all_running = True
        for status in response['InstanceStatuses']:
            if status['InstanceState']['Name'] != 'running' or \
               status['InstanceStatus']['Status'] != 'ok' or \
               status['SystemStatus']['Status'] != 'ok':
                all_running = False
                break
        
        if all_running:
            return {
                'statusCode': 200,
                'body': 'All instances are running and ready'
            }
        
        attempt += 1
        time.sleep(10)
    
    raise Exception('Timeout waiting for instances to be ready')