Speech on Cloud pak for data 1.0 / ICP 3.1.2  as a premium add on

Updates July 10 
Speech Services 1.0 as a premium add on Draft1
https://docs-icpdata.mybluemix.net/docs/content/SSQNUZ_current/com.ibm.icpdata.doc/watson/speech-to-text-install.html

Update July 19
Added API tests for TTS

Update Aug 17
Added test for gluster

_________________________________________________________


#Preparation Steps

#Reference

What is your cluster name?  (load balancer address if multiple masters) 
What is the public IP of your primary master node?  
What is the private IP of your master node (fyre)
What is your ICP Password?  Passw0rdPassw0rdPassw0rdPassw0rd
What do you want to call your deployment?


Find and replace `icp-clustername` with your clustername - ex: wp-wa-stt-feb23.icp.ibmcsf.net
Find and replace your `icp-deployment-name` with your deployment name
Find and replace your `icp-namespace` with your Namespace name - 'conversation'
Find and replace your `icp-password` with your Namespace name - 'Passw0rdPassw0rdPassw0rdPassw0rd'
Find and replace your `public_master_ip` with your public ip address
Find and replace your `worker1` with the IP address of Worker #1 
Find and replace your `worker2` with the IP address of Worker #2
Find and replace your `worker3` with the IP address of Worker #2 


ICP Console Admin URL:https://icp-clustername:8443/console/welcome
Cloud Pak Admin URL:  https://icp-clustername:31843
CLI Login: cloudctl login -a https://icp-clustername:8443 --skip-ssl-validation -u admin -p icp-password


_________________________________________________________
#Speech Services Storage

Speech Services uses GlusterFS for Minio and local-storage, vSphere volumes or Portworx for Postgres and RabbitMQ.
Configure GlusterFS before proceeding.


_________________________________________________________

#Setup Client for ICP

Modify Local Hosts for ICP cluster if not in DNS
-sudo nano /etc/hosts
-add the provided cluster ip address, save and exit:
example:  
9.30.251.234     mycluster.icp

Install ICP / Helm / Kubectl CLIs https://icp-clustername:8443/console/tools/cli  

