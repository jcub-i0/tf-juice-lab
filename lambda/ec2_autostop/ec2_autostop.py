import boto3 # type: ignore
import datetime
import logging
import os
from dateutil import parser as date_parser

# Configure root logger when the Lambda starts
logging.basicConfig(level=logging.INFO)

# Define environment variables
idle_cpu_threshold = float(os.environ.get('IDLE_CPU_THRESHOLD', '5'))
idle_period_minutes = float(os.environ.get('IDLE_PERIOD_MINUTES', '60'))
RENOTIFY_AFTER_HOURS = float(os.environ.get('RENOTIFY_AFTER_HOURS', '2'))

# Set up logger to log messages at the INFO level or higher
logger = logging.getLogger()
logger.setLevel(logging.INFO)
logger.info(f'CPU threshold: {idle_cpu_threshold}')

# Create clients to interact with EC2 and CloudWatch services
ec2 = boto3.client('ec2')
cloudwatch = boto3.client('cloudwatch')

# Define SNS variables
sns = boto3.client('sns')
SNS_TOPIC_ARN = os.environ.get('SNS_TOPIC_ARN')

def publish_to_alerts_sns(instance_id):
    # Check if SNS_TOPIC_ARN is set
    if not SNS_TOPIC_ARN:
        logger.warning('SNS_TOPIC_ARN not set. Skipping alert notification.')
        return

    message = (
        f"🚨 EC2 instance {instance_id} was automatically stopped due to inactivity. \n\n"
        f"Timestamp: {datetime.datetime.now(datetime.UTC).isoformat()}"
    )

    sns.publish(
        TopicArn = SNS_TOPIC_ARN,
        Subject = 'LAMBDA TRIGGERED: EC2 AUTOSTOP',
        Message = message
    )

# Function that determines if instance has been idle for 60 minutes
def is_instance_idle(instance_id):
    end_time = datetime.datetime.now(datetime.UTC)
    start_time = end_time - datetime.timedelta(minutes=idle_period_minutes)

    # Call CloudWatch to get CPUUtilization data for the instance every (5) minutes
    response = cloudwatch.get_metric_statistics(
        Namespace = 'AWS/EC2',
        MetricName = 'CPUUtilization',
        Dimensions = [
            {
                'Name': 'InstanceId',
                'Value': instance_id
            }
        ],
        StartTime = start_time,
        EndTime = end_time,
        Period = 300,
        Statistics = ['Average']
    )

    # Extract the CPU datapoints from the response and return an empty list if there is no monitoring data
    datapoints = response.get('Datapoints', [])

    # If no data is returned, do not stop the instance
    if not datapoints:
        logger.info(f'No CPU data for instance {instance_id}. Assuming instance is not idle.')
        return False
    
    # Calculate the average CPU utilization over the time window and output it to logs as a (2) decimal percentage
    avg_cpu = sum(dp['Average'] for dp in datapoints) / len(datapoints)
    logger.info(f'Instance {instance_id} average CPU utilizatin over last {idle_period_minutes} minutes is {avg_cpu:.2f}%')

    return avg_cpu < idle_cpu_threshold

def lambda_handler(event, context):
    try:

        # List all EC2 instances that are currently running
        reservations = ec2.describe_instances(
            Filters = [
                {
                    'Name': 'instance-state-name',
                    'Values': ['running']
                }
            ]
        )['Reservations']

        # Define 'instances' list by pulling all running instances from 'reservations' variable above
        instances = [i for r in reservations for i in r['Instances']]

        # Loop through each running instance and extract its ID
        for instance in instances:
            instance_id = instance['InstanceId']

            # Get current tags from EC2 instance
            tags = {tag['Key']: tag['Value'] for tag in instance.get('Tags', [])}

            # Check if instance already stopped by Lambda
            if tags.get('StoppedBy') == 'LambdaAutoStop':
                stopped_at_str = tags.get('StoppedAt')

                if stopped_at_str:
                    try:
                        # Parse ISO timestamp (string) into a datetime object for time comparisons
                        stopped_at = date_parser.parse(stopped_at_str)
                        time_since_stopped = datetime.datetime.now(datetime.UTC) - stopped_at

                        # Do not send another SNS notification if it has been less than RENOTIFY_AFTER_HOURS hours
                        if time_since_stopped < datetime.timedelta(hours=RENOTIFY_AFTER_HOURS):
                            logger.info(f'Instance {instance_id} was stopped {time_since_stopped} hours ago. Skipping re-notification.')
                            continue

                    except Exception as parse_err:
                        logger.warning(f'Error parsing StoppedAt tag for instance {instance_id}: {parse_err}')

            # Check if each EC2 instance is idle and log it if so
            if is_instance_idle(instance_id):
                logger.info(f'Stopping idle instance {instance_id}')

                # Stop idle EC2 instance
                ec2.stop_instances(
                    InstanceIds = [instance_id]
                )

                publish_to_alerts_sns(instance_id)

                # Create tags for ec2.create_tags() function
                tags = [
                    {
                        'Key': 'StoppedBy',
                        'Value': 'LambdaAutoStop'
                    },
                    {
                        'Key': 'StoppedAt',
                        'Value': datetime.datetime.now(datetime.UTC).isoformat()
                    }
                ]

                # Tag stopped EC2 instance to indicate who stopped it and at what time
                ec2.create_tags(
                    Resources = [instance_id],
                    Tags = tags
                )
            
            # Log that the instance is still active and will not be stopped.
            else:
                logger.info(f'Instance {instance_id} is active. No action taken.')

        # Return success message to Lambda
        return {'status': 'success'}

    except Exception as e:
        logger.error(f'Error stopping idle instance(s): {str(e)}')
        raise