
# Speech 1.1.4 on CP4D 3.0 (OpenShift 4.3)


## Reference 

* Documentation:  https://www.ibm.com/support/knowledgecenter/SSQNUZ_3.0.1/cpd/svc/watson/speech-to-text-adm-cmd.html
* Readme:  
* Watson Install Requirements:  https://apps.na.collabserv.com/wikis/home?lang=en-us#!/wiki/Wd855b33ea663_4b57_a7c7_f5e8e37c2716/page/Watson%20Install%20Prereqs%20(Q4%202019%20Release)
* Release info here: https://apps.na.collabserv.com/wikis/home?lang=en-us#!/wiki/Wd855b33ea663_4b57_a7c7_f5e8e37c2716/page/Watson%20on%20Cloud%20Pak%20Releases

URLs
* OpenShift Admin URL:  https://console-openshift-console.apps.cp4d-clustername
* Cloud Pak Admin URL:  https://cp4d-namespace-cpd-cp4d-namespace.apps.cp4d-clustername
  

CLI Login 
```
oc login -u kubeadmin -p `cat ~/auth/kubeadmin-password` 
oc login --token=$(oc whoami -t ) --server=https://api.cp4d-clustername:6443
```

_________________________________________________________

##  START HERE
This cheatsheet can be used to do a vanilla installation of Watson Speech 1.1.4 on CP4D 3.0 on Openshift 4.3 with portworx Storage.    


Overview
* Do a Find and replace for the variables below to update the syntax of the commands below for your installation.   Do not use cheatsheet from box as the formatting of commands is lost. 
* Verify prereqs are met
* Follow instructions to install & verify

_________________________________________________________

## STEP #1 - Replace variables for your deploy  


* Find and replace `cp4d-clustername` with your clustername (fyre example: jwalesmay23.os.fyre.ibm.com)
* Find and replace your `cp4d-namespace` with your CP4D namespace or project name - ex: cp4d-namespace

_________________________________________________________

## STEP #2 - Login into Openshift 


Login into Openshift from the node you will be installing from (infrastructure node or node with oc cli installed)

ssh root@IP_address
```
oc login -u kubeadmin -p `cat ~/auth/kubeadmin-password`
oc login --token=$(oc whoami -t ) --server=https://api.cp4d-clustername:6443
```

_________________________________________________________

## STEP #3 Verify Prereqs using commands below 


### To use Script

SCRIPT NEEDS TO BE UPDATED FOR 4.3


### or via Commands
```
# Verify CPUs has AVX2 support (not sure required for wks)
cat /proc/cpuinfo | grep avx2

# Verify OpenShift version 4.3 
oc version

# Verify Cluster is using CRI-O Container Runtime as required for Portworx
oc get nodes -o wide

# Verify Default thread count is set to 8192 pids
for node in $(oc get node -o=jsonpath={.items[*].metadata.name}); do echo -n "${node} " ; ssh core@${node} cat /etc/crio/crio.conf | grep pids_limit ; done


# Verify Ample space in to extract tar file & load images - Not sure how much space is enough?
df -h

# Verify Portworx is operational (Optional if using VSphere Volumes)  

PX_POD=$(kubectl get pods -l name=portworx -n kube-system -o jsonpath='{.items[0].metadata.name}')
kubectl exec $PX_POD -n kube-system -- /opt/pwx/bin/pxctl status


# Verify Portworx is running on all worker nodes
oc get pods --all-namespaces -o wide | grep portworx-api

# Verify Portworx StorageClasses are available 
oc get storageclasses | grep portworx 

# If using VSphere Volumes instead of Portworx  
#   you will use the "thin" storageclass(which OCP install should have created if you had VSphere Volumes defined during OCP install)  
#   you will need to manually create a folder in the VMware vSphere Datacenter using the name of your cluster(OCP 4.3)  
#   See https://access.redhat.com/solutions/4563591 for details  
#  
#   verify thin storageclass was created  
oc get storageclasses | grep thin

# Verify Cloud Pak for Data 3 Control Plane installed 
oc get pods --all-namespaces | grep cp4d-namespace
```