Optionally install Watch on your mac -  useful for watching services come up (http://osxdaily.com/2010/08/22/install-watch-command-on-os-x/)


_________________________________________________________

#Install

#SSH to master - will do installation there
ssh root@public_master_ip

#Login to ICP Cluster 
cloudctl login -a https://icp-clustername:8443 --skip-ssl-validation -u admin -p icp-password

Select the zen namespace for now

#Optionally Create Namespace or you can install to zen
kubectl create namespace icp-namespace

#Login to cluster again and select icp-namespace namespace
cloudctl login -a https://icp-clustername:8443 --skip-ssl-validation -u admin -p icp-password

#Run Healthcheck  *****make sure Gluster status is OK before proceeding*****
cd /ibm/InstallPackage/utils/ICP4D-Support-Tools
./icp4d_tools.sh --health


#Verify ICP cluster meets minimum requirements for # workers, memory and cores
x86 processors 

`kubectl get nodes`

`kubectl get nodes -o=jsonpath="{range .items[*]}{.metadata.name}{'\t'}{.status.allocatable.memory}{'\t'}{.status.allocatable.cpu}{'\n'}{end}"`


#Download Watson Package to master node 

Watson Speech Services V1.0.0 Linux English (CC2EWEN )
wget https://ak-dsw-mul.dhe.ibm.com/sdfdl/v2/fulfill/CC2EWEN/Xa.2/Xb.htcOMovxHCAgZGTTtBvfmSss_YKRo8FK/Xc.CC2EWEN/ibm-watson-speech-prod-1.0.0.tar.gz/Xd./Xf.lPr.A6VR/Xg.10274098/Xi./XY.knac/XZ.nuA-SQbFJa8MkYlYChJHSyERgiw/ibm-watson-speech-prod-1.0.0.tar.gz#anchor --no-check-certificate 

#Download Language pack if you are doing other languages
IBM Watson Speech Services Language Pack V1.0.0 Linux English (CC2EXEN
wget https://ak-dsw-mul.dhe.ibm.com/sdfdl/v2/fulfill/CC2EXEN/Xa.2/Xb.htcOMovxHCAgZGTTtBvfmSss_YKzJBic/Xc.CC2EXEN/ibm-watson-speech-pack-prod-1.0.0.tar.gz/Xd./Xf.lPr.A6VR/Xg.10274098/Xi./XY.knac/XZ.LRO1WojtcXViofpkSQW9K98PMT8/ibm-watson-speech-pack-prod-1.0.0.tar.gz#anchor --no-check-certificate 

#Secrets (minio.yaml)
#Paste below to create minio.yaml (uses default admin / admin1234 base 64 encoding)
`
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
`

#Apply minio.yaml
kubectl apply -f minio.yaml

#Postgres Credentials (postgrescreds.yaml)
#Paste below to create postgrescreds.yaml encoding)
`
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
`


#Apply postgrescreds.yaml
kubectl apply -f postgrescreds.yaml

_________________________________________________________

Create PVs for PostgreSQL and RabbitMQ

Need to create PVs for PostgresSQL and optionally RabbitMQ if you are planning to use the async service

The PVs are setup with host affinity so they will only run on the designated worker if the worker id down, the Pod will not run.  There are a total of 3 instances each, and you only need a mininum of 2 instances for the service to run.

#NOTE -need a script to do this.  lines below will create 6 - 30G PVs for Postgres and Rabbit
#also - will need to add labels to guarantee the pv is used for the desired pvc.   See assistant technote for background:  https://ibm.box.com/s/dbiddxoptmfo72shx7c9gakuri5szqh7


#30g-1-worker1 - will be deployed to worker #1

`
cat > 30g-1-worker1.yaml << EOF
apiVersion: v1
kind: PersistentVolume
metadata:
  name: 30g-1-worker1
spec:
  capacity:
    storage: 30Gi
  accessModes:
  - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: local-storage-local
  local:
    path: /mnt/local-storage/speech/30g-1-worker1
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: In
          values:
          - worker1
EOF
`

kubectl apply -f 30g-1-worker1.yaml

#30g-2-worker1 - will be deployed to worker #1

`
cat > 30g-2-worker1.yaml << EOF
apiVersion: v1
kind: PersistentVolume
metadata:
  name: 30g-2-worker1
spec:
  capacity:
    storage: 30Gi
  accessModes:
  - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: local-storage-local
  local:
    path: /mnt/local-storage/speech/30g-2-worker1
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: In
          values:
          - worker1
EOF
`

kubectl apply -f 30g-2-worker1.yaml

#30g-1-worker2 - will be deployed to worker #1

`
cat > 30g-1-worker2.yaml << EOF
apiVersion: v1
kind: PersistentVolume
metadata:
  name: 30g-1-worker2
spec:
  capacity:
    storage: 30Gi
  accessModes:
  - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: local-storage-local
  local:
    path: /mnt/local-storage/speech/30g-1-worker2
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: In
          values:
          - worker2
EOF
`

kubectl apply -f 30g-1-worker2.yaml

#30g-2-worker2 - will be deployed to worker #1

`
cat > 30g-2-worker2.yaml << EOF
apiVersion: v1
kind: PersistentVolume
metadata:
  name: 30g-2-worker2
spec:
  capacity:
    storage: 30Gi
  accessModes:
  - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: local-storage-local
  local:
    path: /mnt/local-storage/speech/30g-2-worker2
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: In
          values:
          - worker2
EOF
`

kubectl apply -f 30g-2-worker2.yaml

#30g-1-worker3 - will be deployed to worker #1

`
cat > 30g-1-worker3.yaml << EOF
apiVersion: v1
kind: PersistentVolume
metadata:
  name: 30g-1-worker3
spec:
  capacity:
    storage: 30Gi
  accessModes:
  - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: local-storage-local
  local:
    path: /mnt/local-storage/speech/30g-1-worker3
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: In
          values:
          - worker3
EOF
`

kubectl apply -f 30g-1-worker3.yaml

#30g-2-worker3 - will be deployed to worker #1

`
cat > 30g-2-worker3.yaml << EOF
apiVersion: v1
kind: PersistentVolume
metadata:
  name: 30g-2-worker3
spec:
  capacity:
    storage: 30Gi
  accessModes:
  - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: local-storage-local
  local:
    path: /mnt/local-storage/speech/30g-2-worker3
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: In
          values:
          - worker3
EOF
`

kubectl apply -f 30g-2-worker3.yaml


#Remote into each of the worker nodes and create the directory above and set the rights
ssh root@worker1
mkdir -p /mnt/local-storage/speech/30g-1-worker1
chmod 777 /mnt/local-storage/speech/30g-1-worker1
mkdir -p /mnt/local-storage/speech/30g-2-worker1
chmod 777 /mnt/local-storage/speech/30g-2-worker1


ssh root@worker2
mkdir -p /mnt/local-storage/speech/30g-1-worker2
chmod 777 /mnt/local-storage/speech/30g-1-worker2
mkdir -p /mnt/local-storage/speech/30g-2-worker2
chmod 777 /mnt/local-storage/speech/30g-2-worker2


ssh root@worker3
mkdir -p /mnt/local-storage/speech/30g-1-worker3
chmod 777 /mnt/local-storage/speech/30g-1-worker3
mkdir -p /mnt/local-storage/speech/30g-2-worker3
chmod 777 /mnt/local-storage/speech/30g-2-worker3


_________________________________________________________

#Load the Watson Archive to the registry

cloudctl catalog load-archive --registry "icp-clustername:8500" --archive ibm-watson-speech-prod-1.0.0.tar.gz -repo local-charts

#Label Zen namespace
kubectl label --overwrite namespace/zen ns=zen

#Check zen label with:
kubectl get namespace zen --show-labels


#Create the cluster image policy 
#Paste below to create policy.yaml
`
cat > policy.yaml << EOF
apiVersion: securityenforcement.admission.cloud.ibm.com/v1beta1
kind: ClusterImagePolicy
metadata:
  name: ibmcloud-default-cluster-image-policy
spec:
   repositories:
    # This enforces that all images deployed to this cluster pass trust and VA
    # To override, set an ImagePolicy for a specific Kubernetes namespace or modify this policy
    - name: "*"
      policy:
        trust:
          enabled: false
        va:
          enabled: false
EOF
`

#Apply policy.yaml
kubectl apply -f policy.yaml

#Note:  not sure these 5 steps are needed - need to verify

#Initiate Helm
helm init --client-only

#Configure SSL certificate to be used with helm (if self signed)
openssl s_client -showcerts -connect icp-clustername:8443 < /dev/null | openssl x509 -outform PEM >> /etc/ssl/certs/mycluster.pem

#Add the repos to Helm
helm repo add zenrepos https://icp-clustername:8443/helm-repo/charts

#Update the Helm repos
helm repo update

#Check that the repo has been updated
helm search zenrepos/

_________________________________________________________

##Command line install 

#Grab chart
wget --no-check-certificate https://icp-clustername:8443/helm-repo/requiredAssets/ibm-watson-speech-prod-1.0.0.tgz

tar -xvf ibm-watson-speech-prod-1.0.0.tgz

#Copy values.yaml to values-override.yaml, edit then move to same directory as the chart
cd ibm-watson-speech-prod directory
cp values.yaml ../values-override.yaml
cd ..
vi values-override.yaml

Set STT and TTS Customization on or off:
  sttCustomization: true
  ttsCustomization: false
  sttRuntime: true
  ttsRuntime: false

Deselect unnecessary language / models
Verify the image paths are set to your cluster:  mycluster.icp/speech-services


#Install
helm install --tls --values values-override.yaml --namespace icp-namespace --name icp-deployment-name ibm-watson-speech-prod


#Wait for all pods to become ready.  
Open up a second terminal window and use watch command below to see the progress.
watch kubectl get job,pod,svc,secret,cm,pvc --namespace icp-namespace -l release=icp-deployment-name

#To check status of your deployment
helm status --tls icp-deployment-name --debug

#Provision your instance(s)
Login to Cloud Pak Cluster:  https://icp-clustername:31843   credentials:  admin / pw: password
Click on Add On icon in upper right hand corner
Go to your addon
Select Provision Instance
Select Create Instance and give it a name 
Repeat if you installed both STT and TTS

_________________________________________________________

#Verify deployment

#Run Test chart - this is not currently working - expected to be fixed in Aug release
helm test --tls icp-deployment-name

Note:  To delete pods from prior test chart execution, run with  --cleanup flag then you can run again with or without flag.
helm test --tls icp-deployment-name --cleanup

#To check values used for your deployment
helm get values icp-deployment-name --tls

#Test via API

#Find STT Token and API endpoint 
Login to Cloud Pak Cluster:  https://icp-clustername:31843   credentials:  admin / pw: icpd-password
Click on Hamburger and go to My Instances, Provisioned Instances
For your Instance, Select ... far right of Start Date  and View Details
Copy Access Token to clipboard
export TOKEN=youraccesstoken
Copy URL to clipboard
export API_URL=your api endpoint

#Capture STT TOKEN and service endpoint for documentation
echo $TOKEN >stt_icp-deployment-name_TOKEN.out
echo $TOKEN
echo $API_URL >stt_icp-deployment-name_endpoint_url
echo $API_URL
 
#STT API Commands
1) View Models

curl -H "Authorization: Bearer $TOKEN" -k $API_URL/v1/models
Notes: Should return broadband and narrowband models per language installed, US English will also contain a short form narrowband model, this model is optimized for IVR use cases.

2) Transcribe

