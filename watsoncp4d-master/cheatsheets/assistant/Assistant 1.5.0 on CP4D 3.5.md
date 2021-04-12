
# Assistant 1.5.0 on CP4D 3.5 (OpenShift 4.5)


## Reference 

* Dev Docs:  https://www-03preprod.ibm.com/support/knowledgecenter/SSQNUZ_3.5.0_test/svc-assistant/assistant-svc-override.html
* Source:  https://github.ibm.com/watson-deploy-configs/conversation/blob/wa-icp-1.5.0/templates/icp.d/stable/ibm-watson-assistant-prod-bundle/charts/ibm-watson-assistant-prod/README.md
* Documentation:  https://www.ibm.com/support/producthub/icpdata/docs/content/SSQNUZ_latest/svc-assistant/assistant-install.html
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
This cheatsheet can be used to do a vanilla installation of Watson Assistant 1.5.0 on CP4D 3.5 on Openshift 4.5 with portworx Storage 2.5.5.  

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

## STEP #3 - Install event-service from common services if you need analytics in WA.  Do not install all of them unless you have ample compute (46 cores / 44G Ram extra)

If you are not using analytics in WA, you can skip this section


1.  Ensure that the vm.max_map_count setting is at least 262144 on all nodes. Run the following command to check:

```
for node in $(oc get node -o=jsonpath={.items[*].metadata.name}); do echo -n "${node} " ; ssh core@${node} sudo sysctl -a | grep vm.max_map_count ; done
```

If the vm.max_map_count setting is not at least 262144, complete these steps to set the value to 262144:

Paste below to create / apply tuned-cs-es.yaml
```
cat <<EOF > "${PWD}/tuned-cs-es.yaml"
apiVersion: tuned.openshift.io/v1
kind: Tuned
metadata:
 name: common-services-es
 namespace: openshift-cluster-node-tuning-operator
spec:
 profile:
 - data: |
     [sysctl]
     vm.max_map_count=262144
   name: common-services-es
 recommend:
 - priority: 10
   profile: common-services-es
EOF
oc apply -f tuned-cs-es.yaml
```

2.  Paste below to create operatnd
```
cat <<EOF > "${PWD}/opencloudio-source.yaml"
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: opencloud-operators
  namespace: openshift-marketplace
spec:
  displayName: IBMCS Operators
  publisher: IBM
  sourceType: grpc
  image: docker.io/ibmcom/ibm-common-service-catalog:latest
  updateStrategy:
    registryPoll:
      interval: 45m
EOF
sleep 2
oc apply -f opencloudio-source.yaml
sleep 2
oc -n openshift-marketplace get catalogsource opencloud-operators
```

3.  Paste below to create operator:

```
cat <<EOF > "${PWD}/def.yaml"
apiVersion: v1
kind: Namespace
metadata:
  name: common-service

---
apiVersion: operators.coreos.com/v1alpha2
kind: OperatorGroup
metadata:
  name: operatorgroup
  namespace: common-service
spec:
  targetNamespaces:
  - common-service

---
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: ibm-common-service-operator
  namespace: common-service
spec:
  channel: stable-v1 # dev channel is for development purpose only
  installPlanApproval: Automatic
  name: ibm-common-service-operator
  source: opencloud-operators
  sourceNamespace: openshift-marketplace
EOF
sleep 2
oc apply -f def.yaml
sleep 20
oc get csv -n common-service
oc get crd | grep operandrequest
```

_________________________________________________________

## STEP #4 - Service Install Procedures    
_________________________________________________________

1.  Verify Portworx Storage class for Assistant.  If missing create.
```
oc get storageclass |grep portworx-watson-assistant-sc
```

2.  Switch to CPD Namespace
```
oc project $NAMESPACE
```

3.  Prepare repo.yaml for Service.   Add your apikey to the snippet below and paste to create.
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

4.  Prepare override yaml for Service.   

