End-to-end-fyre


#STEP 1 - Replace variables for your deploy  
Find and replace `cp4d-clustername` with your clustername 
Find and replace your `cp4d-masternode` with the deployment name

### Reference
URLs
OpenShift Admin URL:  
https://cp4d-clustername:8443
9.30.87.74

Cloud Pak Admin URL:  
https://zen-cpd-zen.apps.cp4d-clustername

CLI Login 
oc login cp4d-clustername:8443 -u ocadmin -p ocadmin
docker login -u $(oc whoami) -p $(oc whoami -t ) $(oc get routes docker-registry -n default -o template={{.spec.host}}) 

#############################

## STEP 1
### Provision VM Stack using Create Fyre Cluster 
cd /Users/jnifir/Documents/github/openShift/dec12
modified jwcreate.sh with number of workers=5
./createjw.sh

What script does:
Provisioned VM (5 workers, 1 master with nfs)
auto creates /host inventory file with crio and nfs settings and proper worker nodes
Set Selinux to enforcing
Rebooted nodes for selinux to take effect
Setup NFS Server - partitioned disk and setup on notes

### Verify
ssh cp4d-masternode
showmount -e cp4d-masternode
cd /root

## STEP 2
### Install Openshift using ansible

cat > setupseboolean.yaml << EOF
---
- name: SELinux Boolean
  hosts: all
  tasks:
  - name: set seboolean virt_use_nfs
    seboolean: name=virt_use_nfs state=yes persistent=yes
EOF

cat > setvmmaxmapcount.yaml << EOF
---
- name: Setup for Elasticsearch
  hosts: all
  tasks:
  - name: set vm max map count
    shell: sysctl -w vm.max_map_count=262144; echo "vm.max_map_count=262144" >> /etc/sysctl.conf
EOF

ansible-playbook -i hosts setvmmaxmapcount.yaml
ansible-playbook -i hosts setupseboolean.yaml

### Run Prereq check
ansible-playbook -i hosts /usr/share/ansible/openshift-ansible/playbooks/prerequisites.yml

### Deploy OpenShift
ansible-playbook -i hosts /usr/share/ansible/openshift-ansible/playbooks/deploy_cluster.yml


## Step 3 Set accts for openshift

### Login to oc
oc login -u system:admin


### Create user "ocadmin"
cd /etc/origin/master;htpasswd -b htpasswd ocadmin ocadmin

### Set ocadmin to cluster admin
oc adm policy add-cluster-role-to-user cluster-admin ocadmin
oc adm policy add-cluster-role-to-user cluster-admin ocadmin

### Test CLI ogin
oc login --username=ocadmin --password=ocadmin --insecure-skip-tls-verify
oc login https://cp4d-clustername:8443 -u ocadmin -p ocadmin

### Test Browser access to OpenShift
https://cp4d-clustername:8443


### Unregister the system

cat > unregister.yaml << EOF
---
- name: un-register
  hosts: all
  tasks:
  - name: unregister all
    shell: subscription-manager unregister 
EOF
ansible-playbook -i hosts unregister.yaml


## Step 4 Setup NFS storage for CP4D 
mkdir /data/ibm (on master)

From local window, copy up script: scp ./set_up_oc4.sh root@9.30.244.102:/data/ibm

Back to master
chmod +x set_up_oc4.sh
./set_up_oc4.sh 172.16.174.58

### Verify
oc get storageclass

### Optionally test with testpv

cat <<EOF | kubectl apply  -f -
kind: PersistentVolumeClaim
apiVersion: v1
metadata:
  name: testpx-pvc
spec:
  storageClassName: nfs-client
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 1Gi
EOF

Check that it's bound
oc get pv 

Delete
oc delete pv {testpv name}



## Setting up Portworx storage

### Download tarball and transfer to master node
https://github.ibm.com/PrivateCloud-analytics/portworx-util/releases/download/alpha5/cpd-portworx.tgz
scp ./cpd-portworx* root@9.30.87.74:/data/ibm

### Install Podman on all nodes (masters and workers) if it is not already installed
yum install podman
`for node in $(oc get node -o=jsonpath={.items[*].metadata.name}); do echo -n "${node} " ; ssh root@${node} yum -y install podman ; done`

### Create a directory to store the images
mkdir -p /tmp/cpd-px-images

### untar file
chmod +x cpd-portworx.tgz
tar xvf cpd-portworx.tgz

### Download Portworx images 
cd cpd-portworx
bin/px-images.sh -d /tmp/cpd-px-images download

### Verify 
ls /tmp/cpd-px-images


### Apply the Portworx IBM Cloud Pak for Data activation on the OpenShift nodes:
Verify /nothing in /ibm
bin/px-util initialize 

### Load the Portworx Docker images into every node in the cluster
bin/px-images.sh -e 'ssh -o StrictHostKeyChecking=no -l root' -d /tmp/cpd-px-images load

    The 'load' command uses ssh to transfer the image files and invokes 'podman' on the OpenShift host nodes to load the Portworx images. The "-e" argument enables you to pass additional arguments to ssh in to the cluster nodes.

### Check to make sure the images are on the nodes
podman images | grep portworx

Stop if you don't see images on the worker nodes

### Deploy the Portworx services:
bin/px-install.sh -pp Never install

    The "Never" argument is used as the Image Pull Policy for the Portworx pods and is used to ensure that there is no need to access external registries for these images.

### Define Portworx Storage Classes
bin/px-sc.sh

- Running this script helps create the storage classes that are typically used in Cloud Pak for Data services.

