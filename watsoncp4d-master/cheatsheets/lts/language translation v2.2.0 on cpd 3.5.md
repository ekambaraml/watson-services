# Language Translation 2.2.0 on CP4D 3.5 (OpenShift 4.5) Draft 1 


## Reference 

* Documentation:  https://www.ibm.com/support/producthub/icpdata/docs/content/SSQNUZ_latest/svc-lang/language-translator-install-adm.html
* Watson Platform Requirements:  https://w3.ibm.com/w3publisher/watsoncp4d/watson-services/watson-platform-support
* Release info here: https://w3.ibm.com/w3publisher/editor/edit/watsoncp4d/cloud-pak-for-data/release-information
* Service Docs here:  https://cloud.ibm.com/docs/language-translator-data?topic=language-translator-data-gettingstarted

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
This cheatsheet can be used to do a vanilla installation of Language Translation Server 2.2.0 on CP4D 3.5.x on Openshift 4.5 with portworx Storage  

Set variable below with your infrastructure IP Address

```
export INFRA=9.30.
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

1.  Verify Portworx Storage class for Service.  If missing create.
```
oc get storageclass |grep portworx-db-gp2-sc
```

2.  Switch to CPD Namespace
```
oc project $NAMESPACE
```

3.  Prepare repo.yaml for Service.   https://www.ibm.com/support/knowledgecenter/SSQNUZ_3.5.0/cpd/install/installation-files.html
Add your apikey to the snippet below and paste to create.

```
cp repo.yaml cpdsave.yaml
cat <<EOF > "${PWD}/repo.yaml"

# CP4D
registry:
  - url: cp.icr.io
    username: cp
    apikey: 
    namespace: cp/cpd
    name: base-registry
# Minio Operator
  - url: cp.icr.io
    username: cp
    apikey: 
    namespace: cp
    name: prod-entitled-registry
# EDB Operator
  - url: cp.icr.io
    username: cp
    apikey: 
    namespace: cp/cpd
    name: databases-registry
# Language Translator
  - url: cp.icr.io
    username: cp
    apikey: 
    namespace: cp/watson-lt
    name: lt-registry
fileservers:
  -  url: https://raw.github.com/IBM/cloud-pak/master/repo/cpd/3.5

EOF
```

4.  Prepare override yaml for Service:  

* Enable desired translations to override below 
guide:  https://www.ibm.com/support/knowledgecenter/SSQNUZ_3.5.0/svc-lang/language-translator-override.html
* Update zenNamespace to $NAMESPACE if not zen
* Paste contents below to create sample override 

Reference
https://github.com/IBM/cloud-pak/tree/master/repo/cpd/3.5/assembly/watson-language-translator/x86_64/1.2

https://www.ibm.com/support/knowledgecenter/SSQNUZ_3.5.0/svc-lang/language-translator-override.html


```
cat <<EOF > "${PWD}/lt-install-override.yaml"
global:
  pullPolicy: Always
  zenControlPlaneNamespace: "zen"
gateway:
  addonService:
    zenNamespace: 'zen'
translationModels:
  en-fr:
    enabled: true
EOF
```

5.  Label namespace

```
oc label --overwrite namespace zen ns=zen
```

6.  Run adm task.  Edit below for your deployment and paste.  Assumes internal registry and kubeadmin user / password.  

```
NAMESPACE=zen
OPENSHIFT_USERNAME=kubeadmin 
OPENSHIFT_REGISTRY_PULL=image-registry.openshift-image-registry.svc:5000

./cpd-cli adm --repo ./repo.yaml --assembly watson-language-translator --arch x86_64 --namespace $NAMESPACE --accept-all-licenses --apply
```

7.  Install edp-operator (assumes cluster has access to internet to pull / push images)

```
NAMESPACE=zen
OPENSHIFT_USERNAME=kubeadmin 
OPENSHIFT_REGISTRY_PULL=image-registry.openshift-image-registry.svc:5000

./cpd-cli install  --repo repo.yaml --assembly edb-operator --optional-modules edb-pg-base:x86_64 --namespace $NAMESPACE  --transfer-image-to $(oc registry info)/$NAMESPACE --cluster-pull-prefix $OPENSHIFT_REGISTRY_PULL/$NAMESPACE --target-registry-username $OPENSHIFT_USERNAME --target-registry-password=$(oc whoami -t) --latest-dependency  --insecure-skip-tls-verify  --accept-all-licenses 
```

8.  Install minio operator

```
NAMESPACE=zen
OPENSHIFT_USERNAME=kubeadmin 
OPENSHIFT_REGISTRY_PULL=image-registry.openshift-image-registry.svc:5000

./cpd-cli install  --repo repo.yaml --assembly ibm-minio-operator --namespace $NAMESPACE  --transfer-image-to $(oc registry info)/$NAMESPACE --cluster-pull-prefix $OPENSHIFT_REGISTRY_PULL/$NAMESPACE --target-registry-username $OPENSHIFT_USERNAME --target-registry-password=$(oc whoami -t) --latest-dependency  --insecure-skip-tls-verify  --accept-all-licenses
```


9.  Install LTS assembly

```
NAMESPACE=zen
OPENSHIFT_USERNAME=kubeadmin 
OPENSHIFT_REGISTRY_PULL=image-registry.openshift-image-registry.svc:5000

