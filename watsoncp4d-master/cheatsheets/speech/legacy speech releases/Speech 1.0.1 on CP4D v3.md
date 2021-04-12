Speech 1.0.1 on Cloud pak for data 2.1.0.1 as a premium add on

Updates 
Sept 25 - fixed typo in values-override.yaml
Sept 15 -Updated with new variable names


_________________________________________________________


#Preparation Steps
This cheatsheet can be used to do a vanilla development installation of Watson Speech Services 1.0.1  CP4D 2.1.0.1 with local-storage / node affinity.    It assumes you will be working from the master node.  For installing on OpenShift, please consult documentation:  
https://github.com/ibm-cloud-docs/data-readmes/blob/master/speech-README.md


Download pv script and files needed for api testing from: https://ibm.box.com/s/lxt9kx772lw85sznmhrotdmt9sr5vcby

What is your cluster name?  (load balancer address if multiple masters) 
What is the public IP of your primary master node?  
What is the private IP of your master node (fyre only)
What is your ICP Password?  Passw0rdPassw0rdPassw0rdPassw0rd
What do you want to call your deployment?


Find and replace `cp4d-clustername` with your clustername - ex: wp-wa-stt-feb23.icp.ibmcsf.net
Find and replace your `release-name` with your deployment / release name
Find and replace your `cp4d-namespace` with your Namespace name - 'zen'
Find and replace your `icp-password` with your Namespace name - 'Passw0rdPassw0rdPassw0rdPassw0rd'
Find and replace your `public_master_ip` with your public ip address


ICP Console Admin URL:https://cp4d-clustername:8443/console/welcome
Cloud Pak Admin URL:  https://cp4d-clustername:31843
CLI Login: cloudctl login -a https://cp4d-clustername:8443 --skip-ssl-validation -u admin -p icp-password

_________________________________________________________
#Speech Services Storage

Storage options are Gluster/NFS (minio only) / local-storage, vSphere volumes or Portworx.

WARNING!  
Local-storage should be used for non production environments only.  


_________________________________________________________

#Setup Client for ICP

Modify Local Hosts for ICP cluster if not in DNS
-sudo nano /etc/hosts
-add the provided cluster ip address, save and exit:
example:  
9.30.251.234     mycluster.icp


_________________________________________________________

#Install

#SSH to master - will do installation there
ssh root@public_master_ip

#Login to ICP Cluster 
cloudctl login -a https://cp4d-clustername:8443 --skip-ssl-validation -u admin -p icp-password

Select the zen namespace for now

#SKIP this step unless you are installing to a Namespace other than Zen 
kubectl create namespace cp4d-namespace
cloudctl login -a https://cp4d-clustername:8443 --skip-ssl-validation -u admin -p icp-password

#Run Healthcheck  
cd /ibm/InstallPackage/utils/ICP4D-Support-Tools
./icp4d_tools.sh --health


#Verify ICP cluster meets minimum requirements for # workers, memory and cores.  
x86 processors 

`kubectl get nodes`

`kubectl get nodes -o=jsonpath="{range .items[*]}{.metadata.name}{'\t'}{.status.allocatable.memory}{'\t'}{.status.allocatable.cpu}{'\n'}{end}"`


#Download Watson Package and Language pack if supporting languages other than English and transfer to master node 

Release info here: https://apps.na.collabserv.com/wikis/home?lang=en-us#!/wiki/Wd855b33ea663_4b57_a7c7_f5e8e37c2716/page/Watson%20on%20Cloud%20Pak%20Releases

Can optionally use wget to download directly to master node if you know the url:  wget {url} --no-check-certificate  

#Setup Security Policies