curl -H "Authorization: Bearer $TOKEN" -k -X POST  --header "Content-Type: audio/wav" --data-binary @JSON.wav "$API_URL/v1/recognize?timestamps=true&word_alternatives_threshold=0.9"
Notes: Transcribe the provided audio file with the base US English broadband model


3) Create a custom language model
curl -H "Authorization: Bearer $TOKEN" -k -X POST --header "Content-Type: application/json" --insecure --data "{\"name\": \"CustomLanguageModelVP_v1\", \"base_model_name\": \"en-US_BroadbandModel\", \"description\": \"Custom Language Model by Victor Povar v1\"}" "$API_URL/v1/customizations"
Notes: Create a custom language mode, note the language model id and replace all instances of "{language_customization_id}" with the returned model id

#set your language customization ID from the previous command response
export language_customization_id=fbf1f870-3354-481f-bc3b-72673713cac7

4) View Customizations
curl -H "Authorization: Bearer $TOKEN" -k "$API_URL/v1/customizations"

Notes: Verify that the model was created - will show in pending state


5) Add a Corpus
curl -H "Authorization: Bearer $TOKEN" -k -X POST  --data-binary @IT-corpora.txt "$API_URL/v1/customizations/${language_customization_id}/corpora/corpus1"
Notes: Add a corpus to the language model

