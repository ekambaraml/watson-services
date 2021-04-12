# wks 1.1.1 on CP4D 2.5 (OpenShift 311) 

Draft 1
_________________________________________________________

##  Reference 

Documentation:  https://www.ibm.com/support/producthub/icpdata/docs/content/SSQNUZ_current/cpd/svc/watson/knowledge-studio-install.html
Readme:  Readme: https://github.com/ibm-cloud-docs/data-readmes/blob/master/watson-knowledge-studio-README.md
Requirements:  https://apps.na.collabserv.com/wikis/home?lang=en-us#!/wiki/Wd855b33ea663_4b57_a7c7_f5e8e37c2716/page/Watson%20Install%20Prereqs%20(Q4%202019%20Release)/edit

URLs
OpenShift Admin URL:  
https://cp4d-clustername:8443

Cloud Pak Admin URL:  
https://cp4d-namespace-cpd-cp4d-namespace.apps.cp4d-clustername

CLI Login 
```
oc login cp4d-clustername:8443 -u ocadmin -p ocadmin
docker login -u $(oc whoami) -p $(oc whoami -t ) $(oc get routes docker-registry -n default -o template={{.spec.host}})
```

_________________________________________________________

##  START HERE
This cheatsheet can be used to do a vanilla development installation of Watson Knowledge Studio  1.1.1 on CP4D 25 on Openshift 3.11 with portworx Storage.  

### Overview
* Do a Find and replace for the variables below to update the syntax of the commands below for your installation.   Do not use cheatsheet from box as the formatting of commands is lost. 
* Verify prereqs are met
* Follow instructions to install & verify
_________________________________________________________

## STEP 1 - Replace variables for your deploy  
* Find and replace `cp4d-clustername` with your clustername (typically load balancer fqdn) - ex: wp-wa-stt-feb23.icp.ibmcsf.net
* Find and replace your `release-name` with the deployment name
* Find and replace your `cp4d-namespace` with your CP4D namespace or project name - ex: zen
* Find and replace  `cpd-linux-install-directory` with the name of the directory you installed cpd from, example:  /ibm/cpd-linux/
* Find and replace `IP_address` with the IP address of the node you are installing from.  If not a node within the Openshift cluster should have docker and oc cli installed.
* Find and replace `workingdir` with the name of the directory you will be working from.   example:  data/ibm (fyre) or ibm

_________________________________________________________

## STEP 2 - Login into Openshift & Docker from the node you will be installing from

```
ssh root@IP_address
oc login cp4d-clustername:8443 -u ocadmin -p ocadmin
docker login -u $(oc whoami) -p $(oc whoami -t ) $(oc get routes docker-registry -n default -o template={{.spec.host}})
```

_________________________________________________________

## STEP 3 Verify Prereqs using oc-healthcheck.sh script or commands below


### To use Script

Grab oc-healthcheck.sh from Dimply - password is Trans001!
```
cd /root
scp xfer@9.30.44.60:/root/ga/oc-healthcheck.sh .
chmod +x oc-healthcheck.sh
./oc-healthcheck.sh
```

### or via Commands
```
# Verify CPUs has AVX2 support (not sure required for wks)
cat /proc/cpuinfo | grep avx2

# Verify OpenShift version 3.11 
oc version

# Verify Cluster is using CRI-O Container Runtime as required for Portworx
oc get nodes -o wide

# Verify Default thread count is set to 8192 pids
for node in $(oc get node -o=jsonpath={.items[*].metadata.name}); do echo -n "${node} " ; ssh root@${node} cat /etc/crio/crio.conf | grep pids_limit ; done


# Verify Ample space in to extract tar file & load images - 300 gb  for root, /tmp and /var/local/docker
df -h

# Verify Portworx is operational

PX_POD=$(kubectl get pods -l name=portworx -n kube-system -o jsonpath='{.items[0].metadata.name}')
kubectl exec $PX_POD -n kube-system -- /opt/pwx/bin/pxctl status


# Verify Portworx is running on all worker nodes
oc get pods --all-namespaces -o wide | grep portworx-api

# Verify Portworx StorageClasses are available 
oc get storageclasses | grep portworx 

# Verify Cloud Pak for Data 2.5 Control Plane installed 
oc get pods --all-namespaces | grep zen
```

Do not proceed to installation unless all prereqs are confirmed
_________________________________________________________

## STEP 4 Install Procedures  
_________________________________________________________

Download Watson Package and transfer to master node 

Release info here: https://apps.na.collabserv.com/wikis/home?lang=en-us#!/wiki/Wd855b33ea663_4b57_a7c7_f5e8e37c2716/page/Watson%20on%20Cloud%20Pak%20Releases

Optionally Grab Archive from Dimply - password is Trans001!
```
scp xfer@9.30.44.60:/root/ga/ibm-watson-ks-prod-1.1.1.tgz .
```

