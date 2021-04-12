#!/bin/bash
# Script for running healthcheck on openshift

die() { echo "$*" 1>&2 ; exit 1; }


setup() {
	COLOR_GREEN='\033[0;32m'
	COLOR_RED='\033[0;31m'
	COLOR_NC='\033[0m' # No Color

	minimum_thread_count=8192
	#Minimum space in GB
	minimum_space=90
	portworx_expected_status="Status: PX is operational"
	maxmapcount_expected=262144
	enforce_expected="Enforcing"
	max_sync_time=10000
	max_write_iops=500
}

checkFio() {

	sync_time=$(ssh $SSH_ARGS root@${i} fio --rw=write --ioengine=sync --fdatasync=1 --directory=$PWD --size=22m --bs=2300 --name=mytest | awk '$2 =="99.00th=["' | tail -1 | awk -F '[][]' '{print $2}' )
	write_iops=$(ssh $SSH_ARGS root@${i} fio --rw=write --ioengine=sync --fdatasync=1 --directory=$PWD --size=22m --bs=2300 --name=mytest | awk '$1 =="write:"' | awk '{print $2}' | awk -F '[=,]' '{print $2}')
	if [ $sync_time -gt $max_sync_time ]; then
		# Need to install fio
		echo -e ${COLOR_RED}FAILED:${COLOR_NC} node $i has a disc sync 99 percentile time of $sync_time which is greater than $max_sync_time.
	else
		echo -e ${COLOR_GREEN}OK:${COLOR_NC} node $i has a disc sync 99 percentile time of $sync_time which is less than $max_sync_time.
	fi

	if [ $write_iops -gt $max_write_iops ]; then
		# Need to install fio
		echo -e ${COLOR_RED}FAILED:${COLOR_NC} node $i has a write iops time of $write_iops which is greater than $max_write_iops.
	else
		echo -e ${COLOR_GREEN}OK:${COLOR_NC} node $i has a write iops time of $write_iops which is less than $max_write_iops.
	fi
}

