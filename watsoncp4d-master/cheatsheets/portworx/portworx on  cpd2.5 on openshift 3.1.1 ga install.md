# Reference 

Beta release of Portworx for CP4D:  https://github.ibm.com/PrivateCloud-analytics/portworx-util/releases
Beta instructions: https://github.ibm.com/PrivateCloud-analytics/portworx-util/blob/master/cpd-portworx/README.txt
Storage classes:  https://www.ibm.com/support/knowledgecenter/en/SSQNUZ_2.5.0/cpd/install/portworx-storage-classes.html
Portworx Documentation https://docs.portworx.com/portworx-install-with-kubernetes/on-premise/openshift/daemonset/
Practice Page:  https://apps.na.collabserv.com/wikis/home?lang=en-us#!/wiki/Wd855b33ea663_4b57_a7c7_f5e8e37c2716/page/Portworx%20Reference


## CLI Login - Inside the Openshift Cluster 

```(sh)
oc login -u ocadmin -p ocadmin -n zen --insecure-skip-tls-verify
docker login -u $(oc whoami) -p $(oc whoami -t )  docker-registry.default.svc:5000
```

## Download tarball and transfer to master node

https://github.ibm.com/PrivateCloud-analytics/portworx-util/releases/download/alpha5/cpd-portworx.tgz
wget doesn't seem to work not sure why 

## Install Podman on all nodes (masters and workers) if it is not already installed

```(sh)
for node in $(oc get node -o=jsonpath={.items[*].metadata.name}); do echo -n "${node} " ; ssh root@${node} yum -y install podman ; done`
```

## Create a directory to store the images

```(sh)
mkdir -p /tmp/cpd-px-images
```

## untar file

chmod +x cpd-portworx.tgz
tar xvf cpd-portworx.tgz

# Download Portworx images 

```(sh)
cd cpd-portworx
bin/px-images.sh -d /tmp/cpd-px-images download
```
Note: for cases where the OpenShift cluster nodes are in an air-gapped environment, copy the images directory into a host inside that environment, from where you would trigger the installation.

#Verify images
ls /tmp/cpd-px-images


## Apply the Portworx IBM Cloud Pak for Data activation on the OpenShift nodes:

```(sh)
bin/px-util initialize 

#Load the Portworx Docker images into every node in the cluster
bin/px-images.sh -e 'ssh -o StrictHostKeyChecking=no -l root' -d /tmp/cpd-px-images load
```
    The 'load' command uses ssh to transfer the image files and invokes 'podman' on the OpenShift host nodes to load the Portworx images. The "-e" argument enables you to pass additional arguments to ssh in to the cluster nodes.

#Check to make sure the images are on the nodes
podman images | grep portworx

Important:  Stop & fix if you don't see images on the worker nodes

#Deploy the Portworx services:
bin/px-install.sh -pp Never install

    The "Never" argument is used as the Image Pull Policy for the Portworx pods and is used to ensure that there is no need to access external registries for these images.

#Define Portworx Storage Classes
bin/px-sc.sh

- Running this script helps create the storage classes that are typically used in Cloud Pak for Data services.

Note: If Portworx has already been setup on your cluster, the OpenShift cluster admin could run just the bin/px-sc.sh script by itself to create the Cloud Pak for Data recommended storage classes.

_________________________________________________________

#Verify Portworx 

#Watch Portworx pods spin up.  
watch oc get pods -n kube-system

Important:  Stop & fix if you don't see all pods running 

#Verify storageclasses were created
oc get storageclass

#Confirm Portworx has been deployed correctly using the pxctl status command
PX_POD=$(kubectl get pods -l name=portworx -n kube-system -o jsonpath='{.items[0].metadata.name}')
kubectl exec $PX_POD -n kube-system -- /opt/pwx/bin/pxctl status

  You should see this message: "Status: PX is operational"

#Create a Test pv using one of the portworx storageclasses

cat > testpx.yaml << EOF
`kind: PersistentVolumeClaim
apiVersion: v1
metadata:
  name: testpx-pvc
spec:
  storageClassName: portworx-shared-sc
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 1Gi
EOF
`

#Apply
oc create -f testpx.yaml

#Check PV to see that it created and bound successfully. 
oc get pv | grep test

#Delete PV
oc delete pv {pvname}

_________________________________________________________

#Uninstall Portworx Procedure

#Uninstall Software
bin/px-uninstall.sh

#Remove Portworx Docker images 
bin/px-images.sh -e 'ssh -o StrictHostKeyChecking=no -l root'  rmi

The "-e" argument allows you to customize ssh to the cluster nodes.

   




