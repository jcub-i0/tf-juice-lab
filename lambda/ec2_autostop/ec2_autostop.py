import boto3 # type: ignore
import datetime
import logging
import os

# Define environment variables
idle_cpu_threshold = float(os.environ.get('IDLE_CPU_THRESHOLD', '5'))
idle_period_minutes = float(os.environ.get('IDLE_PERIOD_MINUTES', '60'))

# Set up logger to log messages at the INFO level or higher
logger = logging.getLogger()
logger.setLevel(logging.INFO)

logger.info(f'CPU threshold: {idle_cpu_threshold}')

# Create clients to interact with EC2 and CloudWatch services
ec2 = boto3.client('ec2')
cloudwatch = boto3.client('cloudwatch')

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

            # Check if each EC2 instance is idle and log it if so
            if is_instance_idle(instance_id):
                logger.info(f'Stopping idle instance {instance_id}')

                # Stop idle EC2 instance
                ec2.stop_instances(
                    InstanceIds = [instance_id]
                )

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
        logging.error(f'Error stopping idle instance(s): {str(e)}')
        raise