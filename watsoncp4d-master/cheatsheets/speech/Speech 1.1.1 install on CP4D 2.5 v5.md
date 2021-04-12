# Speech 1.1.1 on CP4D 2.5 (Openshift 311)

_________________________________________________________

## Reference 

* Documentation:   https://www.ibm.com/support/producthub/icpdata/docs/content/SSQNUZ_current/cpd/svc/watson/speech-to-text-install.html
* Readme:  https://github.com/ibm-cloud-docs/data-readmes/blob/master/speech-1.1.3-README.md
* Watson Install Requirements:  https://apps.na.collabserv.com/wikis/home?lang=en-us#!/wiki/Wd855b33ea663_4b57_a7c7_f5e8e37c2716/page/Watson%20Install%20Prereqs%20(Q4%202019%20Release)/edit

URLs
* OpenShift Admin URL:  https://cp4d-clustername:8443

* Cloud Pak Admin URL:  https://cp4d-namespace-cpd-cp4d-namespace.apps.cp4d-clustername

CLI Login 
```
oc login cp4d-clustername:8443 -u ocadmin -p ocadmin
docker login -u $(oc whoami) -p $(oc whoami -t ) $(oc get routes docker-registry -n default -o template={{.spec.host}})
```

_________________________________________________________

## START HERE
This cheatsheet can be used to do a vanilla development installation of Watson Speech Services 1.1.1 on CP4D 25 on Openshift 3.11 with portworx Storage.

### Overview
* Do a Find and replace for the variables below to update the syntax of the commands below for your installation.   Do not use cheatsheet from box as the formatting of commands is lost. 
* Verify prereqs are met
* Follow instructions to install & verify
_________________________________________________________

## STEP 1 - Replace variables for your deploy  
* Find and replace `cp4d-clustername` with your clustername (typically load balancer fqdn) - ex: wp-wa-stt-feb23.icp.ibmcsf.net
* Find and replace your `release-name` with the deployment name
* Find and replace your `cp4d-namespace` with your CP4D namespace or project name - ex: zen
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

Download Watson Package(s) and transfer to master node 

Release info here: https://apps.na.collabserv.com/wikis/home?lang=en-us#!/wiki/Wd855b33ea663_4b57_a7c7_f5e8e37c2716/page/Watson%20on%20Cloud%20Pak%20Releases

Optionally Grab Archive from Dimply - password is Trans001!
```
scp xfer@9.30.44.60:/root/ga/ibm-watson-speech-prod-1.1.1.tar.gz .
```

Extract Watson archive to filesystem that has ample space 
```
cd /workingdir
mkdir /workingdir/speech-ppa
tar xvfz ibm-watson-speech-prod-1.1.1.tar.gz -C /workingdir/speech-ppa
```

Extract chart
```
cd /workingdir/speech-ppa/charts
tar -xvf ibm-watson-speech-prod-1.1.3.tgz
```

Load the Docker Images  - using external repo address
Note - you will need to install jq to use this script:

Load jq to use loadImagesOpenShift script
```
wget -O jq https://github.com/stedolan/jq/releases/download/jq-1.6/jq-linux64
chmod +x ./jq
cp jq /usr/bin
```

Upload speech images
```
cd /workingdir/speech-ppa/charts/ibm-watson-speech-prod/ibm_cloud_pak/pak_extensions/pre-install/clusterAdministration
chmod +x loadImagesOpenShift.sh
export DOCKER_REGISTRY_PREFIX=$(oc get routes docker-registry -n default -o template={{.spec.host}})
echo $DOCKER_REGISTRY_PREFIX
./loadImagesOpenShift.sh --path /workingdir/speech-ppa --namespace cp4d-namespace --registry $DOCKER_REGISTRY_PREFIX
```
_________________________________________________________

Optional language Pack  
Download and transfer language pack to Master node  

Extract Watson archive to filesystem that has ample space 
```
mkdir /workingdir/speech-lang
tar xvfz ibm-watson-speech-pack-prod-1.1.1.tar.gz -C /workingdir/speech-lang
```

Upload speech language pack images
```
cd /workingdir/speech-ppa/charts/ibm-watson-speech-prod/ibm_cloud_pak/pak_extensions/pre-install/clusterAdministration
export DOCKER_REGISTRY_PREFIX=$(oc get routes docker-registry -n default -o template={{.spec.host}})
echo $DOCKER_REGISTRY_PREFIX
./loadImagesOpenShift.sh --path /workingdir/speech-lang --namespace cp4d-namespace --registry $DOCKER_REGISTRY_PREFIX
```
_________________________________________________________