Modify snippet below for your deployment

* Set deployment to 'small' for Development or 'medium' for Production
* Set image.pullSecret to secret name if using external registry
* Set features & languages as desired 
* Paste contents below to create file

```
cat <<EOF > "${PWD}/wa-install-override.yaml"
zenServiceInstanceId: 1
watsonAssistant:
  # imagePullSecrets for Assistant
  cluster:
    imagePullSecrets: []
    dockerRegistryPrefix: ""
  # version of Assistant to deploy
  version: 1.5.0
  # how big do we want the cluster to be
  # - options:
  #   'small', 'medium', 'large'
  size: "small"
  # List of languages enabled for this instance
  languages:
  - en
  ##############
  ## Features ##
  ##############
  features:
    # options for the analytics features of Watson Assistant
    analytics:
      # whether to enable analytics or not
      enabled: true
    # options for the recommends features of Watson Assistant
    recommends:
      # whether to enable recommends or not
      enabled: true
    tooling:
      # whether to enable tooling (UI) or not
      enabled: true
  backup:
    onlineQuiesce: false
    offlineQuiesce: false
  ##############################
  ## Datastore Configurations ##
  ##############################
  etcd:
    storageClassName: ""
    storageSize: "1Gi"
  kafka:
    storageClassName: ""
    storageSize: "1Gi"
    zookeeper:
      storageSize: "1Gi"
  minio:
    storageClassName: ""
    storageSize: "20Gi"
  postgres:
    storageClassName: ""
    storageSize: "5Gi"
    backupStorageClassName: ""
  datastores:
    elasticSearch:
      analytics:
        type: cloudpakopenElasticSearch
        cloudpakopenElasticSearch:
          storageClassName: ""
          storageSize: "" # Default size is 40Gi
      store:
        type: cloudpakopenElasticSearch
        cloudpakopenElasticSearch:
          storageClassName: ""
          storageSize: "" # Default size is 10Gi
  analytics:
    crossInstanceQueryScope:
      enabled: "false"
  appConfigOverrides: |-4
    # Preserve this line and the the |-4 specifier above, also note that contraintuitively all the entries MUST BE INDENTED by 6 initial spaces.
    # The above is required, becase the cpd-cli have very,very limited templating support.
    #   We have to use this "specified as multiline string" work-arround/hack to be able to provide arbitrary override data.
    # Also note that you are not allowed to use " or ' to wrap the values (cpd cpd-cli converts these entries and the installation would break)
    # Sample content
    #container_images:
    #  store:
    #    tag: 20201028-111825-43892a
EOF
```

5.  Run adm task.  Edit below for your deployment and paste.  Assumes internal registry and kubeadmin user / password.  

```
NAMESPACE=
OPENSHIFT_USERNAME=kubeadmin 
OPENSHIFT_REGISTRY_PULL=image-registry.openshift-image-registry.svc:5000

./cpd-cli adm --repo ./repo.yaml --assembly watson-assistant --arch x86_64 --namespace $NAMESPACE --accept-all-licenses --apply
```


6.  Install edp-operator (assumes cluster has access to internet to pull / push images)


```
NAMESPACE=
OPENSHIFT_USERNAME=kubeadmin 
OPENSHIFT_REGISTRY_PULL=image-registry.openshift-image-registry.svc:5000

./cpd-cli install  --repo repo.yaml --assembly edb-operator --optional-modules edb-pg-base:x86_64 --namespace $NAMESPACE  --transfer-image-to $(oc registry info)/$NAMESPACE --cluster-pull-prefix $OPENSHIFT_REGISTRY_PULL/$NAMESPACE --target-registry-username $OPENSHIFT_USERNAME --target-registry-password=$(oc whoami -t) --latest-dependency  --insecure-skip-tls-verify  --accept-all-licenses 
```

7.  Install WA operator (assumes cluster has access to internet to pull / push images)

