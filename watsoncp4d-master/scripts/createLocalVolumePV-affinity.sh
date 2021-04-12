#!/bin/bash
#
#################################################################
# Licensed Materials - Property of IBM
# (C) Copyright IBM Corp. 2019.  All Rights Reserved.
#
# US Government Users Restricted Rights - Use, duplication or
# disclosure restricted by GSA ADP Schedule Contract with
# IBM Corp.
#################################################################
#
# This script can be used to create local-volume PV's for POC
# environments in ICP4D.
#
# It is provided as is and should not be used on Production
# ICP4D environments.
#
# It should be run from a machine that has ssh access to all the
# nodes in your ICP4D development environment.
#
# Usage: createLocalVolumePV-affinity.sh [--path PATH] [--help]
#
# You can optionally provide the path used on each node to store 
# the PV data.
#
#################################################################

#################################################################
# You may wish to customise the script by changing these
# variables from their defaults
#################################################################
# You can change the user to ssh into each node here, default is root.
SSH_USER="root"
# You can specify ssh args you want to use here, for example if you need to provide an ssh certificate
SSH_ARGS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"

# Create a Unique Identifier for the PV's
ID=$(date +%Y-%m-%d--%H-%M)
# The location on each node to store the actual PV data
LOCAL_PATH="/mnt/local-storage/storage/watson/assistant"

# Directory to store temporary files
tmpDir=/tmp/createLocalVolumePV-affinity.$$
mkdir -vp $tmpDir
# Temporary file, deleted at the end of the script
tmpNodeTop4=$tmpDir/nodes_top4.out
tmpNodeTop3=$tmpDir/nodes_top3.out
#################################################################
# End of variables
#################################################################

function die() {
  echo "$@" 1>&2

  exit 99
}

function showHelp() {
  echo "Usage createLocalVolumePV-affinity.sh [--path PATH] [--help]"
  echo ""
  echo "--path: You can optionally provide the path used on each node to store the PV data."
  echo "--help: Displays this help message."
}

while (( $# > 0 )); do
  case "$1" in
    -p | --p | --path )
      if [[ $2 == -* ]] || [[ $2 == "" ]]; then
        die "ERROR: Path argument has no value"
      fi
      shift
      LOCAL_PATH="$1"
      ;;
    -h | --h | --help )
      showHelp
      exit 2
      ;;
    * | -* )
      echo "Unknown option: $1"
      exit 99
      ;;
  esac
  shift
done

# if we can't connect to k8s and retrieve the nodes, exit with error
echo "Testing kubernetes connection..."
kubectl get nodes >/dev/null
if [ $? -ne 0 ]
then
  die "ERROR: Can't connect to kubernetes and retrieve node list"  
fi

#################################################################
# Start of main script
#
# Get a list of worker nodes
# ssh into each node and create a dir for each PV
# Generate templates for each size of PV
# Render the templates
# Apply the templates
# Clean the tmp dir
#################################################################

#######################
# Build a list of nodes
#######################
kubectl get nodes -l node-role.kubernetes.io/worker=true --no-headers | cut -f1 -d " " | head -4 > $tmpNodeTop4
head -3 $tmpNodeTop4 > $tmpNodeTop3
export tmpNode4=`tail -1 $tmpNodeTop4`

#######################
# Find node name for 4th node to create node for minio
#######################

###########################################
# We will do following allocation for each node:
# Database\Node | worker 1 | worker 2 | worker 3 | worker 4
# MongoDB| wa-icp-mongodb-80gi-1 | wa-icp-mongodb-80gi-2 | wa-icp-mongodb-80gi-3| - 
# Etcd | wa-icp-etcd-10gi-1 | wa-icp-etcd-10gi-2 | wa-icp-etcd-10gi-3 | -
# PostgresSQL | wa-icp-postgres-10gi-1 | wa-icp-postgres-10gi-2 | wa-icp-postgres-10gi-3 | -
# Minio/COS | wa-icp-minio-5gi-1 | wa-icp-minio-5gi-2 | wa-icp-minio-5gi-3 | wa-icp-minio-5gi-4
###########################################
while read -u10 node; do
  echo "Processing node $node"
  ssh $SSH_ARGS $SSH_USER@$node /bin/bash << EOF
 mkdir -vp "$LOCAL_PATH"/pv_5gb-wa-minio"-${node}"
 mkdir -vp "$LOCAL_PATH"/pv_10gb-wa-etcd"-${node}"
 mkdir -vp "$LOCAL_PATH"/pv_10gb-wa-postgres"-${node}"
 mkdir -vp "$LOCAL_PATH"/pv_80gb-wa-mongodb"-${node}"
EOF
done 10< $tmpNodeTop3

ssh $SSH_ARGS $SSH_USER@$tmpNode4 /bin/bash << EOF
mkdir -vp "$LOCAL_PATH"/pv_5gb-wa-minio"-${tmpNode4}"
EOF

##########################
# Create PV yaml templates
##########################
echo "Creating templates using PATH=$LOCAL_PATH"

for size in 5 10 80; do
  cat << EOF > $tmpDir/pv_${size}_template.tpl
apiVersion: v1
kind: PersistentVolume
metadata:
  finalizers:
  - kubernetes.io/pv-protection
  name: pv-${size}gb-wa-__COMPONENT__-__NODE__
  labels:
     dedication: wa-__COMPONENT__
spec:
  capacity:
    storage: ${size}Gi
  accessModes:
  - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: local-storage
  local:
    path: $LOCAL_PATH/pv_${size}gb-wa-__COMPONENT__-__NODE__
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: In
          values:
          - __NODE__
EOF
done

#########################
# Create:
#   4 5GB PV's
#   6 10GB PV's
#   3 80GB PV's
#########################
echo "Rendering templates"
mkdir -vp $tmpDir/rendered

while read -u10 node; do
  cat $tmpDir/pv_5_template.tpl | sed "s#__COMPONENT__#minio#g" | sed "s#__NODE__#${node}#g" > $tmpDir/rendered/pv_5gb_minio_${node}.yaml
  cat $tmpDir/pv_10_template.tpl | sed "s#__COMPONENT__#etcd#g" | sed "s#__NODE__#${node}#g" > $tmpDir/rendered/pv_5gb_etcd_${node}.yaml
  cat $tmpDir/pv_10_template.tpl | sed "s#__COMPONENT__#postgres#g" | sed "s#__NODE__#${node}#g" > $tmpDir/rendered/pv_5gb_postgres_${node}.yaml
  cat $tmpDir/pv_80_template.tpl | sed "s#__COMPONENT__#mongodb#g" | sed "s#__NODE__#${node}#g" > $tmpDir/rendered/pv_5gb_mongodb_${node}.yaml
done 10< $tmpNodeTop3

cat $tmpDir/pv_5_template.tpl | sed "s#__COMPONENT__#minio#g" | sed "s#__NODE__#${tmpNode4}#g" > $tmpDir/rendered/pv_5gb_minio_${tmpNode4}.yaml
echo "Applying templates"

kubectl apply -f $tmpDir/rendered

rm -fr $tmpDir