To view images
```
oc get images
```
_________________________________________________________

Create Portworx Storage Class by pasting text below  
***Note:  Speech does not use one of the standard storageclasses preconfigured during Portworx install (yet)***
```
cat <<EOF | kubectl apply -n cp4d-namespace -f -

apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: portworx-speech
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

_________________________________________________________


Check for cp4d-namespace label 
```
kubectl get namespace cp4d-namespace --show-labels
```

Run labelNamespace.sh  (if needed - only needs to be done once per cluster when installing multiple services)
```
cd /workingdir/speech-ppa/charts/ibm-watson-speech-prod/ibm_cloud_pak/pak_extensions/pre-install/clusterAdministration
chmod +x labelNamespace.sh
./labelNamespace.sh cp4d-namespace
```

_________________________________________________________

Create Minio Secrets  
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

Apply minio.yaml
```
kubectl apply -f minio.yaml
```
Create Postgres Credentials (postgrescreds.yaml)  
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

Apply postgrescreds.yaml
```
kubectl apply -f postgrescreds.yaml
```
_________________________________________________________

Copy values.yaml to values-override.yaml 
```
cd /workingdir/speech-ppa/charts/ibm-watson-speech-prod
cp values.yaml ../values-override.yaml
cd ..
```

Get docker secret name - you will need for your override file
```
oc get secrets | grep default-dockercfg | awk '{print $1}'
```
_________________________________________________________

#### Edit values-override.yaml & set values for your deployment
```
vi values-override.yaml
```
Down arrow to navigate to the line you need to change  
`i` to enter insert mode  


Set STT and TTS Customization on or off:
* Set sttCustomization: true or false
* Set ttsCustomization: true or false
* Set sttRuntime: true or false
* Set ttsRuntime: true or false

Set the following parms  

* Set global.icpDockerRepo to `docker-registry.default.svc.cluster.local:5000/cp4d-namespace`
* Set global.imagePullSecretName to docker secret name from above
* Set global.image.repository to `docker-registry.default.svc.cluster.local:5000/cp4d-namespace`
* Set global.image.pullSecret to docker secret name from above


Globally change storageclass from rook-ceph-cephfs-internal to portworx: 
* Hit `esc` and `:` 
* Paste the following to search and replace strings: 
```
%s/rook-ceph-cephfs-internal/portworx-speech/g
```
You should see 3 substitutions on 3 lines  


If you are using a namespace / project other than zen, you must also set zenNamespace to `cp4d-namespace`

Set `sttModels` as needed for your use case by setting desired models to true.  By default English US Broadband, US Narrowband and US Shortform Narrowband are enabled.

Set `ttsVoices` as needed for your use case by setting desired models to true. By default English Michael, Allison and Lisa voices are enabled.
 
Enter `:wq` to Save and Exit

_________________________________________________________

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


Set targeted namespace
```
oc project cp4d-namespace
```

Change into charts directory
```
cd /workingdir/speech-ppa/charts
```
Establish the certificate and key for Helm Tiller
```
export TILLER_NAMESPACE=cp4d-namespace
oc get secret helm-secret -n $TILLER_NAMESPACE -o yaml|grep -A3 '^data:'|tail -3 | awk -F: '{system("echo "$2" |base64 --decode > "$1)}'
export HELM_TLS_CA_CERT=$PWD/ca.cert.pem
export HELM_TLS_CERT=$PWD/helm.cert.pem
export HELM_TLS_KEY=$PWD/helm.key.pem
helm version  --tls
```
_________________________________________________________

Run Helm Install 
```
helm install --values values-override.yaml ibm-watson-speech-prod --tiller-namespace cp4d-namespace --name release-name --tls
```

_________________________________________________________

Open a second terminal window and watch deployment spin up.  
Wait for all pods to become ready. 

Open up a second terminal window and ssh to master node
```
ssh root@IP_address
watch oc get job,pod --namespace cp4d-namespace -l release=release-name
```
Wait for all pods to become ready.  You are looking for all of the Jobs to be in Successful=1


Control C to exit watch


To check status of your deployment
```
export TILLER_NAMESPACE=cp4d-namespace
oc get secret helm-secret -n $TILLER_NAMESPACE -o yaml|grep -A3 '^data:'|tail -3 | awk -F: '{system("echo "$2" |base64 --decode > "$1)}'
export HELM_TLS_CA_CERT=$PWD/ca.cert.pem
export HELM_TLS_CERT=$PWD/helm.cert.pem
export HELM_TLS_KEY=$PWD/helm.key.pem
helm status --tls release-name --debug
```

To check for pods not Running or Running but not ready
```
oc get pods --all-namespaces | grep -Ev '1/1|2/2|3/3|4/4' | grep -v 'Completed'
```

_________________________________________________________

### Install async batch bugfix if customer is using batch
* Notes: This is a development provided fix and should not be used in production  
#### Update stt async deployment
Copy bugfix image from dimply image host into your local path  
```
cd /workingdir
scp -p xfer@9.30.44.60:/root/ga/stt-async-patch-Apr16th2020.tar .
```
**Credentials pw:  Trans001!    

Upload bugfix image to your local docker  
```
export DOCKER_REGISTRY_PREFIX=$(oc get routes docker-registry -n default -o template={{.spec.host}})
echo $DOCKER_REGISTRY_PREFIX
docker load -i stt-async-patch-Apr16th2020.tar
```
* Notes: the above will return an image name that you will have to tag and push such as us.icr.io/redsonja_hyboria/speech_services/stt-async:2.0.1-20200416214742  
```
docker tag us.icr.io/redsonja_hyboria/speech_services/stt-async:2.0.1-20200416214742 $DOCKER_REGISTRY_PREFIX/cp4d-namespace/stt-async:bugapr-016
docker push $DOCKER_REGISTRY_PREFIX/cp4d-namespace/stt-async:bugapr-016
```
Edit the stt async deployment to use the new image  
```
kubectl edit deployment release-name-speech-to-text-stt-async  
Change image tag from "master-609" to "bugapr-016"  
```
Save and quit ":wq"  
#### Edit the RabbitMQ deployment to update the memory required from 256MB to 1GB:  
```
kubectl edit statefulset release-name-ibm-rabbitmq  
```
Set the values to:  
```
        resources:
          limits:
            cpu: 500m
            memory: 1Gi
          requests:
            cpu: 500m
            memory: 1Gi  
