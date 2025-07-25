import boto3 # type: ignore
import os
import logging
import requests
import json

logger = logging.getLogger()
logger.setLevel(logging.INFO)
sns = boto3.client('sns')


ABUSE_IPDB_API_KEY = os.environ.get('ABUSE_IPDB_API_KEY')
SNS_TOPIC_ARN = os.environ.get('SNS_TOPIC_ARN')

# Extract the IP addresses from Security Hub finding
def extract_ip(finding):
    ips = []

    network = finding.get('Network', {})
    src_ip = network.get('SourceIpV4') or network.get('SourceIpV6')
    if src_ip:
        ips.append(src_ip)
    dst_ip = network.get('DestinationIpV4') or network.get('DestinationIpV6')
    if dst_ip and dst_ip != src_ip:
        ips.append(dst_ip)

    return ips

# Query AbuseIPDB for IP address data
def query_abuse_ipdb(ip):
    url = 'https://api.abuseipdb.com/api/v2/check'

    headers = {
        'Accept': 'application/json',
        'Key': ABUSE_IPDB_API_KEY
    }

    params = {
        'ipAddress': ip,
        'maxAgeInDays': '90'
    }

    try:
        response = requests.get(url, headers=headers, params=params, timeout=10)
        response.raise_for_status()
        data = response.json()
        return data.get('data', {})
    
    except Exception as e:
        logger.error(f'Error querying AbuseIPDB for IP {ip}: {str(e)}')
        return None

def publish_to_alerts_sns(data):
    if not SNS_TOPIC_ARN:
        logger.warning(f'SNS topic not set. Skipping alert notification.')
        return
    
    message = (
        f"🔍 IP Enrichment Report\n\n"
        f"Below is the data pertaining to one or more IP addresses associated with a Security Hub finding:\n\n"
        f"{json.dumps(data, indent=2)}"
    )

    try:
        sns.publish(
            TopicArn = SNS_TOPIC_ARN,
            Subject = 'AbuseIPDB Lookup Results',
            Message = message
        )
        logger.info('SNS notification sent.')

    except Exception as e:
        logger.error(f'Failed to publish to SNS: {str(e)}')

def lambda_handler(event, context):
    data = []
    all_ips = set()
    ip_to_finding_map = {}
    findings = event['detail']['findings']

    if not findings:
        logger.warning(f'No findings found in event.')
        return {'statusCode': 400, 'body': json.dumps({'message': 'No findings in event'})}

    for finding in findings:
        finding_id = finding.get('Id','Unknown')
        ips = extract_ip(finding)
        for ip in ips:
            ip_to_finding_map[ip] = finding_id

        all_ips.update(ips)

    logger.info(f'Total unique IPs extracted: {len(all_ips)}')

    for ip in all_ips:
        result = query_abuse_ipdb(ip)

        if result:
            data.append({
                'findingId': ip_to_finding_map.get(ip),
                'ip': ip,
                'intel': {
                    'abuseIPDB': {
                        'abuseConfidenceScore': result.get('abuseConfidenceScore'),
                        'countryName': result.get('countryName'),
                        'countryCode': result.get('countryCode'),
                        'usageType': result.get('usageType'),
                        'domain': result.get('domain'),
                        'hostnames': result.get('hostnames'),
                        'isp': result.get('isp'),
                        'isTor': result.get('isTor'),
                        'lastReportedAt': result.get('lastReportedAt')
                    }

                }
            })

    if data:
        message = json.dumps(data, indent=2)
        publish_to_alerts_sns(data)


    return {
        'statusCode': 200,
        'body': json.dumps({'message': 'Processing complete', 'resultCount': len(data)})
    }