6) View the corpora
curl -H "Authorization: Bearer $TOKEN" -k -X GET "$API_URL/v1/customizations/${language_customization_id}/corpora/corpus1"

7) Add OOV Dictionary
curl -H "Authorization: Bearer $TOKEN" -k -X POST --header "Content-Type: application/json" --data @words_list.json "$API_URL/v1/customizations/${language_customization_id}/words"
Notes: Add an OOV words dictionary

8) View the OOV words
curl -H "Authorization: Bearer $TOKEN" -k -X GET "$API_URL/v1/customizations/${language_customization_id}/words"
Notes: Verify that the OOV words dictionary was successfully added

9) Train the custom language model
curl -H "Authorization: Bearer $TOKEN" -k -X POST "$API_URL/v1/customizations/${language_customization_id}/train"
Notes: Train the language model

10) View Customizations
curl -H "Authorization: Bearer $TOKEN" -k -X GET "$API_URL/v1/customizations"
Notes: Verify that the language model training is complete and the model moves into the "available" status

11) Transcribe with language model
curl -H "Authorization: Bearer $TOKEN" -k -X POST --header "Content-Type: audio/wav" --data-binary @JSON.wav "$API_URL/v1/recognize?timestamps=true&word_alternatives_threshold=0.9&language_customization_id=${language_customization_id}&customization_weight=0.8"
Notes: Transcribe an audio file with the trained language model, the transcription should return "JSON" and not "J. son"

