#!/usr/bin/python3
import boto3, os, subprocess, json, time
from datetime import datetime, timezone

# === CONFIG ===
CLUSTER = os.environ.get('CLUSTER').replace('_', '-')
DNS_RR = f"rr.{CLUSTER}.{{cluster_dns_zone}}"
DNS_API = f"api.{CLUSTER}.{{cluster_dns_zone}}"
ZONE_ID = os.environ.get("ZONE_ID", "{{dns_zone_result.zone_id}}")
ASG_NAME = "k0s-{{ inventory_hostname }}"
REGION = "{{ region }}"
HOSTNAME = os.environ.get("HOSTNAME")
TERM_SCHEDULED = os.path.exists("/tmp/terminate-scheduled")
REBOOT_FLAG = "/var/tmp/last-reboot-attempt"

# === AWS CLIENTS ===
route53 = boto3.client('route53', region_name=REGION)
ec2 = boto3.client('ec2', region_name=REGION)
asg = boto3.client('autoscaling', region_name=REGION)


# === UTIL ===
def notify(msg):
    global HOSTNAME
    print(msg)
    os.system(f'curl -s -d "{HOSTNAME} {msg}" ntfy.sh/Pq0X8xQ0XYVsNTb8 > /dev/null')


# === 1. ASG Nodes ===
def get_asg_nodes():
    instance_ids = []
    response = asg.describe_auto_scaling_groups(AutoScalingGroupNames=[ASG_NAME])
    groups = response.get("AutoScalingGroups", [])
    if not groups:
        return set(), set()

    for instance in groups[0]["Instances"]:
        if instance["LifecycleState"] == "InService":
            instance_ids.append(instance["InstanceId"])

    reservations = ec2.describe_instances(InstanceIds=instance_ids)["Reservations"]
    ips, names = set(), set()
    for res in reservations:
        for inst in res["Instances"]:
            ip = inst.get("PrivateIpAddress")
            dns = inst.get("PrivateDnsName", "").split('.')[0]
            if ip and (not TERM_SCHEDULED or dns != HOSTNAME):
                ips.add(ip)
            if dns:
                names.add(dns)

    return ips, names


# === 2. k0s / Kubernetes Nodes ===
def get_k8s_nodes():
    try:
        output = subprocess.check_output("k0s kubectl get nodes -o json", shell=True).decode()
        items = json.loads(output)["items"]
    except Exception as e:
        notify(f"kubectl error: {e}")
        unregister_and_terminate("k0s API unreachable")
        return []

    nodes = []
    for item in items:
        name = item["metadata"]["name"]
        ip = next((addr["address"] for addr in item["status"]["addresses"] if addr["type"] == "InternalIP"), None)
        conditions = {c['type']: c for c in item["status"]["conditions"]}
        ready = conditions.get("Ready", {}).get("status") == "True"
        transition = conditions.get("Ready", {}).get("lastTransitionTime")
        last_transition = None
        if transition:
            try:
                last_transition = datetime.fromisoformat(transition)
            except:
                pass
        nodes.append({
            "name": name,
            "ip": ip,
            "ready": ready,
            "last_transition": last_transition,
        })
    return nodes

def unregister_and_terminate(reason=""):
    try:
        notify(f"Unregistering from ASG and terminating: {reason}")
        asg.set_instance_health(InstanceId=os.environ.get('INSTANCE_ID'), HealthStatus='Unhealthy', ShouldRespectGracePeriod=False)
        subprocess.call("shutdown -h now", shell=True)
    except Exception as e:
        notify(f"Failed to self-terminate: {e}")

# === 3. DNS Update ===
def update_dns(api_ips, rr_ips):
    def record_change(name, ips):
        return {
            "Comment": "Update DNS",
            "Changes": [
                {
                    "Action": a,
                    "ResourceRecordSet": {
                        "Name": name,
                        "Type": "A",
                        "TTL": 300,
                        "ResourceRecords": [{"Value": ip} for ip in ips]
                    }
                }
                for a, ips in (("DELETE", get_current_dns(name)), ("CREATE", ips)) if ips
            ]
        }

    def get_current_dns(record_name):
        try:
            return sorted([
                r['Value'] for r in next((
                    r['ResourceRecords']
                    for r in route53.list_resource_record_sets(HostedZoneId=ZONE_ID)['ResourceRecordSets']
                    if r['Name'].strip('.') == record_name and r['Type'] == 'A'
                ), [])
            ])
        except:
            return []

    if api_ips:
        route53.change_resource_record_sets(HostedZoneId=ZONE_ID, ChangeBatch=record_change(DNS_API, sorted(api_ips)))
    if rr_ips:
        route53.change_resource_record_sets(HostedZoneId=ZONE_ID, ChangeBatch=record_change(DNS_RR, sorted(rr_ips)))


# === 4. Cluster Maintenance ===
def maintain_cluster(k8s_nodes, asg_node_names):
    ready_nodes = sum(1 for n in k8s_nodes if n["ready"])

    for node in k8s_nodes:
        name = node["name"]
        if node["ready"]:
            continue

        age = 0
        if node["last_transition"]:
            age = (datetime.now(timezone.utc) - node["last_transition"]).total_seconds()

        if name == HOSTNAME and age > 300:
            if not os.path.exists(REBOOT_FLAG) or (time.time() - os.path.getmtime(REBOOT_FLAG)) > 1800:
                notify("Rebooting due to NotReady state >5m")
                open(REBOOT_FLAG, "w").close()
                subprocess.call("reboot", shell=True)

        if name not in asg_node_names and age > 900:
            notify(f"Removing node not in ASG: {name}")
            subprocess.call(f"k0s kubectl delete node {name}", shell=True)

    if ready_nodes < 2:
        if not os.path.exists("/tmp/cluster-degraded"):
            notify(f"⚠️ cluster degraded: {ready_nodes} ready nodes")
            open("/tmp/cluster-degraded", "w").close()
    else:
        if os.path.exists("/tmp/cluster-degraded"):
            notify(f"🚀 cluster recovered: {ready_nodes} ready nodes")
            os.remove("/tmp/cluster-degraded")


# === MAIN ===
def main():
    asg_ips, asg_node_names = get_asg_nodes()
    k8s_nodes = get_k8s_nodes()
    rr_ips = [n["ip"] for n in k8s_nodes if n["ready"] and n["name"] in asg_node_names and n["ip"]]
    update_dns(asg_ips, rr_ips)
    maintain_cluster(k8s_nodes, asg_node_names)

main()