./cpd-cli install  --repo repo.yaml --assembly watson-language-translator --instance lts --namespace $NAMESPACE --storageclass portworx-db-gp2-sc  --version 1.2 --transfer-image-to $(oc registry info)/$NAMESPACE --cluster-pull-prefix $OPENSHIFT_REGISTRY_PULL/$NAMESPACE --target-registry-username $OPENSHIFT_USERNAME --target-registry-password=$(oc whoami -t) --optional-modules watson-language-pak-1 --latest-dependency  --insecure-skip-tls-verify  --accept-all-licenses --override lt-install-override.yaml
```


**To Watch install**

Open up a second terminal window and wait for all pods to become ready.  Control C to exit watch

```
ssh root@ip address
watch oc get pods -l release=ibm-lt---lts
```


**To check for pods not Running or Running but not ready**
```
oc get pods --all-namespaces | grep -Ev '1/1|2/2|3/3|4/4|5/5|6/6|7/7|8/8' | grep -v 'Completed'
```

_________________________________________________________

## STEP #4 Verify   


1.  Check the status of the assembly and modules - LTS showed failed even though it installed without error
```
./cpd-cli status --namespace $NAMESPACE
```


2.  Run Test chart

```
oc rsh $(oc get pods -l name=cpd-install-operator -o name)
helm test ibm-lt---lts --tls
```


**Note:  To delete pods from prior test chart execution, run with  --cleanup flag then you can run again with or without flag.**
```
oc rsh $(oc get pods -l name=cpd-install-operator -o name)
helm test helm test ibm-lt---lts --tls --cleanup
```

_________________________________________________________

## STEP #5 Provision Instance   


1.  Login to Cloud Pak Cluster:  https://zen-cpd-zen.apps.$CLUSTERNAME/zen/#/addons

`oc get route zen-cpd | awk '{print $2}'`

**credentials:  admin / pw: password**

* Select Watson Service
* Select Provision Instance
* Select Create Instance and give it a name 

_________________________________________________________

## STEP #6 Test via API     https://cloud.ibm.com/docs/language-translator-data


You will be prompted for the service Token & API endpoint.  To find: 
* Login to Cloud Pak Cluster:  https://zen-cpd-zen.apps.$CP4DCLUSTERNAME/zen/#/myInstances

**credentials:  admin / pw: password**
* Click on Instance name 
* Copy / Paste the token and api end point from the Access information section, then copy / paste the lines into a terminal window when prompted.

export TOKEN=
export API_URL=

Paste below to test translation from english to french
```
curl -k -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" -X POST -d '{"text": ["Hello, world.", "How are you?"], "model_id":"en-fr"}' "$API_URL/v3/translate?version=2018-05-01"
```

Paste below to identify language
```
curl -k -X POST --header "Authorization: Bearer $TOKEN" --header "Content-Type: text/plain" --data "Language Translator identifies text " "$API_URL/v3/identify?version=2018-05-01"
```

_________________________________________________________

### How to Scale service
_________________________________________________________

LTS does not support scaling with cpd-cli, must review deployments and use oc commands to scale.


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

Uninstall Service

```
./cpd-cli uninstall --assembly  watson-language-translator --instance lts  -n zen

oc delete job,deploy,replicaset,pod,statefulset,configmap,secret,ingress,service,serviceaccount,role,rolebinding,persistentvolumeclaim,poddisruptionbudget,horizontalpodautoscaler,networkpolicies,cronjob -l release=ibm-lt---lts

oc delete cm cpdinstall-a-watson-language-translator---lts-amd64  
oc delete cm cpdinstall-a-watson-language-translator-amd64
for i in `oc get pvc | grep ibm-lt | awk '{ print $1 }'`; do oc delete pvc $i ; done
sleep 10
for i in `oc get pv | grep ibm-lt | awk '{ print $1 }'`; do oc delete pv $i ; done
```

Uninstall EDB
```
./cpd-cli uninstall --assembly edb-operator -n zen
```

Uninstall Minio
```
./cpd-cli uninstall --assembly ibm-minio-operator -n zen
```

Uninstall Service & all dependancies 
```
./cpd-cli uninstall --assembly  watson-language-translator --instance lts  -n zen --include-dependent-assemblies 
oc delete job,deploy,replicaset,pod,statefulset,configmap,secret,ingress,service,serviceaccount,role,rolebinding,persistentvolumeclaim,poddisruptionbudget,horizontalpodautoscaler,networkpolicies,cronjob -l release=ibm-lt---lts

oc delete cm cpdinstall-a-watson-language-translator---lts-amd64  
oc delete cm cpdinstall-a-watson-language-translator-amd64
for i in `oc get pvc | grep ibm-lt | awk '{ print $1 }'`; do oc delete pvc $i ; done
sleep 10
for i in `oc get pv | grep ibm-lt | awk '{ print $1 }'`; do oc delete pv $i ; done
```

