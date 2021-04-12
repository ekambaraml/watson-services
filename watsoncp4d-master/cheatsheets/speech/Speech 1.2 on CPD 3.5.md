Speech 1.2 on CPD 3.5.md

Speech 1.2.0 on CP4D 3.5 (OpenShift 4.5) Draft 2 includes fix for minioclient image


## Reference 


* Documentation:  https://www.ibm.com/support/producthub/icpdata/docs/content/SSQNUZ_latest/svc-speech/stt-svc-install-adm.html
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
This cheatsheet can be used to do a vanilla installation of Watson Speech 1.2.0 on CP4D 3.5 on Openshift 4.5 with portworx Storage 2.5.5.  
_________________________________________________________

## Login into Openshift 


Set variables for your deployment and Login into Openshift from the node you will be installing from (infrastructure node or node with oc cli installed)

```
ssh root@ip address
export CP4DCLUSTERNAME=yourclustername-inf.fyre.ibm.com
export NAMESPACE=zen
oc login -u kubeadmin -p `cat ~/auth/kubeadmin-password`
oc login --token=$(oc whoami -t ) --server=https://api.$CP4DCLUSTERNAME:6443
```

_________________________________________________________

## Service Install Procedures    
_________________________________________________________

1.  Create Portworx Storage class for speech by pasting text below 

```
cat <<EOF > "${PWD}/speech-portworx.yaml"

apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: portworx-sc
parameters:
  block_size: 64k
  io_profile: db
  priority_io: high
  repl: "3"
  snap_interval: "0"
provisioner: kubernetes.io/portworx-volume
reclaimPolicy: Delete
volumeBindingMode: Immediate
EOF
sleep 5
oc create -f speech-portworx.yaml
```

2.  Prepare repo.yaml for Service.   Add your apikey to the snippet below and paste to create.

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

3.  Create Minio Secrets by pasting below
```
cat > minio.yaml << EOF
apiVersion: v1
kind: Secret
metadata:
  name: minio
type: Opaque
data:
  accesskey: YWRtaW4=
  secretkey: YWRtaW4xMjM0
EOF
sleep 5
oc apply -f minio.yaml
```

4.  Create Postgres Credentials by pasting below
```
cat > postgres.yaml << EOF
apiVersion: v1
data:
  PG_PASSWORD: ZGxkQ001WHJNOU1sMTZobUo1Ym5qUEtGcUtzPQ==
  PG_REPLICATION_PASSWORD: eTRvRHBlMGIzNCt5dm50dVFtU1BsTVcyZkRzPQ==
  PG_REPLICATION_USER: cmVwbGljYXRpb24=
  PG_USER: ZW50ZXJwcmlzZWRi
  USING_SECRET: dHJ1ZQ==
kind: Secret
metadata:
  name: user-provided-postgressql
type: Opaque
EOF
sleep 5
oc apply -f postgres.yaml
```
5.  Label your cpd namespace.  Modify below if not zen
`oc label --overwrite namespace zen ns=zen`

6.  Grab the default-dockercfg secret needed for speech-override.yaml 
```
oc get secrets | grep default-dockercfg
```

7.  Prepare override yaml for Service.   

Modify snippet below for your deployment

* Set deployment to Development or Production
* Set dockerRegistryPrefix to match your cpd namespace
* Set image.pullSecret to secret name from above, ex:  pullSecret: "default-dockercfg-rgmsl"
* Set features & languages as desired 
* Paste contents below to create file