Do not proceed to installation unless all prereqs are confirmed

_________________________________________________________

## STEP #4 Install Procedures  


This cheat pulls Watson Speech images from the entitled registry and loads to local registry.  


1.  Verify Portworx Storage class for Speech(if using Portworx).  If missing create.
```
oc get storageclass |grep portworx-sc
```


2.  Create Portworx Storage Class by pasting text below (Only if missing above and if using Portworx)

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
```

2a.  Apply Portworx Storage Class (Only if missing above)
```
oc create -f speech-portworx.yaml
```

3.  Check Project label needed for Watson Services.  If missing create.
```
oc get project cp4d-namespace --show-labels 
```

3a.  Label Namespace (only if missing)
```
oc label --overwrite namespace cp4d-namespace ns=cp4d-namespace
```

3b.  Confirm Project label needed for Watson Services is set to (ns=cp4d-namespace)
```
oc get project cp4d-namespace --show-labels 
```

4.  Switch to cp4d-namespace namespace
```
oc project cp4d-namespace
```

5.  Create Minio Secrets  
Paste below to create minio.yaml (uses default admin / admin1234 base 64 encoding)
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
```

5a.  Apply minio.yaml
```
kubectl apply -f minio.yaml
```
6.  Create Postgres Credentials (postgrescreds.yaml)  
Paste below to create postgrescreds.yaml encoding)
```
cat > postgrescreds.yaml << EOF
apiVersion: v1
data:
  pg_repl_password: cmVwbHVzZXI=
  pg_su_password: c3RvbG9u
kind: Secret
metadata:
  name: user-provided-postgressql
type: Opaque
EOF
```

6a.  Apply postgrescreds.yaml
```
kubectl apply -f postgrescreds.yaml
```

7.  Grab the default-dockercfg secret needed for speech-override.yaml 
```
oc get secrets | grep default-dockercfg
```


8.  Create speech-override.yaml

Modify speech-override.yaml below 

* Set image.pullSecret to secret name from above, ex:  pullSecret: "default-dockercfg-rgmsl"
* Set STT and TTS Customization on or off:
* Set sttCustomization: true or false
* Set ttsCustomization: true or false
* Set sttRuntime: true or false
* Set ttsRuntime: true or false
* Paste contents below to create file


### speech-override.yaml
```
cat <<EOF > "${PWD}/speech-override.yaml"
tags:
  sttAsync: true
  sttCustomization: true
  ttsCustomization: true
  sttRuntime: true
  ttsRuntime: true

affinity: {}

global:
  dockerRegistryPrefix: "image-registry.openshift-image-registry.svc:5000/cp4d-namespace"
  image:
    pullSecret: "default-dockercfg-xxxxx"
    pullPolicy: "IfNotPresent"

  datastores:
    minio:
      secretName: "minio"
    postgressql:
      auth:
        authSecretName: "user-provided-postgressql"

  sttModels:
    enUsBroadbandModel:
      enabled: true
    enUsNarrowbandModel:
      enabled: true
    enUsShortFormNarrowbandModel:
      enabled: true

  ttsVoices:
    enUSMichaelV3Voice:
      enabled: true
    enUSAllisonV3Voice:
      enabled: true
    enUSLisaV3Voice:
      enabled: true

EOF
```

9.  Create speech-repo.yaml 

* Modify speech-override.yaml below with apikey from passport advantage then paste contents below to create file

### speech-repo.yaml
	
```
cat <<EOF > "${PWD}/speech-repo.yaml"
registry:
  - url: cp.icr.io/cp/cpd
    username: "cp"
    apikey: <entitlement-key>
    namespace: ""
    name: base-registry
  - url: cp.icr.io
    username: "cp"
    apikey: <entitlement-key>
    namespace: "cp/watson-speech"
    name: spch-registry
fileservers:
  - url: https://raw.github.com/IBM/cloud-pak/master/repo/cpd3
  - url: https://raw.github.com/IBM/cloud-pak/master/repo/cpd3/assembly/watson-speech/
EOF

```