Extract Watson archive to filesystem that has ample space 
```
cd /workingdir
mkdir /workingdir/ibm-watson-knowledge-studio-ppa
tar -xvf ibm-watson-ks-prod-1.1.1.tgz -C /workingdir/ibm-watson-knowledge-studio-ppa
```

Extract chart - Note: this step will hardcode the service accts created in the next step to the release name of release-name
```
cd /workingdir/ibm-watson-knowledge-studio-ppa
mkdir /workingdir/ibm-watson-knowledge-studio-ppa/wks/charts/helm-templates
cd /workingdir/ibm-watson-knowledge-studio-ppa/wks/charts
/cpd-linux-install-directory/bin/utils/helm template ./ibm-watson-ks-prod-1.1.1.tgz  -n release-name --output-dir helm-templates/ --set global.image.repository=docker-registry.default.svc.cluster.local:5000/cp4d-namespace/
```

Create service accounts for Watson Knowledge Studio
```
oc create -f helm-templates/ibm-watson-ks-prod/templates/role.yaml -f helm-templates/ibm-watson-ks-prod/templates/service-account.yaml -f helm-templates/ibm-watson-ks-prod/templates/role-binding.yaml 
```

Check for cp4d-namespace label 
```
kubectl get namespace cp4d-namespace --show-labels
```

Run labelNamespace.sh  (if needed - only needs to be done once per cluster when installing multiple services)
```
kubectl label --overwrite namespace/cp4d-namespace ns=cp4d-namespace
```

Create Portworx Storage Class portworx-wks.yaml by pasting text below.

```
cat <<EOF > "${PWD}/portworx-wks.yaml"

apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: portworx-wks
parameters:
  block_size: 64k
  io_profile: db
  priority_io: high
  repl: "3"
  shared: "true"
  snap_interval: "0"
provisioner: kubernetes.io/portworx-volume
reclaimPolicy: Delete
volumeBindingMode: Immediate

EOF
```

Apply Portworx Storage Class portworx-wks.yaml
```
oc create -f portworx-wks.yaml
```

Prepare Override File wks-values-override.yaml by pasting text below

**Note - override.yaml is tied to release name of release-name**

```
cd /cpd-linux-install-directory/bin
```

```
cat <<EOF > "${PWD}/wks-values-override.yaml"
global:
  existingServiceAccount: release-name-ibm-watson-ks
  icpDockerRepo: "docker-registry.default.svc.cluster.local:5000/cp4d-namespace/"
  image:
    repository: "docker-registry.default.svc.cluster.local:5000/cp4d-namespace"

creds:
  image:
    repository: "docker-registry.default.svc.cluster.local:5000/cp4d-namespace"

mongodb:
  config:
    image:
      repository: "docker-registry.default.svc.cluster.local:5000/cp4d-namespace"
  mongodbInstall:
    image:
      repository: "docker-registry.default.svc.cluster.local:5000/cp4d-namespace"
  mongodb:
    image:
      repository: "docker-registry.default.svc.cluster.local:5000/cp4d-namespace"
  creds:
    image:
      repository: "docker-registry.default.svc.cluster.local:5000/cp4d-namespace"
  test:
    image:
      repository: "docker-registry.default.svc.cluster.local:5000/cp4d-namespace"
  persistentVolume:
    storageClass: "portworx-wks"
minio:
  persistence:
    storageClass: "portworx-wks"
postgresql:
  persistence:
    storageClassName: "portworx-wks"
etcd:
  dataPVC:
    storageClassName: "portworx-wks"

glimpse:
  creds:
    image:
      repository: "docker-registry.default.svc.cluster.local:5000/cp4d-namespace"
  builder:
    image:
      repository: "docker-registry.default.svc.cluster.local:5000/cp4d-namespace/wks-glimpse-ene-builder"
  query:
    modelmesh:
      image:
        repository: "docker-registry.default.svc.cluster.local:5000/cp4d-namespace/model-mesh"
    glimpse:
      image:
        repository: "docker-registry.default.svc.cluster.local:5000/cp4d-namespace/wks-ene-expand"
  helmTest:
    image:
      repository: "docker-registry.default.svc.cluster.local:5000/cp4d-namespace/opencontent-icp-cert-gen-1"

wcn:
  sch:
    image:
      repository: "docker-registry.default.svc.cluster.local:5000/cp4d-namespace"
  addonService:
    zenNamespace: "cp4d-namespace"

awt:
  persistentVolume:
    storageClassName: "portworx-wks"
EOF
```

Get Helm from Tiller pod

**only needs to be done once per cluster when installing multiple services**
```
cd /usr/local/bin
tiller_pod=$(oc get po | grep icpd-till | awk '{print $1}')
oc cp ${tiller_pod}:helm helm
chmod +x helm
./helm init --client-only
```