```
cat <<EOF > "${PWD}/speech-install-override.yaml"
tags:
  sttAsync: true
  sttCustomization: true
  ttsCustomization: true
  sttRuntime: true
  ttsRuntime: true

affinity: {}

#NEW FIX
sttRuntime:
  images:
    miniomc:
      tag:
        1.0.5
sttAMPatcher:
  images:
    miniomc:
      tag:
        1.0.5
ttsRuntime:
  images:
    miniomc:
      tag:
        1.0.5

global:
  dockerRegistryPrefix: "image-registry.openshift-image-registry.svc:5000/{yournamespace}"
  image:
    pullSecret: "{yourdockersecret}-dockercfg-kv4zm"
    pullPolicy: "IfNotPresent"

  datastores:

    minio:
      tlsEnabled: true
      serviceAccountName: "ibm-minio-operator"

      #Images
      images:
        certgen:
          name: opencontent-icp-cert-gen-1
          tag: 1.1.9
        minio:
          name: "opencontent-minio"
          tag: 1.1.5
        minioClient:
          name: "opencontent-minio-client"
          tag: 1.0.5

      #Sizing
      deploymentType: Development #Development or Production

      # 4 <= Replicas <= 32 
      replicasForDev: 4
      replicasForProd: 4

      memoryLimit: 2048Mi
      cpuRequest: 250m
      cpuLimit: 500m
      memoryRequest: 256Mi

      #Storage
      storageClassName: "portworx-sc"

      #Secrets
      authSecretName: minio
      tlsSecretName: "{{ .Release.Name }}-ibm-datastore-tls"

    rabbitMQ:
      tlsEnabled: true
      replicas: 3

      #Images
      images:
        config:
          name: opencontent-rabbitmq-config-copy
          tag: 1.1.5
        rabbitmq:
          name: opencontent-rabbitmq-3
          tag: 1.1.8

      #Sizing
      cpuRequest: 200m
      cpuLimit: 200m
      memoryRequest: 256Mi
      memoryLimit: 256Mi

      #Storage
      storageClassName: "portworx-sc"
      pvEnabled: true
      pvSize: 5Gi
      useDynamicProvisioning: true

      #Secrets
      tlsSecretName: "{{ .Release.Name }}-ibm-datastore-tls"
      authSecretName: "{{ .Release.Name }}-ibm-rabbitmq-auth-secret"

    postgressql: 
      tlsEnabled: true
      serviceAccount: "edb-operator"

      #Images
      images:
        stolon:
          name: "edb-stolon"
          tag: "v1-ubi8-amd64"
        postgres:
          name: "edb-postgresql-12"
          tag: "ubi8-amd64"

      #Sizing configuration
      replicas: 3
      databaseMemoryLimit: "5Gi"
      databaseMemoryRequest: "1Gi"
      databaseCPULimit: "1000m"
      databaseCPU: "50m"
      databaseStorageRequest: "5Gi"

      #Storage configuration
      databaseStorageClass: "portworx-sc"
      databaseArchiveStorageClass: "portworx-sc"
      databaseWalStorageClass: "portworx-sc"
      databasePort: 5432

      #Secrets
      authSecretName: "user-provided-postgressql"
      tlsSecretName: "{{ .Release.Name }}-ibm-datastore-tls"

  sttModels:
    enUsBroadbandModel:
      enabled: true
      catalogName: en-US_BroadbandModel
    enUsNarrowbandModel:
      enabled: true
      catalogName: en-US_NarrowbandModel
    enUsShortFormNarrowbandModel:
      enabled: true
      catalogName: en-US_ShortForm_NarrowbandModel

  ttsVoices:
    enUSMichaelV3Voice:
      enabled: true
      catalogName: en-US_MichaelV3Voice
    enUSLisaV3Voice:
      enabled: true
      catalogName: en-US_LisaV3Voice
    enUSAllisonV3Voice:
      enabled: true
      catalogName: en-US_AllisonV3Voice
EOF
```

8.  Run adm task.  Edit below for your deployment and paste.  Assumes internal registry and kubeadmin user / password.  

```
NAMESPACE=zen
OPENSHIFT_USERNAME=kubeadmin 
OPENSHIFT_REGISTRY_PULL=image-registry.openshift-image-registry.svc:5000

./cpd-cli adm --repo ./repo.yaml --assembly watson-speech --arch x86_64 --namespace $NAMESPACE --accept-all-licenses --apply
```


8.  Install edp-operator (assumes cluster has access to internet to pull / push images)


```
NAMESPACE=zen
OPENSHIFT_USERNAME=kubeadmin 
OPENSHIFT_REGISTRY_PULL=image-registry.openshift-image-registry.svc:5000

./cpd-cli install  --repo repo.yaml --assembly edb-operator --optional-modules edb-pg-base:x86_64 --namespace $NAMESPACE  --transfer-image-to $(oc registry info)/$NAMESPACE --cluster-pull-prefix $OPENSHIFT_REGISTRY_PULL/$NAMESPACE --target-registry-username $OPENSHIFT_USERNAME --target-registry-password=$(oc whoami -t) --latest-dependency  --insecure-skip-tls-verify  --accept-all-licenses 
```


9.  Install Speech assembly

```
NAMESPACE=zen
OPENSHIFT_USERNAME=kubeadmin 
OPENSHIFT_REGISTRY_PULL=image-registry.openshift-image-registry.svc:5000

./cpd-cli install  --repo repo.yaml --assembly watson-speech --instance speech1 --namespace $NAMESPACE --storageclass portworx-sc --transfer-image-to $(oc registry info)/$NAMESPACE --cluster-pull-prefix $OPENSHIFT_REGISTRY_PULL/$NAMESPACE --target-registry-username $OPENSHIFT_USERNAME --target-registry-password=$(oc whoami -t) --latest-dependency  --insecure-skip-tls-verify  --accept-all-licenses --override speech-install-override.yaml
```

Open up a second terminal window and wait for install to start (after image load)
Pods will start to load, a few will start with errors due to minio client image problem. 

```
ssh root@ip address
watch oc get pods -l release=ibm-spch---speech1
```

**To check for pods not Running or Running but not ready**
```
oc get pods --all-namespaces | grep -Ev '1/1|2/2|3/3|4/4|5/5|6/6|7/7|8/8' | grep -v 'Completed'
```

