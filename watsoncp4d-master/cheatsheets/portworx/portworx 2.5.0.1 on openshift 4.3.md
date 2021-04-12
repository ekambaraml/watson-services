### Reference 

Portworx releases:  https://github.ibm.com/PrivateCloud-analytics/portworx-util/releases/tag/cpd-portworx-v2.5.0.1
Instructions:  https://github.ibm.com/PrivateCloud-analytics/CEA-Zen/wiki/How-to-install-Portworx-2.5.0.1-on-RedHat-OpenShift-4.3-System
Support:  #cp4d-storage. https://ibm-analytics.slack.com/archives/CTC7D7RPZ

### START HERE

This cheatsheet assumes 
* You are installing Portworx 2.5.0.1 on OpenShift 4.3 on Fyre.  
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
2.  Remote into each worker node and clean the /dev/vdc device 

```
oc get nodes
ssh core@workername
```
Check for raw disk - you need 2 on each worker ideally, but no more than 8 nodes / 5tb
```
lsblk 
```
Clean ceph from the /dev/vdc device
```
sudo bash
dd if=/dev/zero of=/dev/vdc bs=1M count=2
reboot
```
Repeat for the rest of the workers

Once complete, remote back in to each node and confirm partition has been removed (maybe we can automate this)

3.  Install podman on infrastructure node 
```
yum install podman
```

### Portworx Install

1.  Download Portworx and transfer to infra node
https://github.ibm.com/PrivateCloud-analytics/portworx-util/releases/tag/cpd-portworx-v2.5.0.1

2.  Extract Portworx tar  
```
tar xvf cpd-portworx-2.5.0.1.tar.gz
```

3.  Get the Portworx image files
```
cd cpd-portworx/px-images
wget http://icpfs1.svl.ibm.com/zen/cp4d-builds/3.0.0.0/misc/cpd-portworx/px_2.5.0.1-dist.tgz
cd ..
```

4.  Get registry URL & Set Podman env variables
```
oc project openshift-image-registry
oc patch configs.imageregistry.operator.openshift.io/cluster --type merge -p '{"spec":{"defaultRoute":true}}'
oc get route

export REGISTRY_URL=$(oc get routes default-route -n openshift-image-registry -o template={{.spec.host}})
export PODMAN_LOGIN_ARGS="--tls-verify=false"
export PODMAN_PUSH_ARGS="--tls-verify=false"

#verify you can login
podman login -u kubeadmin -p $(oc whoami -t) $REGISTRY_URL --tls-verify=false
```

5.  Load the Portworx Images using internal registry
```
./px-images/process-px-images.sh -r $REGISTRY_URL -u kubeadmin -p $(oc whoami -t) -s kube-system -c podman
```

6.  Install Portworx Operator Module using internal registry
```
cd px-install-4.3
./px-install.sh install-operator
```

Wait for the Portworx Operator Pod to start successfully before proceeding 
```
oc get pods -n kube-system -w
```

8.  Create Portworx cluster using separate devices for application and metadata storage (Recommended)
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

9.  Create Sample Storage Class and Persistent Volume Claim to Test Portworx Installation 
```
./px-install.sh install-sample-pvc 
oc create -f ./px-test.yaml
```
Check the status of the created PVC and Pod - volume should be bounded, pod running:
```
oc get pvc
oc get po       
```

10.  Install Storage Classes for Cloud Pak for Data 
```
./px-sc.sh 
```

### Uninstall Portworx Procedure (Destructive / complete data loss, proceed with caution!)

```
cd ~/cpd-portworx/px-install-4.3
./px-uninstall.sh 
```



   




