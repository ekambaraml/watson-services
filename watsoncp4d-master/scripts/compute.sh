#!/bin/bash
#/
# Copyright 2018 IBM Corp. All Rights Reserved
# IBM Confidential Source Code Materials
#
# IBM grants recipient of the source code (“you”) a non-exclusive, non-transferable, revocable (in the case of breach of this license or termination of your subscription to
# the applicable IBM Cloud services or their replacement services) license to reproduce, create and transmit, in each case, internally only, derivative works of the source
# code for the sole purpose of maintaining and expanding the usage of applicable IBM Cloud services. You must reproduce the notices and this license grant in any derivative
# work of the source code. Any external distribution of the derivative works will be in object code or executable form only.
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an “AS IS” BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#/
#
# Script to reports cpu and memory request and limit summaries
# Created by Charles de Saint-Aignan
# must be logged into cluster via cloudctl; defaults to conversation namespace
# can specify alternate namespace as argument:
# example ./compute.sh speech


#!/usr/bin/env bash

#CLUSTER=`cloudctl api | grep -o '//.*:' | rev | cut -c 2- | rev | cut -c 3-`
NAMESPACE=${1:-conversation}
FILE=${2:-"/tmp/describe-$NAMESPACE.txt"}
echo ""
echo "Producing CPU and Memory request and limit summary for:"
#echo "Cluster:   $CLUSTER"
echo "Namespace: $NAMESPACE"
echo "File: $FILE"
echo ""

kubectl describe nodes | grep $NAMESPACE > $FILE

### CPU REQUEST
# echo "# CPU REQUEST #"
CPU1=`cat $FILE | tr -s ' ' | tr ' ' ',' | awk -F, '{print $4}' | grep .*m | grep -oE '[0-9]+' | awk '{s+=$1} END {print s}'`
CPU2=`cat $FILE | tr -s ' ' | tr ' ' ',' | awk -F, '{print $4}' | grep -v .*m | awk '{s+=$1} END {print s*1000}'`
# echo "${CPU1}m + ${CPU2}m"
CPU=$((CPU1 + CPU2))
echo "CPU REQ: ${CPU}m" 

### CPU LIMIT
# echo "# CPU LIMIT #"
CPU1=`cat $FILE | tr -s ' ' | tr ' ' ',' | awk -F, '{print $6}' | grep .*m | grep -oE '[0-9]+' | awk '{s+=$1} END {print s}'`
CPU2=`cat $FILE | tr -s ' ' | tr ' ' ',' | awk -F, '{print $6}' | grep -v .*m | awk '{s+=$1} END {print s*1000}'`
# echo "${CPU1}m + ${CPU2}m"
CPU=$((CPU1 + CPU2))
echo "CPU LIM: ${CPU}m"

### MEMORY REQUEST
# echo "# MEMORY REQUEST #"
MEM1=`cat $FILE | tr -s ' ' | tr ' ' ',' | awk -F, '{print $8}' | grep .*Mi | grep -oE '[0-9]+' | awk '{s+=$1} END {print s}'`
MEM2=`cat $FILE | tr -s ' ' | tr ' ' ',' | awk -F, '{print $8}' | grep .*Gi | grep -oE '[0-9]+' | awk '{s+=$1} END {print s*1024}'`
MEM3=`cat $FILE | tr -s ' ' | tr ' ' ',' | awk -F, '{print $8}' | grep '.*M$' | grep -oE '[0-9]+' | awk '{s+=$1} END {print s/1.048576}'`
# echo "${MEM1}Mi + ${MEM2}Mi + ${MEM3}Mi"
MEM=$(echo "$MEM1 + $MEM2 + $MEM3" | bc)
echo "MEM REQ: ${MEM}Mi"

### MEMORY LIMIT
# echo "# MEMORY LIMIT #"
MEM1=`cat $FILE | tr -s ' ' | tr ' ' ',' | awk -F, '{print $10}' | grep .*Mi | grep -oE '[0-9]+' | awk '{s+=$1} END {print s}'`
MEM2=`cat $FILE | tr -s ' ' | tr ' ' ',' | awk -F, '{print $10}' | grep .*Gi | grep -oE '[0-9]+' | awk '{s+=$1} END {print s*1024}'`
MEM3=`cat $FILE | tr -s ' ' | tr ' ' ',' | awk -F, '{print $10}' | grep '.*M$' | grep -oE '[0-9]+' | awk '{s+=$1} END {print s/1.048576}'`
#echo "${MEM1}Mi + ${MEM2}Mi + ${MEM3}Mi"
MEM=$(echo "$MEM1 + $MEM2 + $MEM3" | bc)
echo "MEM LIM: ${MEM}Mi"
echo ""

DATE=`date`
echo "Report produced for cluster $CLUSTER on $DATE"
echo "Visit https://www.gordonengland.co.uk/conversion/binary.htm to convert to other units as necessary"
echo ""
