#!/usr/bin/python3
import subprocess, boto3, json, os

CLUSTER = os.environ.get('CLUSTER').replace('_', '-')
DNS = f"rr.{CLUSTER}.{{cluster_dns_zone}}"
ZONE_ID = os.environ.get("ZONE_ID", "{{dns_zone_result.zone_id}}")
route53 = boto3.client('route53')
TERM_SCHEDULED = os.path.exists("/tmp/terminate-scheduled")

def get_ips():
    return list(set(f.split()[5] for f in subprocess.check_output("k0s kubectl get nodes -o wide", shell=True).decode().splitlines()[1:] if f.split()[5] != "<none>" and (not TERM_SCHEDULED or f.split()[0] != os.environ.get("HOSTNAME"))))

def existing_dns():
    try:
        return [r['Value'] for r in next((r['ResourceRecords'] for r in route53.list_resource_record_sets(HostedZoneId=ZONE_ID)['ResourceRecordSets'] if r['Name'].strip('.') == DNS and r['Type'] == 'A'), [])]
    except:
        return []

def update_dns():
    new_ips, old_ips = get_ips(), existing_dns()
    if new_ips == old_ips: return
    cb = {"Comment": "Update DNS", "Changes": [{"Action": a, "ResourceRecordSet": {"Name": DNS, "Type": "A", "TTL": 300, "ResourceRecords": [{"Value": ip} for ip in ips]}} for a, ips in (("DELETE", old_ips), ("CREATE", new_ips)) if ips]}
    route53.change_resource_record_sets(HostedZoneId=ZONE_ID, ChangeBatch=cb)

update_dns()