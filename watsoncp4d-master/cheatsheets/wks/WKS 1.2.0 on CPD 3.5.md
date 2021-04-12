Watson Knowledge Studio 1.2.0 on CPD 3.5.md

# WKS 1.2.0 on CP4D 3.5 (OpenShift 4.5) Draft 1 - untested


## Reference 

* Source:  
* Documentation:  https://www.ibm.com/support/producthub/icpdata/docs/content/SSQNUZ_latest/svc-welcome/watsonks.html
* Readme:  
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
This cheatsheet can be used to do a vanilla installation of Watson Knowledge Studio 1.2.0 on CP4D 3.5 on Openshift 4.5 with portworx Storage 2.5.5.  

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

_________________________________________________________

## STEP #2 - Cluster Verification for Service - needs updating
_________________________________________________________


_________________________________________________________

## STEP #3 - Service Install Procedures  
_________________________________________________________


1.  Switch to CPD Namespace
```
oc project $NAMESPACE
```

2.  Prepare repo.yaml for Service.   Add your apikey to the snippet below and paste to create 
Repo below will work for all Watson Services.

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
  # WKS
  - url: cp.icr.io
    username: cp
    apikey:
    namespace: "cp/knowledge-studio"
    name: wks-registry
  # LTS
  - url: cp.icr.io
    username: cp
    apikey: 
    namespace: cp/watson-lt
    name: lt-registry
  # Speech
  - url: cp.icr.io
    username: cp
    apikey: 
    namespace: cp/watson-speech
    name: spch-registry

fileservers:
  - url: https://raw.github.com/IBM/cloud-pak/master/repo/cpd/3.5
EOF
```

3.  Run adm task.  Edit below for your deployment and paste.  Assumes internal registry and kubeadmin user / password.  

```
NAMESPACE=
OPENSHIFT_USERNAME=kubeadmin 
OPENSHIFT_REGISTRY_PULL=image-registry.openshift-image-registry.svc:5000

./cpd-cli adm --repo ./repo.yaml --assembly watson-ks --arch x86_64 --namespace $NAMESPACE --accept-all-licenses --apply
```


4.  Install WKS assembly (--optional-modules edb-pg-base will install edb also) about 30 mins

```
NAMESPACE=
OPENSHIFT_USERNAME=kubeadmin 
OPENSHIFT_REGISTRY_PULL=image-registry.openshift-image-registry.svc:5000

./cpd-cli install  --repo repo.yaml --assembly watson-ks --namespace $NAMESPACE --storageclass portworx-shared-gp3 --transfer-image-to $(oc registry info)/$NAMESPACE --cluster-pull-prefix $OPENSHIFT_REGISTRY_PULL/$NAMESPACE --target-registry-username $OPENSHIFT_USERNAME --target-registry-password=$(oc whoami -t) --latest-dependency  --optional-modules edb-pg-base --insecure-skip-tls-verify  --accept-all-licenses  
```

Watson Knowledge Studio will now be installed.   

**To Watch install**

Open up a second terminal window and wait for all pods to become ready.  Control C to exit watch

```
ssh root@ip address
watch oc get pods -l icpdsupport/addOnId=watson-knowledge-studio
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

To see values used during install - replace with your instance name
```
oc get wks wks -o yaml
```

_________________________________________________________

## STEP #5 Provision Instance   


1.  Login to Cloud Pak Cluster:  https://zen-cpd-zen.apps.$CLUSTERNAME/zen/#/addons

`oc get route zen-cpd | awk '{print $2}'`

**credentials:  admin / pw: password**

* Select Watson Service
* Select Provision Instance
* Select Create Instance and give it a name 
* Open Watson Knowledge Studio Tooling 
* Create a workspace 

**Note: If you have trouble with the tooling, try incognito mode**


_________________________________________________________

### How to modify deployment
_________________________________________________________

To change deployment, modify Service operator & save.  Installation will automatically change as needed.


```
oc edit {servicename} {instancename}
example:  `oc edit wks wks`
```
```
oc edit wks `oc get wks --no-headers |awk '{ print $1}'`
```

_________________________________________________________

### How to Scale service
_________________________________________________________

With the default of no override yaml file, WKS will deploy in a medium configuration with multiple pods per service.

To scale to a development configuration, use command below.  To Scale back to HA config, use --config medium.

```
./cpd-cli scale --assembly watson-ks --config small -n zen
sleep 10
watch oc get pods -l icpdsupport/addOnId=watson-knowledge-studio
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
./cpd-cli uninstall --assembly watson-ks -n zen
```

Uninstall EDB
```
./cpd-cli uninstall --assembly edb-operator -n zen
```

Uninstall Service & all dependancies (--dry-run to see what will be removed)
```
./cpd-cli uninstall --assembly watson-ks -n zen --include-dependent-assemblies
```
_________________________________________________________

### How to Delete Deployment - Advanced
_________________________________________________________