```
NAMESPACE=
OPENSHIFT_USERNAME=kubeadmin 
OPENSHIFT_REGISTRY_PULL=image-registry.openshift-image-registry.svc:5000

./cpd-cli install  --repo repo.yaml --assembly watson-assistant-operator --optional-modules watson-assistant-operand-ibm-events-operator:x86_64 --namespace $NAMESPACE --storageclass portworx-watson-assistant-sc --transfer-image-to $(oc registry info)/$NAMESPACE --cluster-pull-prefix $OPENSHIFT_REGISTRY_PULL/$NAMESPACE --target-registry-username $OPENSHIFT_USERNAME --target-registry-password=$(oc whoami -t) --latest-dependency  --insecure-skip-tls-verify  --accept-all-licenses --override wa-install-override.yaml
```

Verify you see edb-postgresql image as well as WA images before installing assembly

```
oc get images | grep image-registry.openshift-image-registry.svc:5000/zen
oc get images | grep image-registry.openshift-image-registry.svc:5000/zen | grep postgres
oc get images | grep image-registry.openshift-image-registry.svc:5000/zen | grep assistant
```


8.  Install WA assembly

```
NAMESPACE=
OPENSHIFT_USERNAME=kubeadmin 
OPENSHIFT_REGISTRY_PULL=image-registry.openshift-image-registry.svc:5000

./cpd-cli install  --repo repo.yaml --assembly watson-assistant --instance wa001 --namespace $NAMESPACE --storageclass portworx-watson-assistant-sc --transfer-image-to $(oc registry info)/$NAMESPACE --cluster-pull-prefix $OPENSHIFT_REGISTRY_PULL/$NAMESPACE --target-registry-username $OPENSHIFT_USERNAME --target-registry-password=$(oc whoami -t) --latest-dependency  --insecure-skip-tls-verify  --accept-all-licenses --override wa-install-override.yaml
```

Watson Assistant will now be installed.   The process takes about 30 mins

**To Watch install**

Open up a second terminal window and wait for all pods to become ready.  Control C to exit watch

```
ssh root@ip address
watch oc get pods -l icpdsupport/addOnId=assistant
```


**To check for pods not Running or Running but not ready**
```
oc get pods --all-namespaces | grep -Ev '1/1|2/2|3/3|4/4|5/5|6/6|7/7|8/8' | grep -v 'Completed'
```

_________________________________________________________

## STEP #5 Verify   


1.  Check the status of the assembly and modules
```
./cpd-cli status --namespace $NAMESPACE
```

2.  Create DVT to test Service:  https://cloud.ibm.com/docs/assistant-data?topic=assistant-data-install-150#install-150-test

Modify snippet below for your deployment

* Replace 'watson-assistant---wa001' with your instance name 'oc get wa' 
* Update dockerRegistryPrefix if not internal registry/zen (Namespace)
* Paste contents below to create file


```
cat <<EOF > "${PWD}/wa-test-override.yaml"
apiVersion: com.ibm.watson.watson-assistant/v1
kind: WatsonAssistantDvt
metadata:
  name: watson-assistant---wa001
  annotations:
    oppy.ibm.com/disable-rollback: "true"
spec:
  # Additional labels to pass down to all objects created by the operator
  labels:
    "app.kubernetes.io/instance": "watson-assistant---wa001"
  version: 1.5.0
  # The name of the WA instance to target with this DVT run
  assistantInstanceName: watson-assistant---wa001
  # The cucumber test tags to execute
  testTags: "@accuracy,@dialogErrors,@dialogs,@dialogV1,@dialogV1errors,@embedsearch,@entities,@folders,@fuzzy,@generic,@intents,@openentities,@patterns,@prebuilt,@search,@slots,@spellcheck,@spellcheckfr,@v2assistants,@v2authorskill,@v2authorwksp,@v2healthcheck,@v2skillref,@v2snapshots,@workspaces"
  # Information specific to this cluster
  cluster:
    # :type: Cluster environment type
    # - options: 'public', 'dedicated', 'premium', 'private'
    type: "private"
    # :image_pull_secrets: pull secret names
    imagePullSecrets: []
    # TODO: These are for WA dev
    # :docker_registry_prefix: (private only) Docker registry, including namespace, to get images from
    dockerRegistryPrefix: image-registry.openshift-image-registry.svc:5000/zen

EOF
```
```
sleep 2
oc apply -f wa-test-override.yaml
sleep 5
oc get dvt
oc get pods | grep dvt
```

