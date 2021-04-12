### Reference 

Portworx release:  http://icpfs1.svl.ibm.com/zen/cp4d-builds/3.0.1/production/portworx/
Instructions:  
https://www.ibm.com/support/knowledgecenter/SSQNUZ_3.5.0/cpd/install/portworx-install.html
https://github.ibm.com/PrivateCloud-analytics/CEA-Zen/wiki/How-to-install-Portworx-2.5.5-on-RedHat-OpenShift-4.5-System
Support:  #cp4d-storage. https://ibm-analytics.slack.com/archives/CTC7D7RPZ

### START HERE

This cheatsheet assumes 
* You are installing Portworx 2.5.5 on OpenShift 4.5 on Fyre.  
* All workers have 2 disk partitions that will be used for Portworx storage 
* Standard install using internal registry with recommended install using separate devices for application and metadata storage

Login to Openshift from Infra node
```
oc login -u kubeadmin -p `cat ~/auth/kubeadmin-password` 
```
### Portworx Prep - FYRE ONLY

1.  Delete rook project
```
oc delete project rook-ceph 
oc -n rook-ceph patch cephclusters.ceph.rook.io rook-ceph -p '{"metadata":{"finalizers": []}}' --type=merge
```
2.  Check disks on worker nodes - you need clean vdb and vdc partitions

```
for worker in $(oc get node -o name -l node-role.kubernetes.io/worker | sed 's/node\///')
do 
echo $worker
ssh core@$worker sudo lsblk -l
done
```
Clean ceph (only if it exists from the /dev/vdc device)
```
for worker in $(oc get node -o name -l node-role.kubernetes.io/worker | sed 's/node\///')
do 
echo $worker
ssh core@$worker sudo lsblk -l
ssh core@$worker sudo dd if=/dev/zero of=/dev/vdb bs=1M count=2
ssh core@$worker sudo dd if=/dev/zero of=/dev/vdc bs=1M count=2
ssh core@$worker sudo reboot
done
```
3.  Install podman on infrastructure node 
```
yum install podman
```

### Portworx Install

1.  Create Internal Image Registry Route. From the Infra Node, run the following commands and make sure you can login
```
oc project openshift-image-registry
oc patch configs.imageregistry.operator.openshift.io/cluster --type merge -p '{"spec":{"defaultRoute":true}}'
oc registry info
export PRIVATE_REGISTRY=$(oc registry info)
export PODMAN_LOGIN_ARGS="--tls-verify=false"
export PODMAN_PUSH_ARGS="--tls-verify=false"
podman login -u kubeadmin -p $(oc whoami -t) $(oc registry info) --tls-verify=false
```
2.  Download Portworx from infra node and push the images to the OCP in-cluster registry

```
mkdir /ibm
cd /ibm
wget http://icpfs1.svl.ibm.com/zen/cp4d-builds/3.0.1/misc/portworx/cpd3-portworx-v2.5.5.0-fp01.tgz
tar xzvf cpd3-portworx-v2.5.5.0-fp01.tgz
cd ./cpd-portworx/px-images
./process-px-images.sh -r $(oc registry info) -u kubeadmin -p $(oc whoami -t) -s kube-system -c podman -t ./px_2.5.5.0-dist.tgz
```

3.  Verify images are pushed into the registry
```
oc get imagestreams -n kube-system
```

4.  Install Portworx Operator Module using internal registry
```
cd /ibm/portworx_install/cpd-portworx/px-install-4.x
./px-install.sh install-operator
```

Wait for the Portworx Operator Pod to start successfully before proceeding 
```
oc get pods -n kube-system -w
```

5.  Create Portworx cluster using separate devices for application and metadata storage (Recommended)
```
./px-install.sh install-storage /dev/vdb /dev/vdc
```

Watch pods come up
```
oc get po -n kube-system -w
```

Check Portworx status
```
PX_POD=$(kubectl get pods -l name=portworx -n kube-system -o jsonpath='{.items[0].metadata.name}')
kubectl exec $PX_POD -n kube-system -- /opt/pwx/bin/pxctl status
```

6.  Create Sample Storage Class and Persistent Volume Claim to Test Portworx Installation 
```
./px-install.sh install-sample-pvc 
oc create -f ./px-test.yaml
```
Check the status of the created PVC and Pod - volume should be bounded, pod running:
```
oc get pvc
oc get po       
```

7.  Install Storage Classes for Cloud Pak for Data 
```
./px-sc.sh 
```

### Uninstall Portworx Procedure (Destructive / complete data loss, proceed with caution!)

```
cd ~/cpd-portworx/px-install-4.x
./px-uninstall.sh 
```



   




