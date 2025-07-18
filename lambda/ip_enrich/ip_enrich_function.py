import boto3 # type: ignore
import os
import logging
import requests
import json

logger = logging.getLogger()
logger.setLevel(logging.INFO)


ABUSE_IPDB_API_KEY = os.environ.get('ABUSE_IPDB_API_KEY')

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

# Query AbuseIPDP for IP address data
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

def lambda_handler(event, context):
    findings = event['detail']['findings']

    for finding in findings:
        ips = extract_ip(finding)


    return None