DVT takes about an hour to run, then check log `oc get pods | grep dvt`

example:
oc logs watson-assistant---wa001-dvt-job-66ns9

or to watch realtime:
oc logs watson-assistant---wa001-dvt-job-vht46 -f


To see values used during install - replace with your instance name
` oc get wa watson-assistant---wa001 -o yaml`


_________________________________________________________

## STEP #6 Provision Instance   


1.  Login to Cloud Pak Cluster:  https://zen-cpd-zen.apps.$CLUSTERNAME/zen/#/addons

```
oc get route zen-cpd | awk '{print $2}'
```

**credentials:  admin / pw: password**

* Select Watson Service
* Select Provision Instance
* Select Create Instance and give it a name 
* Open Watson Assistant Tooling & Create a skill
* Switch to Skills
* Create Skill, Dialog Skill, Next
* Select to Use Sample Skill
* Click the Sample Skill and it will open 
* Click Try it panel and make sure it understands you - type hello (after training completes)
* Go to Assistants (Skills, Assistants)
* Create Assistant, Give it a name, Click Create Assistant
* Click Add Dialog Skill, Add existing Skill (Pick customer care sample skill created previously)
* Click on Preview Link and test skill

**Note: If you have trouble with the tooling, try incognito mode**


_________________________________________________________

## STEP #7 Test via API   

Download files needed for WA test from:  https://github.ibm.com/jennifer-wales/watsoncp4d/blob/master/cheatsheets/assistant/assistant-testing
```
chmod +x wa-api-test.sh
./wa-api-test.sh
```
You will be prompted for the service Token & API endpoint.  To find: 
* Login to Cloud Pak Cluster:  https://zen-cpd-zen.apps.$CP4DCLUSTERNAME/zen/#/myInstances

**credentials:  admin / pw: password**
* Click on Instance name 
* Copy / Paste the token and api end point from the Access information section, then copy / paste the lines into a terminal window when prompted.

_________________________________________________________

### How to modify deployment
_________________________________________________________

To change deployment, modify Service operator & save.  Installation will automatically change as needed.

* Add / remove languages:  https://www.ibm.com/support/producthub/icpdata/docs/content/SSQNUZ_latest/svc-assistant/assistant-svc-override.html
* Change from Deployment type (small, medium, large)
* Enable / disable analytics, etc

```
oc edit {servicename} {instancename}
example:  `oc edit wa watson-assistant---wa001`


oc edit wa `oc get wa --no-headers |awk '{ print $1}'`
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

Uninstall Service

```
./cpd-cli uninstall --assembly  watson-assistant --instance wa001 -n zen
oc delete wa watson-assistant---wa001
for i in `oc get pvc | grep assistant | awk '{ print $1 }'`; do oc delete pvc $i ; done
sleep 10
for i in `oc get pv | grep assistant | awk '{ print $1 }'`; do oc delete pv $i ; done
```

Uninstall Operator
```
./cpd-cli uninstall --assembly  watson-assistant-operator -n zen 
```

Uninstall EDB
```
./cpd-cli uninstall --assembly edb-operator -n zen
```

Uninstall Service & all dependancies (--dry-run to see what will be removed)
```
./cpd-cli uninstall --assembly  watson-assistant --instance wa001 -n zen --include-dependent-assemblies
```


