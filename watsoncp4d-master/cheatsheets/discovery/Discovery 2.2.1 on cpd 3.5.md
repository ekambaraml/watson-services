Watson Discovery 2.2.1 on CPD 3.5.md

# discovery 2.2.0 on CP4D 3.5 (OpenShift 4.5) 


## Reference 

* Source:  
* Documentation:  https://www.ibm.com/support/knowledgecenter/SSQNUZ_3.5.0/svc-discovery/discovery-install.html
* Readme:  https://cloud.ibm.com/docs/discovery-data?topic=discovery-data-release-notes#2-2-0-release-8-december-2020-cloud-pak-for-data-only-images-cpdonly-png-
* Watson Platform Requirements:  https://w3.ibm.com/w3publisher/watsoncp4d/watson-services/watson-platform-support
* Release info here: https://w3.ibm.com/w3publisher/editor/edit/watsoncp4d/cloud-pak-for-data/release-information

URLs
* OpenShift Admin URL:  `https://console-openshift-console.apps.$CP4DCLUSTERNAME`
* Cloud Pak Admin URL:  `https://zen-cpd-zen.apps.$CP4DCLUSTERNAME`
  

CLI Login 
```
oc login -u kubeadmin -p `cat ~/auth/kubeadmin-password` 
oc login --token=$(oc whoami -t ) --server=https://api.$CP4DCLUSTERNAME:6443
```

_________________________________________________________

##  START HERE
This cheatsheet can be used to do a vanilla installation of Watson Discovery 2.2.0 on CP4D 3.5 on Openshift 4.5 with portworx Storage 2.5.5.  

```
export INFRA=9.30.43.x
```
_________________________________________________________

## STEP #1 - Login into Openshift 


Set variables for your deployment and Login into Openshift from the node you will be installing from (infrastructure node or node with oc cli installed)

```
ssh root@$INFRA
export CP4DCLUSTERNAME=
export NAMESPACE=zen
oc login -u kubeadmin -p `cat ~/auth/kubeadmin-password`
oc login --token=$(oc whoami -t ) --server=https://api.$CP4DCLUSTERNAME:6443
```


## STEP #2 - Cluster Verification for Service - needs updating

need to add crio and elastic settings
https://www-03preprod.ibm.com/support/knowledgecenter/SSQNUZ_3.5.0_test/cpd/install/node-settings.html#node-settings__crio
https://www-03preprod.ibm.com/support/knowledgecenter/SSQNUZ_3.5.0_test/cpd/install/node-settings.html

```
# Verify CPUs has AVX2 support (not sure required for wks)
cat /proc/cpuinfo | grep avx2

# Verify OpenShift version 4.5 (works on 4.3, but not supported)
oc version

# Verify Cluster is using CRI-O Container Runtime as required for Portworx
oc get nodes -o wide

# Verify Ample space in to extract tar file & load images - Not sure how much space is enough?
df -h

# Verify Portworx is operational

PX_POD=$(kubectl get pods -l name=portworx -n kube-system -o jsonpath='{.items[0].metadata.name}')
kubectl exec $PX_POD -n kube-system -- /opt/pwx/bin/pxctl status


# Verify Portworx is running on all worker nodes
oc get pods --all-namespaces -o wide | grep portworx-api

# Verify Portworx StorageClasses are available 
oc get storageclasses | grep portworx 

# Verify Cloud Pak for Data 3 Control Plane installed 
oc get pods --all-namespaces | grep $NAMESPACE
```

Do not proceed to installation unless all prereqs are confirmed
_________________________________________________________

## STEP #3 - Service Install Procedures  
_________________________________________________________


1.  Switch to CPD Namespace
```
oc project $NAMESPACE
```

2.  Prepare repo.yaml for Service.   Add your apikey to the snippet below and paste to create 
Repo below will work for Assistant + Discovery.

