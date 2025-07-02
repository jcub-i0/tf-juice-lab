import boto3 # type: ignore
import logging
import os
import datetime

logger = logging.getLogger()
logger.setLevel(logging.INFO)

ec2 = boto3.client('ec2')

def snapshot_attached_volumes(instance_id):
    logger.info(f'Describing volumes for instance {instance_id}')

    try:
        # Get instance details
        reservations = ec2.describe_instances(InstanceIds=[instance_id])['Reservations']
        instances = [i for r in reservations for i in r['Instances']]

        if not instances:
            logger.warning(f'No instance found with ID {instance_id}')
            return

        instance = instances[0]

        # Skip snapshot if instance already quarantined
        tags = {tag['Key']: tag['Value'] for tag in instance.get('Tags', [])}
        if tags.get('Quarantine', '').lower() == 'true':
            logger.info(f'Instance {instance_id} already quarantined; skipping snapshot.')
            return

        for device in instance.get('BlockDeviceMappings', []):
            volume_id = device.get('Ebs', {}).get('VolumeId')
            device_name = device.get('DeviceName')

            if volume_id:
                logger.info(f'Creating snapshot for volume {volume_id} ({device_name})')
                description = f'Snapshot of {volume_id} from instance {instance_id} prior to quarantine operation'

                # Create the snapshot
                response = ec2.create_snapshot(
                    VolumeId=volume_id,
                    Description=description
                )

                snapshot_id = response['SnapshotId']
                logger.info(f'Snapshot {snapshot_id} created, tagging...')

                # Apply tags separately
                ec2.create_tags(
                    Resources=[snapshot_id],
                    Tags=[
                        {'Key': 'Name', 'Value': f'{instance_id}-{volume_id}'},
                        {'Key': 'CreatedBy', 'Value': 'LambdaAutoResponse'},
                        {'Key': 'InstanceId', 'Value': instance_id}
                    ]
                )

                logger.info(f'Snapshot {snapshot_id} for {volume_id} tagged successfully.')

    except Exception as e:
        logger.error(f'Failed to create snapshot: {str(e)}')
        raise

    except Exception as e:
        logger.error(f'Failed to create snapshot: {str(e)}')
        raise

def map_finding_to_ttp(finding):
    ttps = []
    types = finding.get('Types', [])

    for t in types:
        t_lower = t.lower().strip()

        if 'bruteforce' in t_lower:
            if 'spray' in t_lower:
                ttps.append('T1110.003: Brute Force - Password Spraying')
            else:
                ttps.append('T1110: Brute Force')

        elif 'command' in t_lower:
            ttps.append('T1059: Command and Scripting Interpreter')

        elif 'credentialdump' in t_lower:
            ttps.append('T1003: OS Credential Dumping')

    if not ttps:
        ttps.append('No known MITRE tactic detected')

    return list(set(ttps))
        
def lambda_handler(event, context):
    try:
        finding = event['detail']['findings'][0]

        mitre_ttps = map_finding_to_ttp(finding)
        logger.info(f'Detected MITRE TTPs: {mitre_ttps}')

        for resource in finding.get('Resources', []):
            if resource.get('Type') == 'AwsEc2Instance':

                # Extract instance ID from Security Hub event
                instance_id = resource['Id'].split('/')[-1]
                quarantine_sg_id = os.environ['QUARANTINE_SG_ID']

                # Snapshot volume before quarantine operation
                snapshot_attached_volumes(instance_id)

                logger.info(f'Isolating EC2 instance: {instance_id}')

                # Replace all SGs with the quarantine SG
                ec2.modify_instance_attribute(
                    InstanceId = instance_id,
                    Groups = [quarantine_sg_id]
                )

                tags = [
                    {'Key': 'Quarantine', 'Value': 'True'},
                    {'Key': 'IsolatedBy', 'Value': 'Lambda-AutoResponse'},
                    {'Key': 'IsolatedAt', 'Value': datetime.datetime.now(datetime.UTC).isoformat()}
                ]

                if mitre_ttps:
                    tags.append({'Key': 'MitreTTPs', 'Value': ','.join(mitre_ttps)})
                    
                ec2.create_tags(
                    Resources = [instance_id],
                    Tags = tags
                )

                logger.info(f"Instance {instance_id} successfully isolated into SG {quarantine_sg_id}")
                return {
                    'status': 'success',
                    'instance_id': instance_id
                }
            
        logger.info('No EC2 instance found in finding. Skipping isolation.')

    except Exception as e:
        logger.error(f'Error isolating instance: {str(e)}')
        raise e
    