10.  Install Speech 1.1.4

**Note:**  If using STT batch, run instructions found in June-2020-ImagePatches.md, then continue with below steps  

Paste contents below to kickoff installation
If using VSphere Volumes instead of Portworx, add to cpd-linux command below --storageclass "thin"  

```
ASSEMBLY_VERSION=1.1.4
NAMESPACE=cp4d-namespace
OPENSHIFT_USERNAME=kubeadmin 
OPENSHIFT_REGISTRY_PULL=image-registry.openshift-image-registry.svc:5000
	
echo $ASSEMBLY_VERSION
echo $NAMESPACE
echo $OPENSHIFT_USERNAME
echo $OPENSHIFT_REGISTRY_PULL

./cpd-linux --repo speech-repo.yaml --assembly watson-speech --version $ASSEMBLY_VERSION --namespace $NAMESPACE --transfer-image-to $(oc registry info)/$NAMESPACE --target-registry-username $OPENSHIFT_USERNAME --target-registry-password=$(oc whoami -t) --insecure-skip-tls-verify --cluster-pull-prefix $OPENSHIFT_REGISTRY_PULL/$NAMESPACE -o speech-override.yaml --silent-install --accept-all-licenses


```

Watson Speech will now be installed.   First the images will be pulled from the entitled docker registry and pushed to the OpenShift registry.  Once loaded, the Watson install will begin.  The whole process should take at least 2 hours; 1 hour to load images and another hour to install Watson Speech.


After the image load has completed, you can watch the deployment spin up.  The majority of the install goes fast, with the recommends pod taking up to 45 minutes to create.  Be patient.

**To Watch install**

Open up a second terminal window and wait for all pods to become ready.  You are looking for all of the Jobs to be in `Successful=1`  Control C to exit watch

```
ssh root@IP_address
watch oc get job,pod --namespace cp4d-namespace -l release=watson-speech-base
```


**To check for pods not Running or Running but not ready**
```
oc get pods --all-namespaces | grep -Ev '1/1|2/2|3/3|4/4|5/5|6/6|7/7|8/8' | grep -v 'Completed'
```
**Patch to resolve failing TTS / STT runtime pods due to issue with model download**
https://github.ibm.com/jennifer-wales/watsoncp4d/blob/master/cheatsheets/speech/speech%20fix%20for%20failing%20runtime%20pods.md

_________________________________________________________

## STEP #5 Verify   


1.  Check the status of the assembly and modules
```
./cpd-linux status --namespace cp4d-namespace
```

Looking for something like this:
```
Status for assembly lite and relevant modules in project cp4d-namespace:

		Assembly Name           Status           Version          Arch    
		lite                    Ready            3.0.1            x86_64  

		  Module Name                     Status           Version          Arch      Storage Class     
		  0010-infra                      Ready            3.0.1            x86_64    portworx-shared-gp
		  0015-setup                      Ready            3.0.1            x86_64    portworx-shared-gp
		  0020-core                       Ready            3.0.1            x86_64    portworx-shared-gp

		=========================================================================================

		Status for assembly watson-speech and relevant modules in project zen:

		Assembly Name           Status           Version          Arch    
		watson-speech    Ready            1.1.4            x86_64  

		  Module Name                     Status           Version          Arch      Storage Class     
		  0010-infra                      Ready            3.0.1            x86_64    portworx-shared-gp
		  0015-setup                      Ready            3.0.1            x86_64    portworx-shared-gp
		  0020-core                       Ready            3.0.1            x86_64    portworx-shared-gp
		  watson-speech-base              Ready            1.1.4            x86_64                      
=======================================================================================
```