#Create Custom pod security policy
Paste below to create yaml
`
cat >podsecuritypolicy.yaml <<EOF
apiVersion: extensions/v1beta1
kind: PodSecurityPolicy
metadata:
  name: ibm-speech-psp
spec:
  allowPrivilegeEscalation: false
  forbiddenSysctls:
  - '*'
  fsGroup:
    ranges:
    - max: 65535
      min: 1
    rule: MustRunAs
  requiredDropCapabilities:
  - ALL
  runAsUser:
    rule: MustRunAsNonRoot
  seLinux:
    rule: RunAsAny
  supplementalGroups:
    ranges:
    - max: 65535
      min: 1
    rule: MustRunAs
  volumes:
  - configMap
  - emptyDir
  - projected
  - secret
  - downwardAPI
  - persistentVolumeClaim
EOF
  `

#Apply podsecuritypolicy.yaml
kubectl apply -f podsecuritypolicy.yaml

#Create Cluster role
Paste below to create yaml
`
cat >clusterrole.yaml <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: ibm-speech-psp
rules:
- apiGroups:
  - extensions
  resourceNames:
  - ibm-chart-dev-psp
  resources:
  - podsecuritypolicies
  verbs:
  - use
EOF
  `

#Apply clusterrole.yaml
kubectl apply -f clusterrole.yaml


#Load the Watson Archive to the registry
#Note - you should not have http in the clustername below or load archive will fail

cloudctl catalog load-archive --registry "cp4d-clustername:8500" --archive ibm-watson-speech-prod-1.0.1.tar.gz  --repo local-charts

##Preinstall scripts
#Grab pre-install scripts from archive
wget --no-check-certificate https://cp4d-clustername:8443/helm-repo/requiredAssets/ibm-watson-speech-prod-1.1.1.tgz

#Extract tar 
tar -xvzf ibm-watson-speech-prod-1.1.1.tgz

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
 name: watson-speech-services-release-name-policy
spec:
 repositories:
    - name: "cp4d-clustername:8500/*"
      policy:
        va:
          enabled: false
EOF
`
#Apply policy.yaml
kubectl apply -f policy.yaml


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

#create required PV with affinity using custom script - requires 4 worker nodes
Download script https://ibm.box.com/s/59r9mqjoosay4x09zdbkhr1e1czkpwbf
Open 2nd terminal window and move the script to your master node
scp ./createLocalVolumePV-affinity-speech.sh root@public_master_ip:/root

Return to terminal window remoted into master node
chmod 755 createLocalVolumePV-affinity-speech.sh
./createLocalVolumePV-affinity-speech.sh

_________________________________________________________


##Command line install 

#Prepare override.yaml(s) for your installation
#Copy values.yaml to values-override.yaml, edit then move to same directory as the chart
cd ibm-watson-speech-prod directory
cp values.yaml ../values-override.yaml
cd ..

#Edit values-override.yaml 
vi values-override.yaml

#Set STT and TTS Customization on or off:
  sttCustomization: true
  ttsCustomization: false
  sttRuntime: true
  ttsRuntime: false

#Fix the following parms  
Modify global.icpDockerRepo to: cp4d-clustername:8500/cp4d-namespace
Modify global.imagePullSecretName to: sa-cp4d-namespace
Modify global.image.repository to: cp4d-clustername:8500/cp4d-namespace
Modify global.image.pullSecret to: sa-cp4d-namespace
Select / Deselect language / models

#Create speech-persistence.yaml in the ibm-watson-speech-prod directory
#Paste text below to create speech-persistence.yaml
`
cat >speech-persistence.yaml <<EOF
postgressql:
  persistence:
    enabled: true
    useDynamicProvisioning: false
    storageClassName: local-storage-local
  dataPVC:
    selector:
      label: "dedication"
      value: "speech-postgres"
rabbitmqHA:
  replicas: 3
  persistentVolume:
    enabled: true
    useDynamicProvisioning: false
    storageClassName: local-storage-local
  dataPVC:
    selector:
      label: "dedication"
      value: "speech-rabbitmq"