```
Save and quit ":wq"  

_________________________________________________________

## Provision your instance
Login to Cloud Pak Cluster:  https://cp4d-namespace-cpd-cp4d-namespace.apps.cp4d-clustername/cp4d-namespace/#/addons   
**credentials:  admin / pw: password**

Select Watson Service (STT or TTS)  
Select Deploy  
Select Create Instance and give it a name  
Repeat if you installed both STT and TTS  

_________________________________________________________

## Verify deployment

Run Test chart
```
helm test --tls release-name
```


**Note:  To delete pods from prior test chart execution, run with  --cleanup flag then you can run again with or without flag.**
```
helm test --tls release-name --cleanup
```
_________________________________________________________

## Test via API

Find Token and API endpoint
* Login to Cloud Pak Cluster:  https://cp4d-namespace-cpd-cp4d-namespace.apps.cp4d-clustername   
**credentials:  admin / pw: password**
* Click on Hamburger and go to My Instances, Provisioned Instances
* For your Instance, Select ... far right of Start Date  and View Details

Copy / Paste the token and api end point below, then copy / paste the lines into a terminal window
```
export TOKEN=
export API_URL=
echo $TOKEN >cp4d-release-token.out
echo $TOKEN
echo $API_URL >release-name_api_url.out
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

* Capture information about deployment / gather baseline information / or use for debugging  

* Download openshift Collector script and copy to Master node (ibm directory): https://github.ibm.com/jennifer-wales/watsoncp4d/tree/master/scripts

* Run Script
```
chmod +x openshiftCollector.sh
./openshiftCollector.sh -c cp4d-clustername -u ocadmin -p ocadmin -n cp4d-namespace -t
```

or 

Run commands below to capture manually  
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


To modify deployment - add models, or languages  
* Note:  To enable STT or TTS after Speech services has been deployed, you must reinstall; upgrade will not perform required pre-hooks 


_________________________________________________________


### How to Delete Deployment 

1. Delete Instance from My Instances Page  

Login to Cloud Pak Cluster:  https://zen-cpd-zen.apps.cp4d-clustername/zen/#/myInstances   credentials:  admin / pw: password  
Click on Hamburger, go to My Instances  
Click on ... to right of Start date and select Delete  
Confirm

2.  Delete Deployment  
```
helm delete --tls --no-hooks --purge release-name 
```

3.  Post uninstall cleanup
```
kubectl delete job,deploy,rs,pod,statefulset,configmap,secret,ingress,service,serviceaccount,role,rolebinding,pvc,poddisruptionbudget,hpa --selector=release=release-name --namespace=cp4d-namespace
```

4.  Remove the configmap
```
kubectl delete cm stolon-cluster-release-name-postgressql
```