12) Create an acoustic model
curl -H "Authorization: Bearer $TOKEN" -k -X POST --header "Content-Type: application/json" --data "{\"name\": \"Custom Acoustic Model by Victor Povar v1\", \"base_model_name\": \"en-US_BroadbandModel\", \"description\": \"Custom Acoustic Model by Victor Povar v1\"}" "$API_URL/v1/acoustic_customizations"
Notes: Create an acoustic model, note the acoustic model id and replace all instances of {acoustic_customization_id} with the returned acoustic model id


13) List en-US acoustic model
curl -H "Authorization: Bearer $TOKEN" -k -X GET "$API_URL/v1/acoustic_customizations?language=en-US"
Notes: Verify that the acoustic model was created

#set your acoustic customization ID from the previous command response
export acoustic_customization_id=
export acoustic_customization_id=e6002933-a516-4288-94a6-a81a4008087c

14) Add audio resource
curl -H "Authorization: Bearer $TOKEN" -k -X POST --header "Content-Type: application/zip" --data-binary @sample.zip "$API_URL/v1/acoustic_customizations/${acoustic_customization_id}/audio/audio1"
Notes: Add audio files to the acoustic model

15) List audio resources
curl -H "Authorization: Bearer $TOKEN" -k -X GET "$API_URL/v1/acoustic_customizations/${acoustic_customization_id}/audio"
Notes: Ensure that the files added to the acoustic model exceed 10 minutes (minimum required to train an acoustic model) and that all audio files were successfully processed

16) Train an acoustic model with a language model
curl -H "Authorization: Bearer $TOKEN" -k -X POST "$API_URL/v1/acoustic_customizations/${acoustic_customization_id}/train?custom_language_model_id=${language_customization_id}"
Notes: Train the acoustic model

17) View Acoustic Model Status
curl -H "Authorization: Bearer $TOKEN" -k -X GET "$API_URL/v1/acoustic_customizations?language=en-US"
Notes: Verify that the acoustic model training is complete and the model moves into the available Status

18) Transcribe with language model and acoustic model
curl -H "Authorization: Bearer $TOKEN" -k -X POST --header "Content-Type: audio/wav" --data-binary @JSON.wav "$API_URL/v1/recognize?timestamps=true&word_alternatives_threshold=0.9&language_customization_id=${language_customization_id}&customization_weight=0.8&acoustic_customization_id=${acoustic_customization_id}"
Notes: Transcribe the audio file with the acoustic and language model, ensure that a valid transcription is returned

19) Add a grammar to a language model
curl -H "Authorization: Bearer $TOKEN" -k -X POST --header "Content-Type: application/srgs" --data-binary @YesNo.abnf "$API_URL/v1/customizations/${language_customization_id}/grammars/{grammar_name}"
Notes: Create a new grammar, replace all instances of {grammar_name} with the name of the grammar

20) Monitor grammars
curl -H "Authorization: Bearer $TOKEN" -k -X GET "$API_URL/v1/customizations/${language_customization_id}/grammars/{grammar_name}"
Notes: Verify that the grammar was created.  Status will go from being_processed to analyzed.

21) Train the custom language model
curl -H "Authorization: Bearer $TOKEN" -k -X POST "$API_URL/v1/customizations/${language_customization_id}/train"
Notes: Train the language model, since grammar is an extention of the language model, the language model has to be retrained for the grammar to be available

22) Monitor custom language model training with grammar
curl -H "Authorization: Bearer $TOKEN" -k -X GET "$API_URL/v1/customizations"
Notes: Verify that the language model training successfully completes


23) Transcribe with a grammar 
curl -H "Authorization: Bearer $TOKEN" -k -X POST --header "Content-Type: audio/wav" --data-binary @JSON.wav "$API_URL/v1/recognize?customization_id=${language_customization_id}&language_customization_enabled={grammar_name}&language_customization_weights=0.7"
Notes: Transcribe an audio file with the new language model that contains a grammar, since the audio file is not tailored to the grammar, it is normal to receive hypothesis of 0.0

24) Delete a language model
curl -H "Authorization: Bearer $TOKEN" -k -X DELETE "$API_URL/v1/customizations/${language_customization_id}"
Notes: Remove the language model

