#!/bin/bash

# Kube-bench Visual Reporter
# Generates a formatted table output from kube-bench results

echo "========================================"
echo "  Kube-bench Visual Summary Generator"
echo "========================================"
echo ""

# Run kube-bench and capture output
kubectl delete job kube-bench 2>/dev/null || true
kubectl apply -f - <<EOF
apiVersion: batch/v1
kind: Job
metadata:
  name: kube-bench
spec:
  template:
    spec:
      hostPID: true
      containers:
      - name: kube-bench
        image: aquasec/kube-bench:v0.8.0
        command: ["kube-bench", "--json"]
        volumeMounts:
        - name: var-lib-etcd
          mountPath: /var/lib/etcd
          readOnly: true
        - name: var-lib-kubelet
          mountPath: /var/lib/kubelet
          readOnly: true
        - name: var-lib-kube-scheduler
          mountPath: /var/lib/kube-scheduler
          readOnly: true
        - name: var-lib-kube-controller-manager
          mountPath: /var/lib/kube-controller-manager
          readOnly: true
        - name: etc-systemd
          mountPath: /etc/systemd
          readOnly: true
        - name: lib-systemd
          mountPath: /lib/systemd/
          readOnly: true
        - name: srv-kubernetes
          mountPath: /srv/kubernetes/
          readOnly: true
        - name: etc-kubernetes
          mountPath: /etc/kubernetes
          readOnly: true
        - name: usr-bin
          mountPath: /usr/local/mount-from-host/bin
          readOnly: true
        - name: etc-cni-netd
          mountPath: /etc/cni/net.d/
          readOnly: true
        - name: opt-cni-bin
          mountPath: /opt/cni/bin/
          readOnly: true
        - name: etc-passwd
          mountPath: /etc/passwd
          readOnly: true
        - name: etc-group
          mountPath: /etc/group
          readOnly: true
      restartPolicy: Never
      volumes:
      - name: var-lib-etcd
        hostPath:
          path: "/var/lib/etcd"
      - name: var-lib-kubelet
        hostPath:
          path: "/var/lib/kubelet"
      - name: var-lib-kube-scheduler
        hostPath:
          path: "/var/lib/kube-scheduler"
      - name: var-lib-kube-controller-manager
        hostPath:
          path: "/var/lib/kube-controller-manager"
      - name: etc-systemd
        hostPath:
          path: "/etc/systemd"
      - name: lib-systemd
        hostPath:
          path: "/lib/systemd"
      - name: srv-kubernetes
        hostPath:
          path: "/srv/kubernetes"
      - name: etc-kubernetes
        hostPath:
          path: "/etc/kubernetes"
      - name: usr-bin
        hostPath:
          path: "/usr/bin"
      - name: etc-cni-netd
        hostPath:
          path: "/etc/cni/net.d/"
      - name: opt-cni-bin
        hostPath:
          path: "/opt/cni/bin/"
      - name: etc-passwd
        hostPath:
          path: "/etc/passwd"
      - name: etc-group
        hostPath:
          path: "/etc/group"
EOF

echo "Waiting for kube-bench job to complete..."
kubectl wait --for=condition=complete --timeout=60s job/kube-bench

# Get pod name
POD_NAME=$(kubectl get pods --selector=job-name=kube-bench -o jsonpath='{.items[0].metadata.name}')

echo ""
echo "Generating visual report..."
echo ""

# Get logs and format
kubectl logs $POD_NAME | python3 -c "
import json
import sys
from datetime import datetime

def print_separator(char='=', length=120):
    print(char * length)

def print_table_header(columns, widths):
    header = '| '
    for col, width in zip(columns, widths):
        header += col.ljust(width) + ' | '
    print(header)
    print_separator('-', 120)

def print_table_row(values, widths):
    row = '| '
    for val, width in zip(values, widths):
        row += str(val).ljust(width) + ' | '
    print(row)

# Read JSON from stdin
try:
    data = json.loads(sys.stdin.read())
except:
    print('Error: Could not parse JSON output')
    sys.exit(1)

# Print header
print_separator()
print('KUBE-BENCH CIS KUBERNETES BENCHMARK REPORT'.center(120))
print_separator()
print(f'Generated: {datetime.now().strftime(\"%Y-%m-%d %H:%M:%S\")}'.center(120))
print_separator()
print()

totals = {'PASS': 0, 'FAIL': 0, 'WARN': 0, 'INFO': 0}

# Process each control
for control in data.get('Controls', []):
    section_id = control.get('id', '')
    section_text = control.get('text', '')
    
    print()
    print(f'[{section_id}] {section_text}')
    print_separator('-', 120)
    
    # Print results table
    widths = [8, 10, 85]
    print_table_header(['Status', 'Test ID', 'Description'], widths)
    
    for test in control.get('tests', []):
        for result in test.get('results', []):
            status = result.get('status', '')
            test_num = result.get('test_number', '')
            desc = result.get('test_desc', '')[:82] + '...' if len(result.get('test_desc', '')) > 85 else result.get('test_desc', '')
            
            # Add emoji for status
            status_icon = {
                'PASS': '✅',
                'FAIL': '❌',
                'WARN': '⚠️ ',
                'INFO': 'ℹ️ '
            }.get(status, '  ')
            
            print_table_row([f'{status_icon} {status}', test_num, desc], widths)
            totals[status] = totals.get(status, 0) + 1
    
    # Section summary
    print_separator('-', 120)
    print(f'Section Summary: PASS={control.get(\"total_pass\", 0)} | FAIL={control.get(\"total_fail\", 0)} | WARN={control.get(\"total_warn\", 0)} | INFO={control.get(\"total_info\", 0)}')
    print()

# Overall summary
print()
print_separator()
print('OVERALL SUMMARY'.center(120))
print_separator()
print()

total_checks = sum(totals.values())
compliance = round((totals['PASS'] / (totals['PASS'] + totals['FAIL']) * 100), 1) if (totals['PASS'] + totals['FAIL']) > 0 else 0

summary_data = [
    ['✅ Passed', totals['PASS']],
    ['❌ Failed', totals['FAIL']],
    ['⚠️  Warnings', totals['WARN']],
    ['ℹ️  Info', totals['INFO']],
    ['━━━━━━━━━', '━━━━━'],
    ['Total Checks', total_checks],
    ['Compliance Score', f'{compliance}%']
]

widths = [30, 15]
for row in summary_data:
    if '━' in row[0]:
        print_separator('━', 50)
    else:
        print(f'{row[0].ljust(widths[0])} : {str(row[1]).rjust(widths[1])}')

print()
print_separator()

# Compliance rating
if compliance >= 90:
    rating = '🌟 EXCELLENT - High Security Posture'
elif compliance >= 70:
    rating = '👍 GOOD - Acceptable Security Level'
elif compliance >= 50:
    rating = '⚠️  FAIR - Needs Improvement'
else:
    rating = '❌ POOR - Immediate Action Required'

print(f'Security Rating: {rating}'.center(120))
print_separator()
print()
"

echo ""
echo "Report generation complete!"
echo ""