Note - you will see a messsage about "Not installing tiller due to 'client-only' flag having been set" this is normal

```
#Set targeted namespace 
oc project cp4d-namespace

#Change into bin directory from cp4d install
cd /cpd-linux-install-directory/bin

#Establish the certificate and key for Helm Tiller
export TILLER_NAMESPACE=cp4d-namespace
oc get secret helm-secret -n $TILLER_NAMESPACE -o yaml|grep -A3 '^data:'|tail -3 | awk -F: '{system("echo "$2" |base64 --decode > "$1)}'
export HELM_TLS_CA_CERT=$PWD/ca.cert.pem
export HELM_TLS_CERT=$PWD/helm.cert.pem
export HELM_TLS_KEY=$PWD/helm.key.pem
helm version  --tls

#Get external registry
export EXTERNAL_REGISTRY_PREFIX=$(oc get routes docker-registry -n default -o template={{.spec.host}})/cp4d-namespace
```

Run deploy script 

```
./deploy.sh --docker_registry_prefix=docker-registry.default.svc.cluster.local:5000/cp4d-namespace --external_registry_prefix=$EXTERNAL_REGISTRY_PREFIX --target_namespace=cp4d-namespace --storage_class=portworx-wks -O ./wks-values-override.yaml -d /workingdir/ibm-watson-knowledge-studio-ppa/wks -e release-name
```

The deploy.sh will test for environment variables and start the load the images to the cp4d repo.  Once the images have been successfully uploaded, the wks chart will be installed.


Watch deployment spin up

Open up a second terminal window 

```
ssh root@IP_address
watch oc get job,pod --namespace cp4d-namespace -l release=release-name
```
Wait for all pods to become ready.

_________________________________________________________

## OPTIONAL DEBUG

To debug failures, start with the tiller log

`oc get pods | grep till`
`oc logs {tiller-pod-name}`


To check status of your deployment
```
helm status --tls release-name --debug
```

To check for pods not Running or Running but not ready
```
oc get pods --all-namespaces | grep -Ev '1/1|2/2|3/3|4/4' | grep -v 'Completed'
```
_________________________________________________________


## Provision your instance
Login to Cloud Pak Cluster:  https://cp4d-namespace-cpd-cp4d-namespace.apps.cp4d-clustername/cp4d-namespace/#/addons   
**credentials:  admin / pw: password**

* Select Watson Service
* Select Provision Instance
* Select Create Instance and give it a name 
* Open Watson Tooling 

_________________________________________________________

## Verify deployment

Run Test chart
```
helm test --tls release-name
```


**Note:  To delete pods from prior test chart execution, run with  --cleanup flag then you can run again with or without flag.**
```
helm test --tls release-name -cleanup
```

**need wks validation steps**


_________________________________________________________

## Capture information about deployment / gather baseline information (Highly recommended)

#Download openshift Collector script and copy to Master node (ibm directory): https://ibm.box.com/s/5r0bzqawsusbf81iiwp7kukw5d0nhf91

#Capture information about deployment
```
chmod +x openshiftCollector.sh
./openshiftCollector.sh -c cp4d-clustername -u ocadmin -p ocadmin -n cp4d-namespace -t
```


or 

#run commands below to capture manually

```
kubectl get nodes --show-labels >cp4d-clustername_nodes.txt

kubectl get nodes -o=jsonpath="{range .items[*]}{.metadata.name}{'\t'}{.status.allocatable.memory}{'\t'}{.status.allocatable.cpu}{'\n'}{end}" >cp4d-clustername_compute.txt

kubectl get pods -o wide -l release=release-name >cp4d-clustername_pods.txt

helm status --tls release-name >cp4d-clustername_helm_status.txt

kubectl describe nodes>describe_nodes.txt

helm get release-name --tls >helm_release_cp4d-clustername.txt

helm get values release-name --tls >helm_values_cp4d-clustername.txt
```

_________________________________________________________

## How to Delete Deployment 

```
#Establish the certificate and key for Helm Tiller
export TILLER_NAMESPACE=cp4d-namespace
oc get secret helm-secret -n $TILLER_NAMESPACE -o yaml|grep -A3 '^data:'|tail -3 | awk -F: '{system("echo "$2" |base64 --decode > "$1)}'
export HELM_TLS_CA_CERT=$PWD/ca.cert.pem
export HELM_TLS_CERT=$PWD/helm.cert.pem
export HELM_TLS_KEY=$PWD/helm.key.pem

#Delete Deployment
helm delete --tls --no-hooks --purge release-name

#Post uninstall cleanup
kubectl delete job,deploy,rs,pod,statefulset,configmap,secret,ingress,service,serviceaccount,role,rolebinding,pvc,poddisruptionbudget --selector=release=release-name --namespace=cp4d-namespace

#Remove the configmap
kubectl delete cm stolon-cluster-release-name-postgresql
```