```
cp repo.yaml cpdsave.yaml
cat <<EOF > "${PWD}/repo.yaml"

registry: 
  - 
    apikey: 
    name: base-registry
    namespace: ""
    url: cp.icr.io/cp/cpd
    username: cp
  # Watson Assistant
  - url: cp.icr.io
    username: "cp"
    apikey: 
    namespace: "cp/watson-assistant"
    name: wa-registry
  - url: cp.icr.io
    username: "cp"
    apikey: 
    namespace: "cp/watson-assistant"
    name: wa-registry-operator
  # ElasticSearch
  - url: cp.icr.io
    username: "cp"
    apikey: 
    namespace: "cp"
    name: elasticsearch-registry
  # Etcd
  - url: cp.icr.io
    username: "cp"
    apikey: 
    namespace: "cp"
    name: entitled-registry
  # Gateway, Redis, Minio, ElasticSearch
  - url: cp.icr.io
    username: "cp"
    apikey: 
    namespace: "cp"
    name: prod-entitled-registry
  # For EDB operator
  - url: cp.icr.io
    username: "cp"
    apikey: 
    namespace: "cp/cpd"
    name: databases-registry
  # ModelTrain Classic
  - url: cp.icr.io
    username: cp
    apikey: 
    namespace: cp/modeltrain
    name: modeltrain-classic-registry
  # Discovery
  - url: cp.icr.io
    username: cp
    apikey: 
    namespace: cp/watson-discovery
    name: watson-discovery-registry

fileservers:
  - url: https://raw.github.com/IBM/cloud-pak/master/repo/cpd/3.5
EOF
```

3.  Prepare override yaml for Service.   

Modify snippet below for your deployment

* Set deployment to 'Development' or 'Production'
* Set enableContentIntelligence to true if needed 
* Paste contents below to create file

```
cat <<EOF > "${PWD}/wd-install-override.yaml"
wdRelease:
  deploymentType: Development
  enableContentIntelligence: false
  elasticsearch:
    clientNode:
      persistence:
        size: 1Gi
    dataNode:
      persistence:
        size: 40Gi
    masterNode:
      persistence:
        size: 2Gi
  etcd:
    storageSize: 10Gi
  minio:
    persistence:
      size: 100Gi
  postgres:
    database:
      storageRequest: 30Gi
    useSingleMountPoint: true
  rabbitmq:
    persistentVolume:
      size: 5Gi
EOF

```

4.  Run adm task.  Edit below for your deployment and paste.  Assumes internal registry and kubeadmin user / password.  

```
NAMESPACE=
OPENSHIFT_USERNAME=kubeadmin 
OPENSHIFT_REGISTRY_PULL=image-registry.openshift-image-registry.svc:5000

./cpd-cli adm --repo ./repo.yaml --assembly watson-discovery --arch x86_64 --namespace $NAMESPACE --accept-all-licenses --apply
```


5.  Install edp-operator (assumes cluster has access to internet to pull / push images)

```
NAMESPACE=
OPENSHIFT_USERNAME=kubeadmin 
OPENSHIFT_REGISTRY_PULL=image-registry.openshift-image-registry.svc:5000

./cpd-cli install  --repo repo.yaml --assembly edb-operator --optional-modules edb-pg-base:x86_64 --namespace $NAMESPACE  --transfer-image-to $(oc registry info)/$NAMESPACE --cluster-pull-prefix $OPENSHIFT_REGISTRY_PULL/$NAMESPACE --target-registry-username $OPENSHIFT_USERNAME --target-registry-password=$(oc whoami -t) --latest-dependency  --insecure-skip-tls-verify  --accept-all-licenses 
```


6.  Install WD assembly 

```
NAMESPACE=
OPENSHIFT_USERNAME=kubeadmin 
OPENSHIFT_REGISTRY_PULL=image-registry.openshift-image-registry.svc:5000

./cpd-cli install  --repo repo.yaml --assembly watson-discovery --version 2.2.1 --namespace $NAMESPACE --storageclass portworx-db-gp3-sc --transfer-image-to $(oc registry info)/$NAMESPACE --cluster-pull-prefix $OPENSHIFT_REGISTRY_PULL/$NAMESPACE --target-registry-username $OPENSHIFT_USERNAME --target-registry-password=$(oc whoami -t) --latest-dependency  --insecure-skip-tls-verify  --accept-all-licenses --override wd-install-override.yaml
```

Watson discovery will now be installed.   

**To Watch install**

Open up a second terminal window and wait for all pods to become ready.  Control C to exit watch

```
ssh root@ip address
watch oc get pods -l icpdsupport/addOnId=discovery
```