2.  Setup your Helm environment.  
```
export TILLER_NAMESPACE=cp4d-namespace
oc get secret helm-secret -n $TILLER_NAMESPACE -o yaml|grep -A3 '^data:'|tail -3 | awk -F: '{system("echo "$2" |base64 --decode > "$1)}'
export HELM_TLS_CA_CERT=$PWD/ca.cert.pem
export HELM_TLS_CERT=$PWD/helm.cert.pem
export HELM_TLS_KEY=$PWD/helm.key.pem
helm version --tls
```

You should see output like this:

```
Client: &version.Version{SemVer:"v2.14.3", GitCommit:"0e7f3b6637f7af8fcfddb3d2941fcc7cbebb0085", GitTreeState:"clean"}
Server: &version.Version{SemVer:"v2.16.6", GitCommit:"dd2e5695da88625b190e6b22e9542550ab503a47", GitTreeState:"clean"}
```

3.  Check the status of resources
```
helm status watson-speech-base --tls
```

4.  Run Helm Tests (timeout is not optional, else bdd test times out with default timer of 5 mins.  Test takes about 30 mins. 
```
helm test watson-speech-base --tls --timeout=18000
```

**Note:**  To delete pods from prior test chart execution, run with  --cleanup flag then you can run again with or without flag.
```
helm test watson-speech-base --tls --timeout=18000 --cleanup
```

**Optional:  To see what values were set when installed**
```
helm get values watson-speech-base --tls
```

_________________________________________________________

## STEP #5-Optional Update deployment for STT batch   

**Note:**  If you are going to use STT batch you should update the following  

```
oc edit role watson-speech-base-ibm-postgresql
```
Add events to the resources list  

```
oc edit deployment watson-speech-base-ibm-postgresql-proxy
oc edit deployment watson-spe-0a08-ib-642d-sentinel
oc edit statefulset watson-spe-0a08-ib-642d-keeper
```
Each of the above should have their cpu and memory requests and limits set to cpu: "1"  and memory: 1Gi  

```
oc edit statefulset watson-speech-base-ibm-rabbitmq
```
Modify rabbitmq to use cpu: 500m and memory: 1Gi  

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

## STEP #7 Test via API    


Find Token and API endpoint
* Login to Cloud Pak Cluster:  
https://cp4d-namespace-cpd-cp4d-namespace.apps.cp4d-clustername/cp4d-namespace/#/myInstances
**credentials:  admin / pw: password**
* Click on Instance name 
* Copy / Paste the token and api end point from the Access information section, then copy / paste the lines into a terminal window


```
export TOKEN=
export API_URL=
echo $TOKEN
echo $API_URL
```

 
## STT API Commands

Download files needed for speech test from:  https://github.ibm.com/jennifer-wales/watsoncp4d/tree/master/cheatsheets/speech/speech-testing
```
chmod +x speech-api-test.sh
./speech-api-test.sh
```
or optionally issue individual curl commands below:  

1) View Models
```
curl -H "Authorization: Bearer $TOKEN" -k $API_URL/v1/models
```
* Notes: Should return broadband and narrowband models per language installed, US English will also contain a short form narrowband model, this model is optimized for IVR use cases.

2) Transcribe
```
curl -H "Authorization: Bearer $TOKEN" -k -X POST  --header "Content-Type: audio/wav" --data-binary @JSON.wav "$API_URL/v1/recognize?timestamps=true&word_alternatives_threshold=0.9"
```
* Notes: Transcribe the provided audio file with the base US English broadband model


3) Create a custom language model
```
curl -H "Authorization: Bearer $TOKEN" -k -X POST --header "Content-Type: application/json" --insecure --data "{\"name\": \"CustomLanguageModelVP_v1\", \"base_model_name\": \"en-US_BroadbandModel\", \"description\": \"Custom Language Model by Victor Povar v1\"}" "$API_URL/v1/customizations"
```
* Notes: Create a custom language mode, note the language model id and replace all instances of "{language_customization_id}" with the returned model id

* Set your language customization ID from the previous command response
```
export language_customization_id=
```
4) View Customizations - Verify that the model was created - will show in pending state
```
curl -H "Authorization: Bearer $TOKEN" -k "$API_URL/v1/customizations"
```