25) Delete an acoustic model
curl -H "Authorization: Bearer $TOKEN" -k -X DELETE "$API_URL/v1/acoustic_customizations/${acoustic_customization_id}"
Notes: Remove the acoustic model

#TTS API Commands

1) View Voices
curl -H "Authorization: Bearer $TOKEN" -k $API_URL/v1/voices

2) Test Voices
Set the voice to one of your languages from the previous command response
export voice=

examples:
export voice=en-US_LisaV3Voice
export voice=en-US_MichaelV3Voice
export voice=en-US_AllisonV3Voice


curl -k -X POST --header "Authorization: Bearer $TOKEN" --header "Content-Type: application/json" --header "Accept: audio/wav" --data "{\"text\":\"Hello world\"}" --output $voice.wav "$API_URL/v1/synthesize?voice=$voice"

#Repeat and test all of your available voices by setting the voice variable and repeating the curl command:
export voice=

curl -k -X POST --header "Authorization: Bearer $TOKEN" --header "Content-Type: application/json" --header "Accept: audio/wav" --data "{\"text\":\"Hello world\"}" --output $voice.wav "$API_URL/v1/synthesize?voice=$voice"

_________________________________________________________

#Capture information about deployment 

kubectl get nodes --show-labels >icp-clustername_nodes.out

`kubectl get nodes -o=jsonpath="{range .items[*]}{.metadata.name}{'\t'}{.status.allocatable.memory}{'\t'}{.status.allocatable.cpu}{'\n'}{end}" >icp-clustername_compute.out`

kubectl get pods -o wide >icp-clustername_pods.out

helm status --tls icp-deployment-name >icp-clustername_helm_status.out

kubectl describe nodes>describe_nodes.out

helm get icp-deployment-name --tls >helm_release_icp-clustername.out

or optionally run icpCollector_without_jq.sh to snapshot config / logs post install (recommended)
#copy script to master node.  https://ibm.box.com/s/q87wpr3vy92u46cmywue7m69ri13zjyx

run icpcollector from Masternode
./icpCollector_without_jq.sh -c icp-clustername -a id-mycluster-account -n icp-namespace -u admin -p icp-password

_________________________________________________________


#To modify deployment - add models, or languages 
Note:  To enable STT or TTS after Speech services has been deployed, you must reinstall; upgrade will not perform required pre-hooks 

#modify values-override.yaml used to deploy speech services


#Run helm upgrade
helm upgrade icp-deployment-name ibm-watson-speech-prod -f values-override.yaml --namespace speech-services --tls

_________________________________________________________

###to Delete Deployment 


#Delete Instance from My Instances Page

Login to Cloud Pak Cluster:  https://icp-clustername:31843   credentials:  admin / pw: password
Click on Hamburger, go to My Instances
Click on ... to right of Start date and select Delete
Confirm

#Clean up artifacts left over from instance (verify this is needed for disco)
kubectl -n zen exec zen-metastoredb-0 \
-- sh /cockroach/cockroach.sh sql  \
--insecure -e "DELETE FROM zen.service_instances WHERE deleted_at IS NOT NULL RETURNING id;" \
--host='zen-metastoredb-public'

#Delete Deployment

helm delete --tls --purge icp-deployment-name
helm delete --tls --no-hooks --purge icp-deployment-name (use --no-hooks if above command fails)

#Delete everything else

kubectl delete --namespace=icp-namespace job,deploy,rs,pod,statefulset,configmap,secret,ingress,service,serviceaccount,role,rolebinding,pvc,poddisruptionbudget -l release=icp-deployment-name


#Delete the PVs 
```
kubectl delete persistentvolumes $(kubectl get persistentvolumes \
  --output=jsonpath='{range .items[*]}{@.metadata.name}:{@.status.phase}:{@.spec.claimRef.name}{"\n"}{end}' \
  | grep ":Released:" \
  | grep "icp-deployment-name-" \
  | cut -d ':' -f 1)

  ```


#Delete the data from the PV on each of your worker nodes 
To find your worker ips 
kubectl get nodes

Remote into each worker node and check directory and purge if you find PV data for the service there
ssh root@{workernodeip}
ls /mnt/local-storage/speech
rm -r -f /mnt/local-storage/speech
exit

Repeat for remaining worker nodes