Note: If Portworx has already been setup on your cluster, the OpenShift cluster admin could run just the bin/px-sc.sh script by itself to create the Cloud Pak for Data recommended storage classes.

### Verify Portworx 

### Check to see if pods are running:
watch oc get pods -n kube-system

### Check to see if storageclasses were created
oc get storageclass

### Confirm Portworx has been deployed correctly using the pxctl status command
PX_POD=$(kubectl get pods -l name=portworx -n kube-system -o jsonpath='{.items[0].metadata.name}')
kubectl exec $PX_POD -n kube-system -- /opt/pwx/bin/pxctl status

  You should see this message: "Status: PX is operational"

### Create a Test pv using one of the portworx storageclasses
oc get storageclass


### create testpx.yaml:
cat > testpx.yaml << EOF

kind: PersistentVolumeClaim
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

### Apply
oc create -f testpx.yaml
kubectl apply -f testpx.yaml

### Check PV to see that it created and bound successfully. 
kubectl get pv | grep test

### Delete PV
oc delete pvc testpx-pvc




## Step 5 Install CP4D

https://www.ibm.com/support/knowledgecenter/SSQNUZ_2.5.0/cpd/install/rhos-install.html

### Install CP4D Lite

cd /data/ibm
wget http://icpfs1.svl.ibm.com/zen/cp4d-builds/2.5.0.0/production/installer/cloudpak4data-ee-v2.5.0.0.tgz
mkdir cpd-linux
tar -xvf cloudpak4data-ee-v2.5.0.0.tgz -C cpd-linux
cd cpd-linux/
rm repo.yaml
wget http://icpfs1.svl.ibm.com/zen/cp4d-builds/2.5.0.0/production/GM/cpd/repo.yaml
chmod +x /data/ibm/cpd-linux/bin/cpd-linux

### verified my registry
oc get routes -n default

### Log into openshift and docker with external registry
oc login cp4d-clustername:8443 -u ocadmin -p ocadmin

docker login -u $(oc whoami) -p $(oc whoami -t ) $(oc get routes docker-registry -n default -o template={{.spec.host}}) 

### part 1 
set up environment - must be done by cluster admin.  makes zen namespace.

echo "export DOCKER_REGISTRY_PREFIX=docker-registry-default.apps.cp4d-clustername/zen
export TARGET_NAMESPACE=zen
export STORAGE_CLASS=portworx-shared-gp3 
export TILLER_NAMESPACE=zen" >> ~/.bashrc
source ~/.bashrc
cd bin
./cpd-linux adm \
  --repo ../repo.yaml \
  --assembly lite \
  --namespace zen \
  --verbose \
  --apply
Accept license


### create override file for cpd install
cd /data/ibm
cat > cp-override.yaml << EOF
zenCoreMetaDb:
  storageClass: portworx-metastoredb-sc
EOF



./cpd-linux \
  --repo ../repo.yaml \
  --assembly lite \
  --namespace zen \
  --override ./cp-override.yaml \
  --verbose \
  --target-registry-password $(oc whoami -t) \
  --target-registry-username $(oc whoami) \
  --storageclass portworx-shared-gp3 \
  --transfer-image-to $DOCKER_REGISTRY_PREFIX \
  --cluster-pull-prefix docker-registry.default.svc:5000/zen \
  --accept-all-licenses



Login if doing as another admin, but if same admin should already be on zen project

### part 2 - can be done by project admin
If running by project admin must run command below to grant cpd-admin-role to the project admin user
oc adm policy add-role-to-user cpd-admin-role Project_admin --role-namespace=Project -n Project

Then login as project user


./cpd-linux \
  --repo ../repo.yaml \
  --assembly lite \
  --namespace zen \
  --override /data/ibm/cpd-portworx/cp-override.yaml \
  --verbose \
  --storageclass portworx-shared-gp3 \
  --transfer-image-to docker-registry-default.apps.cp4d-clustername/zen \
  --cluster-pull-prefix docker-registry.default.svc:5000/zen \
  --target-registry-password $(oc whoami -t) \
  --target-registry-username $(oc whoami) \
  --accept-all-licenses


#portworx
./cpd-Operating_System --repo ./repo.yaml \
--assembly lite \
--namespace Project \
--storageclass Default_storage_class_name \
--override Override_file_path \
--transfer-image-to Registry_location \
--cluster-pull-prefix Registry_from_cluster \
--ask-push-registry-credentials


Test login to cp4d:[INFO] [2019-12-14 07:14:25-0765] Access the web console at https://zen-cpd-zen.apps.cp4d-clustername


you use same shell:sed -i.orig 's/1024/4096/' x    this will make backup of x as x.orig and change content of x from 2014 to 4096

### Modify CRIO Threads 

vi /etc/crio/crio.conf

%s/pids_limit = 1024/pids_limit = 8192/g
%s/pids_limit = 4096/pids_limit = 8192/g

cat > criopids.yaml << EOF
---
- name: Setup for CRIO Pid Limits
  hosts: all
  tasks:
  - name: pidlimit
    shell: sed -i.orig 's/1024/4096/' x; /etc/crio/crio.conf
EOF



### Modify CRIO
cat > criopids.yaml << EOF
---
- name: Setup for CRIO Pid Limits
  hosts: all
  tasks:
  - name: pidlimit
    shell: sed -i 's/1024/8192/' /etc/crio/crio.conf
EOF

ansible-playbook -i hosts criopids.yaml


### Check CRIO
`for node in $(oc get node -o=jsonpath={.items[*].metadata.name}); do echo -n "${node} " ; ssh root@${node} cat /etc/crio/crio.conf | grep pids_limit ; done`