5) Add a Corpus to the language model
```
curl -H "Authorization: Bearer $TOKEN" -k -X POST  --data-binary @IT-corpora.txt "$API_URL/v1/customizations/${language_customization_id}/corpora/corpus1"
```

6) View the corpora
```
curl -H "Authorization: Bearer $TOKEN" -k -X GET "$API_URL/v1/customizations/${language_customization_id}/corpora/corpus1"
```

7) Add OOV words dictionary
```
curl -H "Authorization: Bearer $TOKEN" -k -X POST --header "Content-Type: application/json" --data @words_list.json "$API_URL/v1/customizations/${language_customization_id}/words"
```

8) Verify that the OOV words dictionary was successfully added
```
curl -H "Authorization: Bearer $TOKEN" -k -X GET "$API_URL/v1/customizations/${language_customization_id}/words"
```

9) Train the custom language model
```
curl -H "Authorization: Bearer $TOKEN" -k -X POST "$API_URL/v1/customizations/${language_customization_id}/train"
```

10) View Customizations - Verify that the language model training is complete and the model moves into the "available" status
```
curl -H "Authorization: Bearer $TOKEN" -k -X GET "$API_URL/v1/customizations"
```

11) Transcribe with trained language model -the transcription should return "JSON" and not "J. son"
```
curl -H "Authorization: Bearer $TOKEN" -k -X POST --header "Content-Type: audio/wav" --data-binary @JSON.wav "$API_URL/v1/recognize?timestamps=true&word_alternatives_threshold=0.9&language_customization_id=${language_customization_id}&customization_weight=0.8"
```

12) Create an acoustic model
```
curl -H "Authorization: Bearer $TOKEN" -k -X POST --header "Content-Type: application/json" --data "{\"name\": \"Custom Acoustic Model by Victor Povar v1\", \"base_model_name\": \"en-US_BroadbandModel\", \"description\": \"Custom Acoustic Model by Victor Povar v1\"}" "$API_URL/v1/acoustic_customizations"

#set your acoustic customization ID from the previous command response
export acoustic_customization_id=
```

13) List en-US acoustic model - Verify that the acoustic model was created
```
curl -H "Authorization: Bearer $TOKEN" -k -X GET "$API_URL/v1/acoustic_customizations?language=en-US"
```

14) Add audio files to the acoustic model
```
curl -H "Authorization: Bearer $TOKEN" -k -X POST --header "Content-Type: application/zip" --data-binary @sample.zip "$API_URL/v1/acoustic_customizations/${acoustic_customization_id}/audio/audio1"
```

15) List audio resources
```
curl -H "Authorization: Bearer $TOKEN" -k -X GET "$API_URL/v1/acoustic_customizations/${acoustic_customization_id}/audio"
```
* Notes: Ensure that the files added to the acoustic model exceed 10 minutes (minimum required to train an acoustic model) and that all audio files were successfully processed

16) Train an acoustic model with a language model
```
curl -H "Authorization: Bearer $TOKEN" -k -X POST "$API_URL/v1/acoustic_customizations/${acoustic_customization_id}/train?custom_language_model_id=${language_customization_id}"
```

17) View Acoustic Model Status
```
curl -H "Authorization: Bearer $TOKEN" -k -X GET "$API_URL/v1/acoustic_customizations?language=en-US"
```
* Notes: Verify that the acoustic model training is complete and the model moves into the available Status

18) Transcribe the audio file with the acoustic and language model, ensure that a valid transcription is returned
```
curl -H "Authorization: Bearer $TOKEN" -k -X POST --header "Content-Type: audio/wav" --data-binary @JSON.wav "$API_URL/v1/recognize?timestamps=true&word_alternatives_threshold=0.9&language_customization_id=${language_customization_id}&customization_weight=0.8&acoustic_customization_id=${acoustic_customization_id}"
```