EOF
`



#Install
helm install --tls --values values-override.yaml,speech-persistence.yaml --namespace cp4d-namespace --name release-name ibm-watson-speech-prod

#Wait for all pods to become ready.  
Open up a second terminal window and use watch command below to see the progress.
watch kubectl get job,pod,svc,secret,cm,pvc --namespace cp4d-namespace -l release=release-name

#To check status of your deployment
helm status --tls release-name --debug

#Provision your instance(s)
Login to Cloud Pak Cluster:  https://cp4d-clustername:31843   credentials:  admin / pw: password
Click on Add On icon in upper right hand corner
Go to your addon
Select Provision Instance
Select Create Instance and give it a name 
Repeat if you installed both STT and TTS

_________________________________________________________

#Verify deployment

#Run Test chart 
helm test --tls release-name

Note:  To delete pods from prior test chart execution, run with  --cleanup flag then you can run again with or without flag.
helm test --tls release-name --cleanup

#To check values used for your deployment
helm get values release-name --tls

#Test via API

#Find STT Token and API endpoint 
Login to Cloud Pak Cluster:  https://cp4d-clustername:31843   credentials:  admin / pw: icpd-password
Click on Hamburger and go to My Instances, Provisioned Instances
For your Instance, Select ... far right of Start Date  and View Details
Copy Access Token to clipboard
export TOKEN=youraccesstoken
Copy URL to clipboard
export API_URL=your api endpoint

#Capture STT TOKEN and service endpoint for documentation
echo $TOKEN >stt_release-name_TOKEN.out
echo $TOKEN
echo $API_URL >stt_release-name_endpoint_url
echo $API_URL
 
#STT API Commands

Change into the directory with the pv script and files needed for api testing and run the commands below
https://ibm.box.com/s/lxt9kx772lw85sznmhrotdmt9sr5vcby


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
export language_customization_id=

4) View Customizations - Verify that the model was created - will show in pending state
curl -H "Authorization: Bearer $TOKEN" -k "$API_URL/v1/customizations"


5) Add a Corpus to the language model
curl -H "Authorization: Bearer $TOKEN" -k -X POST  --data-binary @IT-corpora.txt "$API_URL/v1/customizations/${language_customization_id}/corpora/corpus1"


6) View the corpora
curl -H "Authorization: Bearer $TOKEN" -k -X GET "$API_URL/v1/customizations/${language_customization_id}/corpora/corpus1"

7) Add OOV words dictionary
curl -H "Authorization: Bearer $TOKEN" -k -X POST --header "Content-Type: application/json" --data @words_list.json "$API_URL/v1/customizations/${language_customization_id}/words"


8) Verify that the OOV words dictionary was successfully added
curl -H "Authorization: Bearer $TOKEN" -k -X GET "$API_URL/v1/customizations/${language_customization_id}/words"


9) Train the custom language model
curl -H "Authorization: Bearer $TOKEN" -k -X POST "$API_URL/v1/customizations/${language_customization_id}/train"


10) View Customizations - Verify that the language model training is complete and the model moves into the "available" status
curl -H "Authorization: Bearer $TOKEN" -k -X GET "$API_URL/v1/customizations"


11) Transcribe with trained language model -the transcription should return "JSON" and not "J. son"
curl -H "Authorization: Bearer $TOKEN" -k -X POST --header "Content-Type: audio/wav" --data-binary @JSON.wav "$API_URL/v1/recognize?timestamps=true&word_alternatives_threshold=0.9&language_customization_id=${language_customization_id}&customization_weight=0.8"


12) Create an acoustic model
curl -H "Authorization: Bearer $TOKEN" -k -X POST --header "Content-Type: application/json" --data "{\"name\": \"Custom Acoustic Model by Victor Povar v1\", \"base_model_name\": \"en-US_BroadbandModel\", \"description\": \"Custom Acoustic Model by Victor Povar v1\"}" "$API_URL/v1/acoustic_customizations"

#set your acoustic customization ID from the previous command response
export acoustic_customization_id=


13) List en-US acoustic model - Verify that the acoustic model was created
curl -H "Authorization: Bearer $TOKEN" -k -X GET "$API_URL/v1/acoustic_customizations?language=en-US"


14) Add audio files to the acoustic model
curl -H "Authorization: Bearer $TOKEN" -k -X POST --header "Content-Type: application/zip" --data-binary @sample.zip "$API_URL/v1/acoustic_customizations/${acoustic_customization_id}/audio/audio1"


15) List audio resources
curl -H "Authorization: Bearer $TOKEN" -k -X GET "$API_URL/v1/acoustic_customizations/${acoustic_customization_id}/audio"

Notes: Ensure that the files added to the acoustic model exceed 10 minutes (minimum required to train an acoustic model) and that all audio files were successfully processed

16) Train an acoustic model with a language model
curl -H "Authorization: Bearer $TOKEN" -k -X POST "$API_URL/v1/acoustic_customizations/${acoustic_customization_id}/train?custom_language_model_id=${language_customization_id}"


17) View Acoustic Model Status
curl -H "Authorization: Bearer $TOKEN" -k -X GET "$API_URL/v1/acoustic_customizations?language=en-US"

Notes: Verify that the acoustic model training is complete and the model moves into the available Status

18) Transcribe the audio file with the acoustic and language model, ensure that a valid transcription is returned
curl -H "Authorization: Bearer $TOKEN" -k -X POST --header "Content-Type: audio/wav" --data-binary @JSON.wav "$API_URL/v1/recognize?timestamps=true&word_alternatives_threshold=0.9&language_customization_id=${language_customization_id}&customization_weight=0.8&acoustic_customization_id=${acoustic_customization_id}"


19) Add a grammar to a language model
curl -H "Authorization: Bearer $TOKEN" -k -X POST --header "Content-Type: application/srgs" --data-binary @YesNo.abnf "$API_URL/v1/customizations/${language_customization_id}/grammars/{grammar_name}"


20) Monitor grammars - Verify that the grammar was created.  Status will go from being_processed to analyzed.
curl -H "Authorization: Bearer $TOKEN" -k -X GET "$API_URL/v1/customizations/${language_customization_id}/grammars/{grammar_name}"


21) Retrain the custom language model now with grammar
curl -H "Authorization: Bearer $TOKEN" -k -X POST "$API_URL/v1/customizations/${language_customization_id}/train"


22) Monitor custom language model training with grammar   (takes a few mins)
curl -H "Authorization: Bearer $TOKEN" -k -X GET "$API_URL/v1/customizations"

Notes: Verify that the language model training successfully completes


23) Transcribe with a grammar 
curl -H "Authorization: Bearer $TOKEN" -k -X POST --header "Content-Type: audio/wav" --data-binary @JSON.wav "$API_URL/v1/recognize?customization_id=${language_customization_id}&language_customization_enabled={grammar_name}&language_customization_weights=0.7"

Notes: Transcribe an audio file with the new language model that contains a grammar, since the audio file is not tailored to the grammar, it is normal to receive hypothesis of 0.0

24) Delete a language model
curl -H "Authorization: Bearer $TOKEN" -k -X DELETE "$API_URL/v1/customizations/${language_customization_id}"


25) Delete an acoustic model
curl -H "Authorization: Bearer $TOKEN" -k -X DELETE "$API_URL/v1/acoustic_customizations/${acoustic_customization_id}"


#TTS API Commands
#Find TTS Token and API endpoint 
Login to Cloud Pak Cluster:  https://cp4d-clustername:31843   credentials:  admin / pw: icpd-password
Click on Hamburger and go to My Instances, Provisioned Instances
For your Instance, Select ... far right of Start Date  and View Details
Copy Access Token to clipboard
export TOKEN=youraccesstoken
Copy URL to clipboard
export API_URL=your api endpoint

#Capture TTS TOKEN and service endpoint for documentation
echo $TOKEN >tts_release-name_TOKEN.out
echo $TOKEN
echo $API_URL >tts_release-name_endpoint_url
echo $API_URL


#View Voices
curl -H "Authorization: Bearer $TOKEN" -k $API_URL/v1/voices

#Test Voices
1) Set the voice to one of your languages from the previous command response
export voice=

examples:
export voice=en-US_LisaV3Voice
export voice=en-US_MichaelV3Voice
export voice=en-US_AllisonV3Voice

2) Run curl command to transcribe to audio
curl -k -X POST --header "Authorization: Bearer $TOKEN" --header "Content-Type: application/json" --header "Accept: audio/wav" --data "{\"text\":\"Hello world\"}" --output $voice.wav "$API_URL/v1/synthesize?voice=$voice"

3) Browse to the wav file on your computer and double click to play the wav file and hear the voice.

4) Repeat and test all of your available voices by setting the voice variable and repeating the curl command:

export voice=

curl -k -X POST --header "Authorization: Bearer $TOKEN" --header "Content-Type: application/json" --header "Accept: audio/wav" --data "{\"text\":\"Hello world\"}" --output $voice.wav "$API_URL/v1/synthesize?voice=$voice"

_________________________________________________________

#Capture information about deployment / gather baseline information (Highly recommended)

Download icpCollector script and copy to Master node (ibm directory): https://ibm.box.com/s/q87wpr3vy92u46cmywue7m69ri13zjyx

#Run icpcollector from Masternode
./icpCollector_without_jq.sh -c cp4d-clustername -a id-mycluster-account -n cp4d-namespace -u admin -p icp-password

   or 

kubectl get nodes --show-labels >cp4d-clustername_nodes.txt

`kubectl get nodes -o=jsonpath="{range .items[*]}{.metadata.name}{'\t'}{.status.allocatable.memory}{'\t'}{.status.allocatable.cpu}{'\n'}{end}" >cp4d-clustername_compute.txt`

kubectl get pods -o wide -l release=release-name >cp4d-clustername_pods.txt

helm status --tls release-name >cp4d-clustername_helm_status.txt

kubectl describe nodes>describe_nodes.txt

helm get release-name --tls >helm_release_cp4d-clustername.txt

helm get values release-name --tls >helm_values_cp4d-clustername.txt

_________________________________________________________


#To modify deployment - add models, or languages 
Note:  To enable STT or TTS after Speech services has been deployed, you must reinstall; upgrade will not perform required pre-hooks 


_________________________________________________________

###to Delete Deployment 

#Delete Instance(s) from My Instances Page 

Login to Cloud Pak Cluster:  https://cp4d-clustername:31843   credentials:  admin / pw: password
Click on Hamburger, go to My Instances
Click on ... to right of Start date and select Delete
Confirm
Repeat for other speech (TTS or STT) instance if both were installed

#Delete Deployment
helm delete --tls --purge release-name 

#Post uninstall cleanup
#see what's left:
kubectl get job,deploy,rs,pod,statefulset,configmap,secret,ingress,service,serviceaccount,role,rolebinding,pvc,poddisruptionbudget --selector=release=release-name --namespace=cp4d-namespace 

#then Delete
kubectl delete job,deploy,rs,pod,statefulset,configmap,secret,ingress,service,serviceaccount,role,rolebinding,pvc,poddisruptionbudget --selector=release=release-name --namespace=cp4d-namespace --grace-period=0 --force

#To remove the configmap
kubectl delete cm stolon-cluster-release-name-postgressql


#Delete the PVs 

`kubectl delete persistentvolumes $(kubectl get persistentvolumes \
  --output=jsonpath='{range .items[*]}{@.metadata.name}:{@.status.phase}:{@.spec.claimRef.name}{"\n"}{end}' \
  | grep ":Released:" \
  | grep "release-name-" \
  | cut -d ':' -f 1)
`

#Delete the local-storage data on the worker nodes

#Get a list of the worker IPs
kubectl get nodes | grep worker  | awk '{ print $1 }'

#Remote into each worker and remove the /mnt point for each PV:
ssh root@workeripaddr
ls /mnt/local-storage/storage/watson/speech/
rm -r -f /mnt/local-storage/storage/watson/speech/
exit

#Run command below to purge the ICP4D Addon service instance database if you intend to re-use the release name on a future install

kubectl -n zen exec zen-metastoredb-0 \
  -- sh /cockroach/cockroach.sh sql \
  --insecure -e "DELETE FROM zen.service_instances WHERE deleted_at IS NOT NULL RETURNING id;" \
  --host='zen-metastoredb-public'

