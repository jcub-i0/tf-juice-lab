import boto3 # type: ignore
import datetime
import logging
import os

# Set up logger to log messages at the INFO level or higher
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Create clients to interact with EC2 and CloudWatch services
ec2 = boto3.client('ec2')
cloudwatch = boto3.client('cloudwatch')

# Function that determines if instance has been idle for 60 minutes
def is_instance_idle(instance_id):
    end_time = datetime.datetime.now(datetime.UTC)
    start_time = end_time - datetime.timedelta(minutes=IDLE_PERIOD_MINUTES)

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
    logger.info(f'Instance {instance_id} average CPU utilizatin over last {IDLE_PERIOD_MINUTES} minutes is {avg_cpu:.2f}%')

    return avg_cpu < CPU_THRESHOLD

def lambda_handler(event, context):
    print("Hello world")
    print("This should be working. IF this is printed, EventBridge rules are good to go, as well as IAM permissions.")