19) Add a grammar to a language model
```
curl -H "Authorization: Bearer $TOKEN" -k -X POST --header "Content-Type: application/srgs" --data-binary @YesNo.abnf "$API_URL/v1/customizations/${language_customization_id}/grammars/{grammar_name}"
```

20) Monitor grammars - Verify that the grammar was created.  Status will go from being_processed to analyzed.
```
curl -H "Authorization: Bearer $TOKEN" -k -X GET "$API_URL/v1/customizations/${language_customization_id}/grammars/{grammar_name}"
```

21) Retrain the custom language model now with grammar
```
curl -H "Authorization: Bearer $TOKEN" -k -X POST "$API_URL/v1/customizations/${language_customization_id}/train"
```

22) Monitor custom language model training with grammar   (takes a few mins)
```
curl -H "Authorization: Bearer $TOKEN" -k -X GET "$API_URL/v1/customizations"
```
* Notes: Verify that the language model training successfully completes


23) Transcribe with a grammar 
```
curl -H "Authorization: Bearer $TOKEN" -k -X POST --header "Content-Type: audio/wav" --data-binary @JSON.wav "$API_URL/v1/recognize?customization_id=${language_customization_id}&language_customization_enabled={grammar_name}&language_customization_weights=0.7"
```
* Notes: Transcribe an audio file with the new language model that contains a grammar, since the audio file is not tailored to the grammar, it is normal to receive hypothesis of 0.0

24) Delete a language model
```
curl -H "Authorization: Bearer $TOKEN" -k -X DELETE "$API_URL/v1/customizations/${language_customization_id}"
```

25) Delete an acoustic model
```
curl -H "Authorization: Bearer $TOKEN" -k -X DELETE "$API_URL/v1/acoustic_customizations/${acoustic_customization_id}"
```

## TTS API Commands
Find TTS Token and API endpoint  
Login to Cloud Pak Cluster:  https://icp-clustername:31843   credentials:  admin / pw: icpd-password  
Click on Hamburger and go to My Instances, Provisioned Instances  
For your Instance, Select ... far right of Start Date  and View Details  
Copy Access Token to clipboard  
```
export TOKEN=youraccesstoken
```
Copy URL to clipboard
```
export API_URL=your api endpoint
```

## Capture TTS TOKEN and service endpoint for documentation
```
echo $TOKEN >tts_icp-deployment-name_TOKEN.out
echo $TOKEN
echo $API_URL >tts_icp-deployment-name_endpoint_url
echo $API_URL
```

View Voices
```
curl -H "Authorization: Bearer $TOKEN" -k $API_URL/v1/voices
```

Test Voices  
1) Set the voice to one of your languages from the previous command response  
```
export voice=

examples:
export voice=en-US_LisaV3Voice
export voice=en-US_MichaelV3Voice
export voice=en-US_AllisonV3Voice
```

2) Run curl command to transcribe to audio
```
curl -k -X POST --header "Authorization: Bearer $TOKEN" --header "Content-Type: application/json" --header "Accept: audio/wav" --data "{\"text\":\"Hello world\"}" --output $voice.wav "$API_URL/v1/synthesize?voice=$voice"
```

3) Browse to the wav file on your computer and double click to play the wav file and hear the voice.  

4) Repeat and test all of your available voices by setting the voice variable and repeating the curl command:
```
export voice=

curl -k -X POST --header "Authorization: Bearer $TOKEN" --header "Content-Type: application/json" --header "Accept: audio/wav" --data "{\"text\":\"Hello world\"}" --output $voice.wav "$API_URL/v1/synthesize?voice=$voice"
```

_________________________________________________________

### OpenShift Collector  
_________________________________________________________

Use OpenShift Collector to capture information about deployment / gather baseline information / or use for debugging

* Download openshift Collector script and copy to installation node: https://github.ibm.com/jennifer-wales/watsoncp4d/blob/master/scripts/openshiftCollector.sh

* Run Script
```
chmod +x openshiftCollector.sh
./openshiftCollector.sh -c api.cp4d-clustername -u kubeadmin -p `cat ~/auth/kubeadmin-password` -n cp4d-namespace -t
```
_________________________________________________________