Scale up Postgres pods after patch
```
oc scale deployment ibm-spch---speech1-speech-to-text-postgres-proxy --replicas=3
oc scale deployment ibm-spch---speech1-speech-to-text-postgres-sentinel --replicas=3
```

_________________________________________________________

## STEP #5 Verify   


1.  Check the status of the assembly and modules
```
./cpd-linux status --namespace zen
```
_________________________________________________________

## STEP #6 Provision Instance   


1.  Login to Cloud Pak Cluster:  https://cp4d-namespace-cpd-cp4d-namespace.apps.cp4d-clustername/cp4d-namespace/#/addons
**credentials:  admin / pw: password**

* Select Create a Service Instance
* Select Watson Service Speech to Text or Text to Speech
* Select New instance
* Provide an Instance name and select Create
* Repeat if you installed both STT and TTS 

_________________________________________________________

## STT API Commands

Download files needed for speech test from:  https://github.ibm.com/jennifer-wales/watsoncp4d/tree/master/cheatsheets/speech/speech-testing
```
chmod +x speech-api-test.sh
./speech-api-test.sh
```
You will be prompted for the service Token & API endpoint.  To find: 
* Login to Cloud Pak Cluster:  https://zen-cpd-zen.apps.$CP4DCLUSTERNAME/zen/#/myInstances

**credentials:  admin / pw: password**
* Click on Instance name 
* Copy / Paste the token and api end point from the Access information section, then copy / paste the lines into a terminal window when prompted.


_________________________________________________________

### How to Scale service
_________________________________________________________

https://cloud.ibm.com/docs/speech-to-text-data?topic=speech-to-text-data-speech-scaling-12

By Default, Speech will deploy in a small (development) configuration without redundancy.

To scale to a development configuration, use command below.  To Scale back to HA config, use --config medium.

```
./cpd-cli scale --assembly watson-speech --instance speech1 -n zen --config medium
sleep 10
watch oc get pods -l release=ibm-spch---speech1
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
./cpd-cli uninstall --assembly  watson-speech --instance speech1 -n zen
for i in `oc get pvc | grep ibm-spch | awk '{ print $1 }'`; do oc delete pvc $i ; done
sleep 10
for i in `oc get pv | grep ibm-spch | awk '{ print $1 }'`; do oc delete pv $i ; done
```

There are multiple labels with this release of speech.  Make sure nothing is left over before trying a new install:

release=ibm-spch---speech1-speech-to-text-rabbitmq
release=ibm-spch---speech1-speech-to-text-minio
release=ibm-spch---speech1

To find:
```
oc get job,deploy,rs,pod,statefulset,configmap,secret,ingress,service,serviceaccount,role,rolebinding,pvc,poddisruptionbudget,hpa | grep ibm-spch
```

To Delete:
```
oc delete job,deploy,rs,pod,statefulset,configmap,secret,ingress,service,serviceaccount,role,rolebinding,pvc,poddisruptionbudget,hpa | grep ibm-spch
```


Uninstall EDB
```
./cpd-cli uninstall --assembly edb-operator -n zen
```

Uninstall Service & all dependancies (--dry-run to see what will be removed)
```
./cpd-cli uninstall --assembly  watson-speech --instance speech1 -n zen --include-dependent-assemblies
```


_________________________________________________________

### How to Delete Deployment - Advanced
_________________________________________________________

#Via Helm

1.  Remote into the operator pod
```
oc get pods | grep operator
oc exec -it {cpd-install-operator-pod} /bin/bash
```
2.  Delete Deployment 
```
helm ls --tls 	#to find instance name
helm delete --tls --no-hooks --purge {instance}
```

3.  Post uninstall cleanup
```
kubectl delete job,deploy,rs,pod,statefulset,configmap,secret,ingress,service,serviceaccount,role,rolebinding,pvc,poddisruptionbudget,hpa | grep ibm-spch --namespace=cp4d-namespace
```

Fix for configmap 'stolon-cluster-ibm-spch---s001-speech-to-text-postgres' not deleting

```
kubectl patch configmap stolon-cluster-ibm-spch---s001-speech-to-text-postgres -p '{"metadata":{"finalizers":[]}}' --type=merge
```

_________________________________________________________

### How to Add language models after installation. Doesn't work inside of operator pod - need new instructions. 
_________________________________________________________

If you need support for additional languages you can add language models using the following commands:  

1.  Remote into operator pod where helm is
```
oc exec -it cpd-install-operator-58665b4979-q8dd8 bin/bash
```

2.  Change into tmp/ directory (you have write permissions here)
`cd /tmp`

3.  Extract the values to a yaml file
```
helm get values ibm-spch---speech1 --tls >newlangs.yaml
```

4.  Edit newlangs.yaml to enable new model(s) 
`vi /tmp/newlangs.yaml`

5.  Apply change
```
helm upgrade ibm-spch---speech1 /mnt/installer/modules/watson-speech-base/x86_64/1.2/ibm-watson-speech-prod-1.2.1.tgz -f ~/tmp/newlangs.yaml --tls
```