**To check for pods not Running or Running but not ready**
```
oc get pods --all-namespaces | grep -Ev '1/1|2/2|3/3|4/4|5/5|6/6|7/7|8/8' | grep -v 'Completed'
```

_________________________________________________________

## STEP #4 Verify   


1.  Check the status of the assembly and modules
```
./cpd-cli status --namespace $NAMESPACE
```

How to test service?  
https://github.ibm.com/Watson-Discovery/bob/wiki/DVTs 


To see values used during install - replace with your instance name
```
oc get wd wd
```

If rabbit-mq-operator keeps dying:
oc get wd wd -o yaml | grep failedComponents: 
increase the memory of model-train-classic-operator:  https://ibm-analytics.slack.com/archives/CJQ323MMM/p1607820199468500
oc edit deployment model-train-classic-operator
try memory limits: 512Mi requests: 512Mi


_________________________________________________________

## STEP #5 Provision Instance   


1.  Login to Cloud Pak Cluster:  https://zen-cpd-zen.apps.$CLUSTERNAME/zen/#/addons

`oc get route zen-cpd | awk '{print $2}'`

**credentials:  admin / pw: password**

* Select Watson Service
* Select Provision Instance
* Select Create Instance and give it a name 
* Open Watson discovery Tooling 
* Click on Sample project and wait for it to setup
* Try a sample query

**Note: If you have trouble with the tooling, try incognito mode**


_________________________________________________________

## STEP #6 Test via API    

Download files needed for WD test from:  https://github.ibm.com/jennifer-wales/watsoncp4d/tree/master/cheatsheets/discovery/discovery-testing
```
chmod +x wds-api-test.sh
./wds-api-test.sh
```
You will be prompted for the service Token & API endpoint.  To find: 
* Login to Cloud Pak Cluster:  https://zen-cpd-zen.apps.$CP4DCLUSTERNAME/zen/#/myInstances

**credentials:  admin / pw: password**
* Click on Instance name 
* Copy / Paste the token and api end point from the Access information section, then copy / paste the lines into a terminal window when prompted.

_________________________________________________________

### How to modify deployment / Scale Service
_________________________________________________________

To change deployment, modify Service operator & save.  Installation will automatically change as needed.  

* Enable / Disable Content Intelligence
* Change Deployment type (Development, Production)

```
oc edit {servicename} {instancename}
example:  `oc edit wd wd`


oc edit wd `oc get wd --no-headers |awk '{ print $1}'`
```

_________________________________________________________

### OpenShift Collector  
_________________________________________________________

Use OpenShift Collector to capture information about deployment / gather baseline information / or use for debugging

* Download openshiftCollector4.sh and copy to installation node: https://github.ibm.com/jennifer-wales/watsoncp4d/blob/master/scripts/openshiftCollector4.sh

* Run Script
```
chmod +x openshiftCollector4.sh
./openshiftCollector4.sh -c api.$CP4DCLUSTERNAME -u kubeadmin -p `cat ~/auth/kubeadmin-password` -n $NAMESPACE -t

#fyre
./openshiftCollectorv4.sh -c api.$HOSTNAME -u kubeadmin -p `cat ~/auth/kubeadmin-password` -n zen -t
```
_________________________________________________________

### How to Delete Deployment 
_________________________________________________________


Uninstall Service (not tested)

```
./cpd-cli uninstall --assembly watson-discovery -n zen
```

Uninstall EDB
```
./cpd-cli uninstall --assembly edb-operator -n zen
```

Uninstall Service & all dependancies (--dry-run to see what will be removed)
```
./cpd-cli uninstall --assembly watson-discovery -n zen --include-dependent-assemblies
```
_________________________________________________________

### How to Delete Deployment - Advanced
_________________________________________________________

Could not delete via cpd-cli - no longer showed watson-discovery assembly status even though still installed and functioning

```
oc delete wd wd
oc exec -it {cpd-install-operator-pod}
helm ls --tls
helm delete wd --tls
for i in `oc get pvc | grep wd | awk '{ print $1 }'`; do oc delete pvc $i ; done
sleep 10
for i in `oc get pv | grep wd | awk '{ print $1 }'`; do oc delete pv $i ; done
sleep 10
for i in `oc get cm | grep discovery | awk '{ print $1 }'`; do oc delete cm $i ; done
```