### How to Delete Deployment 
_________________________________________________________


```
#Delete lock
rm .cpd.lock

#Remove assembly
./cpd-linux uninstall --assembly watson-speech --namespace cp4d-namespace

oc delete all,configmaps,jobs,secrets,service,persistentvolumeclaims,poddisruptionbudgets,podsecuritypolicy,securitycontextconstraints,clusterrole,clusterrolebinding,role,rolebinding,serviceaccount,networkpolicy -l release=watson-speech-base

#Remove the configmap 
oc delete configmap stolon-cluster-watson-speech-base-postgressql

#Remove artifacts that are labeled
oc delete job,deploy,replicaset,pod,statefulset,configmap,secret,ingress,service,serviceaccount,role,rolebinding,persistentvolumeclaim,poddisruptionbudget,horizontalpodautoscaler,networkpolicies,cronjob -l release=watson-speech

#Remove the configmap 
oc delete configmap stolon-cluster-watson-speech

#if installing the same assembly version (prerelease only)
rm -fr cpd-linux-workspace
```

_________________________________________________________

### How to Delete Deployment - Advanced 
_________________________________________________________

Note:  If you cancelled an install by hitting Control-C, instead of waiting for install to time-out, follow instructions below before attempting re-install


```
#Delete lock
rm .cpd.lock

#Delete the cpd-install configmaps:

for i in `oc get cm| grep cpd-install | awk '{ print $1 }'`; do oc delete cm $i ; done
oc delete cm cpd-operation-cm
```

Find and delete the operator pod
```
oc get pods | grep operator
oc delete pod {cpd-install-operator-pod}
```

#Remove assembly
```
./cpd-linux uninstall --assembly ibm-watson-speech --namespace cp4d-namespace

#See artifacts that are labeled
oc get all,configmaps,jobs,secrets,service,persistentvolumeclaims,poddisruptionbudgets,podsecuritypolicy,securitycontextconstraints,clusterrole,clusterrolebinding,role,rolebinding,serviceaccount,networkpolicy -l release=watson-speech-base

#Remove artifacts that are labeled
oc delete all,configmaps,jobs,secrets,service,persistentvolumeclaims,poddisruptionbudgets,podsecuritypolicy,securitycontextconstraints,clusterrole,clusterrolebinding,role,rolebinding,serviceaccount,networkpolicy -l release=watson-speech-base

#Remove the configmap 
oc delete configmap stolon-cluster-watson-speech-base-postgressql

#Remove artifacts that are labeled
oc delete job,deploy,replicaset,pod,statefulset,configmap,secret,ingress,service,serviceaccount,role,rolebinding,persistentvolumeclaim,poddisruptionbudget,horizontalpodautoscaler,networkpolicies,cronjob -l release=watson-speech

#Remove the configmap 
oc delete configmap stolon-cluster-watson-speech
```

#Via Helm

1.  Remote into the operator pod
```
oc get pods | grep operator
oc exec -it {cpd-install-operator-pod} /bin/bash
```
2.  Delete Deployment 
```
helm delete --tls --no-hooks --purge watson-speech-base
```

3.  Post uninstall cleanup
```
kubectl delete job,deploy,rs,pod,statefulset,configmap,secret,ingress,service,serviceaccount,role,rolebinding,pvc,poddisruptionbudget,hpa --selector=release=watson-speech-base --namespace=cp4d-namespace
```


_________________________________________________________

### How to Add language models after installation 
_________________________________________________________

If you need support for additional languages you can add language models using the following commands:  

```
helm get values watson-speech-base --tls > watson-speech-base-newlangs.yaml
```

Edit file watson-speech-base-newlangs.yaml to enable new model(s)  

```
helm upgrade watson-speech-base /root/ga/cp4d301/bin/cpd-linux-workspace/modules/watson-speech-base/x86_64/1.1.4/ibm-watson-speech-prod -f watson-speech-base-newlangs.yaml --tls
```
