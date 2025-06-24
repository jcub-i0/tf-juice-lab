import boto3
import logging
import os

logger = logging.getLogger()
logger.setLevel(logging.INFO)

ec2 = boto3.client('ec2')

def lambda_handler(event, context):
    try:
        # Extract instance ID from Security Hub event
        instance_id = event['detail']['findings'][0]['Resources'][0]['Id'].split('/')[-1]
        quarantine_sg_id = os.environ['QUARANTINE_SG_ID']

        logger.info(f'Isolating EC2 instance: {instance_id}')

        # Replace all SGs with the quarantine SG
        ec2.modify_instance_attribute(
            InstanceId = instance_id,
            Groups = [quarantine_sg_id]
        )

        ec2.create_tags(
            Resources = [instance_id],
            Tags = [
                {'Key': 'Quarantine', 'Value': 'True'},
                {'Key': 'IsolatedBy', 'Value': 'Lambda-AutoResponse'}
            ]
        )

        logger.info(f"Instance {instance_id} successfully isolated into SG {quarantine_sg_id}")
        return {
            'status': 'success',
            'instance_id': instance_id
        }

    except Exception as e:
        logger.error(f'Error isolating instance: {str(e)}')
        raise e
