
### Checking Prerequisites

https://github.com/IBM-ICP4D/Install_Precheck_CPD_v3

Use the Install_Precheck_CPD_v3 utility a set of pre-installation checks designed to validate that your system is compatible with RedHat Openshift 4.3.13+ and Cloud Pak 4 Data 3.0.1 installations.

### Manual Checks

CPUs with AVX2 support
`cat /proc/cpuinfo | grep avx2`

OpenShift Version
`oc version`

CRI-O Container Runtime (required for Portworx)
`oc get nodes -o wide`

Default thread count to permit containers with 8192 pids
To check:
`for node in $(oc get node -o=jsonpath={.items[*].metadata.name}); do echo -n "${node} " ; ssh root@${node} cat /etc/crio/crio.conf | grep pids_limit ; done`

To set (OpenShift 3): 
`add pids_limit = 4096 under the [crio.runtime] section in  /etc/crio/crio.conf`


Check disk space 
`df -h`


To Check Portworx Status:
`PX_POD=$(kubectl get pods -l name=portworx -n kube-system -o jsonpath='{.items[0].metadata.name}')
kubectl exec $PX_POD -n kube-system -- /opt/pwx/bin/pxctl status`

To to verify Portworx running on all nodes: 
`oc get pods --all-namespaces -o wide | grep portworx-api`


vm.max_map_count set to  262144 for Elastic (WDS)
To Check:  `for node in $(oc get node -o=jsonpath={.items[*].metadata.name}); do echo -n "${node} " ; ssh root@${node} sysctl -a | grep vm.max_map_count ; done`

To Set: `for node in $(oc get node -o=jsonpath={.items[*].metadata.name}); do ssh root@${node} "echo vm.max_map_count=262144 >> /etc/sysctl.conf"; done`

Selinux set to Enforcing for Elastic to start (WDS)
To Check: `for node in $(oc get node -o=jsonpath={.items[*].metadata.name}); do echo -n "${node} " ; ssh root@${node} getenforce; done`

To Set: `for node in $(oc get node -o=jsonpath={.items[*].metadata.name}); do echo -n "${node} " ; ssh root@${node} setenforce enforcing; done`


To Restart Nodes if changes were made (Fyre)
`cat /etc/hosts |grep fyre|  awk -F" " '{print $2}' >> nodeList
ansible all -i nodeList -m shell -a "reboot"`