health_check() {
	oc get nodes --no-headers >/dev/null 2>&1
	if [ $? -eq 0 ]; then
		all_nodes=$(oc get nodes --no-headers | awk '{print $1}')
		worker_nodes=$(oc get nodes --no-headers | awk '$3 =="compute"' | awk '{print $1}')
	else
		echo -e ${COLOR_RED}FAILED:${COLOR_NC} Error getting node details. Ensure oc login is run before attempting this script.
		exit 1
	fi

	echo
	echo Checking if CPUs have AVX2 support
	echo --------------------------
	for i in $(echo $all_nodes); do
		avx2count=$(ssh $SSH_ARGS root@${i} cat /proc/cpuinfo | grep avx2 | wc -l)
		if [ $avx2count -eq 0 ]; then
			echo -e ${COLOR_RED}FAILED:${COLOR_NC} node $i does not support avx2
		else
			echo -e ${COLOR_GREEN}OK:${COLOR_NC} node $i supports avx2
		fi
	done

	echo
	echo Checking if OpenShift version 3.11
	echo --------------------------

	for i in $(echo $all_nodes); do
		versionString=$(ssh root@${i} oc version | grep oc | awk '{print $2}')
		if [[ $versionString == v3.11* ]]; then
			echo -e ${COLOR_GREEN}OK:${COLOR_NC} node $i has Openshift version 3.11
		else
			echo -e ${COLOR_RED}FAILED:${COLOR_NC} node $i has Openshift version $versionString instead of 3.11.xx
		fi
	done

	echo
	echo Checking if Clusters are using CRI-O Container
	echo --------------------------
	for i in $(echo $all_nodes); do
		oc get nodes $i -o wide --no-headers | awk '{print $11}' | grep -v ^cri-o | wc -l >/dev/null 2>&1
		if [ $? -eq 0 ]; then
			echo -e ${COLOR_GREEN}OK:${COLOR_NC} Cluster $i is using CRI-O Container
		else
			echo -e ${COLOR_RED}FAILED:${COLOR_NC} Cluster $i is not using CRI-O Container
		fi
	done

	echo
	echo Checking if default thread count to set to $minimum_thread_count or higher
	echo --------------------------
	for i in $(echo $all_nodes); do
		avx2count=$(ssh $SSH_ARGS root@${i} cat /etc/crio/crio.conf | grep pids_limit | grep -v ^# | awk '{print $3}')
		if [ $avx2count -ge $minimum_thread_count ]; then
			echo -e ${COLOR_GREEN}OK:${COLOR_NC} node $i default thread count is set to $avx2count pids
		else
			echo -e ${COLOR_RED}FAILED:${COLOR_NC} node $i default thread count $avx2count is less than $minimum_thread_count
		fi
	done

	echo
	echo Checking if ample space available in /root, /tmp and /var
	echo --------------------------

	for mount in /root /tmp /var; do
		space=$(df -h --out=avail --block-size=1G $mount | tail -1)
		if [ $space -ge $minimum_space ]; then
			echo -e ${COLOR_GREEN}OK:${COLOR_NC} mount $mount has $space GB available
		else
			echo -e ${COLOR_RED}FAILED:${COLOR_NC} mount $mount has insufficient space available \(Available: $space GB, Minimum Required: $minimum_space GB\)
		fi
	done

	echo
	echo Checking if portworx is operational
	echo --------------------------

	PX_POD=$(kubectl get pods -l name=portworx -n kube-system -o jsonpath='{.items[0].metadata.name}')
	portworx_status=$(kubectl exec $PX_POD -n kube-system -- /opt/pwx/bin/pxctl status | grep ^Status)

	if [[ $portworx_status = $portworx_expected_status ]]; then
		echo -e ${COLOR_GREEN}OK:${COLOR_NC} portworx is operational
	else
		echo -e ${COLOR_RED}FAILED:${COLOR_NC} portworx is not operational. $portworx_status
	fi

	echo
	echo Checking if Portworx is running on all worker nodes
	echo --------------------------
	for i in $(echo $worker_nodes); do
		oc get pods --all-namespaces -o wide | grep portworx-api | grep $i >/dev/null 2>&1
		if [ $? -eq 0 ]; then
			echo -e ${COLOR_GREEN}OK:${COLOR_NC} portworx is running in node $i
		else
			echo -e ${COLOR_RED}FAILED:${COLOR_NC} portworx is not running in node $i
		fi
	done

	echo
	echo Checking if Portworx StorageClasses are available
	echo --------------------------

	for storageclass in portworx-shared-gp portworx-nonshared-gp; do
		classcount=$(oc get storageclasses | awk -v class=${storageclass} '$1 == class' | wc -l)
		if [ $classcount -eq 1 ]; then
			echo -e ${COLOR_GREEN}OK:${COLOR_NC} class $storageclass available
		else
			echo -e ${COLOR_RED}FAILED:${COLOR_NC} class $storageclass is not available
		fi
	done

	echo
	echo "Checking if vm.max_map_count set to $maxmapcount_expected (for Discovery only)"
	echo --------------------------
	for i in $(echo $all_nodes); do
		maxmapcount=$(ssh $SSH_ARGS root@${i} sysctl -a 2<&1 | awk '$1 == "vm.max_map_count"' | awk '{print $3}')
		if [ $maxmapcount -eq $maxmapcount_expected ]; then
			echo -e ${COLOR_GREEN}OK:${COLOR_NC} node $i has vm.max_map_count set to $maxmapcount
		else
			echo -e ${COLOR_RED}FAILED:${COLOR_NC} node $i has vm.max_map_count set to $maxmapcount. Expected: $maxmapcount_expected
		fi
	done

	echo
	echo "Checking if selinux is set to 'enforcing' (for Discovery only)"
	echo --------------------------

	for i in $(echo $all_nodes); do
		enforce=$(ssh $SSH_ARGS root@${i} getenforce)
		if [ $enforce = $enforce_expected ]; then
			echo -e ${COLOR_GREEN}OK:${COLOR_NC} node $i has selinux set to $enforce
		else
			echo -e ${COLOR_RED}FAILED:${COLOR_NC} node $i has selinux set to $enforce. Expected: $enforce_expected
		fi
	done

	echo
	echo "Testing disk performance (for Discovery only)"
	echo --------------------------

	for i in $(echo $worker_nodes); do
		fio_installed=$(ssh $SSH_ARGS root@${i} yum list installed 2>/dev/null | grep fio | wc -l)
		if [ $fio_installed -eq 0 ]; then
			# Need to install fio
			echo "fio is not installed in node $i. Installing fio....."
			ssh $SSH_ARGS root@${i} yum -y install fio >/dev/null 2>&1
			if [ $? -eq 0 ]; then
				echo "Installation of fio completed on node $i. Checking disk parameters using fio "
				checkFio $i
			else
				echo -e "${COLOR_RED}FAILED:${COLOR_NC} Installation of fio failed on node $i "
			fi
		else
			echo "fio is installed on node $i. Checking disk parameters using fio "
			checkFio $i
		fi
	done
}

function showHelp() {
	echo "Usage: oc-healthcheck.sh [--ssh-args SSH_ARGS] [--help]"
	echo ""
	echo '--SSH_ARGS: Any additional arguments to be passed when making ssh to other nodes (For example "-i name.pem")'
	echo "--help: Displays this help message."
}

while (($# > 0)); do
	case "$1" in
	-s | --s | --ssh-args)
		if [[ $2 == "" ]]; then
			die "ERROR: ssh argument has no value"
		fi
		shift
		SSH_ARGS="$1"
		;;
	-h | --h | --help)
		showHelp
		exit 2
		;;
	* | -*)
		echo "Unknown option: $1"
		exit 99
		;;
	esac
	shift
done

setup
health_check
