Speech v1.1.0 on 3.1.0 

v7 Update April 23:  added workaround to minio chart problem
v6 Updates March 27:
Added step to capture chart secret, updated deletion to include remove localstorage data

_________________________________________________________


#Preparation Steps

#Reference

Find and replace `icp-clustername` with your clustername - ex: assistant-jwales-dec.icp.ibmcsf.net
Find and replace your `icp-deployment-name` with your deployment name
Find and replace your `icp-namespace` with your Namespace name

ICP Cluster Admin URL:  https://icp-clustername:8443/console/welcome

_________________________________________________________


#Setup Client for ICP
Create Local Hosts for ICP cluster if not in DNS 
Install ICP / Helm / Kubectl CLIs https://icp-clustername:8443/console/tools/cli
Download scripts and save to /speech https://ibm.box.com/s/n1mt595th9ja1p0gl0dnvbsamyidyknu
Download sample files and save to /speech/api-testing https://ibm.box.com/s/lxt9kx772lw85sznmhrotdmt9sr5vcby
Download Speech Archive and save to /speech

Optionally install Watch on your mac -  useful for watching services come up (http://osxdaily.com/2010/08/22/install-watch-command-on-os-x/)

_________________________________________________________

#Docker & clusters with self signed certificates
If self signed cert is used for cluster, Docker login will fail with certificate error.  To workaround, create daemon.json in the docker directory on your client with the icp clustername listed under insecure-registries & restart Docker.

#Sample daemon.json
{
  "debug" : true,
  "experimental" : true,
  "insecure-registries" : [
    "mycluster.icp:8500"
  ]
}

#Mac Instructions
copy daemon.json to `~/.docker/ directory`   Users/username/.docker
Command R to restart


#Linux Instructions
cp daemon.json to /etc/docker directory
sudo service docker stop
sudo service docker start

_________________________________________________________


#Install

#Login to ICP Cluster 
cloudctl login -a https://icp-clustername:8443 --skip-ssl-validation -u admin -p admin

#Verify CLI - try command to show nodes in your cluster:
`kubectl get nodes --show-labels`

#Login to docker  
docker login https://icp-clustername:8500

#Create Namespace 
kubectl create namespace icp-namespace
Login to cluster again and select icp-namespace namespace

#Create Storage class `local-storage`
change into the speech directory where you downloaded the script and yaml files
kubectl create -f local-storage.yaml

#Create required PVs
(4 pvs for 1.1.0 STT)
./pv.sh 

#Create the minio Secret (uses default admin / admin1234 base 64 encoding)
kubectl create -f secret.yaml

#Create datastores-secrets to access the Postgres and RabbitMQ datastores
kubectl create -f postgres-secrets.properties
 
#Share the user credentials with the Postgres chart
kubectl create -f postgrescreds.yaml

#Load the Watson Archive to the Docker registry
#Note - there is a problem with the GA 1.1.0 code that causes it to fail when uploading to the docker registry with the error: `Error response from daemon:  No such image:  radial/busyboxplus:curl`

From speech directory where archive resides:

mkdir extracted_archive
tar -xzvf IBM_WATSON_SPEECH_TO_TEXT_CUSTOME.tar.gz -C extracted_archive
docker load -i extracted_archive/images/71fa7369f43748b8c5e3578aa46141502da770a967455d1071498b714bb0f089.tar.gz
docker tag watson_nlu/curl:4.0.0 radial/busyboxplus:curl
rm -rf extracted_archive

#Upload archive
From the /speech directory
cloudctl catalog load-archive --registry "icp-clustername:8500" --archive IBM_WATSON_SPEECH_TO_TEXT_CUSTOME.tar.gz

#Backup the Archive Secret
kubectl get secret sa-icp-namespace -n icp-namespace --export -o yaml > chartsecret.yaml


#Perform Catalog install 
Login to admin ui with browser https://icp-clustername:8443
Click on Catalog
Search for Watson Service
Select Watson Servie
Click Configure
Set Helm release name to icp-deployment-name
Set Target namespace to icp-namespace
Accept license

Expand other parameters
deselect unnecessary language / models
Select dynamic memory calculation
Reduce cpu counts for stt runtime & am patcher to 4
Note:  Minio persistent volume size must match PV size (100G)
Set postgreSQL name of secrets object containing credentials to: user-provided-postgressql (or whatever you set in yaml)

Install

_________________________________________________________

#Verify deployment

Wait for all pods to become ready. You can keep track of the pods either through the dashboard or through the command line interface:

kubectl get pods -l release=icp-deployment-name -n icp-namespace

#If you have watch installed:
watch kubectl get job,pod,svc,secret,cm,pvc --namespace icp-namespace


#To check status of your deployment
helm status --tls icp-deployment-name --debug

_________________________________________________________

#Workaround for problem with Minio chart deploying on Master / Proxy / or Management nodes

The Minio chart has a toleration that allows it to be deployed to a non worker node.  To verify where the chart was deployed, run the following commands to see what node (IP) the minio pod was deployed to.

kubectl get nodes
kubectl get pods -o wide

If deployed to non-worker node, you can edit the Minio Deployment via Kubernetes and restart the service to resolve the problem.

#Set depl to your deployment name
export depl=icp-deployment-name

#Edit the minio deployment
kubectl edit deployments/$depl-minio #file opens with VI editor

#Under tolerations, remove the following lines, save and exit
```
	{
	"key": "dedicated",
	"operator": "Exists"
	}
```

#Scale the minio service to 0
kubectl scale deployments/$depl-minio --replicas=0

#Scale the minio service back to 1
kubectl scale deployments/$depl-minio --replicas=1

#Verify Minio is running on a worker node
kubectl get nodes
kubectl get pods -o wide

_________________________________________________________

#Run Test chart
helm test --tls icp-deployment-name

Note:  To delete pods from prior test chart execution, run with  --cleanup flag then you can run again with or without flag.
helm test --tls icp-deployment-name --cleanup





	
##Test via API
Change into directory with sample files /speech/api-testing and run commands below 

#Retrieve the API key Linux:
export API_KEY=$(kubectl get secret speech-to-text-serviceid-secret  -o jsonpath="{.data.api_key}" | base64 -d)

#Retrieve the API key Mac / windows:
export API_KEY=$(kubectl get secret speech-to-text-serviceid-secret  -o jsonpath="{.data.api_key}" | base64 -D)

#set clusterip
export CLUSTER_IP=$(kubectl get nodes | grep proxy | awk 'NR==1{match($0,/[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/); ip = substr($0,RSTART,RLENGTH); print $1}')


#Capture api key and service endpoint for documentation 
echo $API_KEY >icp-deployment-name_API_KEY.out
echo $API_KEY
echo $CLUSTER_IP
echo "https://${CLUSTER_IP}/speech-to-text/api" >icp-deployment-name_endpoint_url.out
echo "https://${CLUSTER_IP}/speech-to-text/api"


1) View Models

curl -k -u "apikey:${API_KEY}" https://${CLUSTER_IP}/speech-to-text/api/v1/models 
Notes: Should return broadband and narrowband models per language installed, US English will also contain a short form narrowband model, this model is optimized for IVR use cases.


2) Transcribe
curl -k -X POST -u "apikey:${API_KEY}" --header "Content-Type: audio/wav" --data-binary @JSON.wav "https://${CLUSTER_IP}/speech-to-text/api/v1/recognize?timestamps=true&word_alternatives_threshold=0.9"
Notes: Transcribe the provided audio file with the base US English broadband model

3) Create a custom language model
curl -k -X POST -u "apikey:${API_KEY}" --header "Content-Type: application/json" --insecure --data "{\"name\": \"CustomLanguageModelVP_v1\", \"base_model_name\": \"en-US_BroadbandModel\", \"description\": \"Custom Language Model by Victor Povar v1\"}" "https://${CLUSTER_IP}/speech-to-text/api/v1/customizations"
Notes: Create a custom language mode, note the language model id and replace all instances of "{language_customization_id}" with the returned model id

#set your language customization ID from the previous command response
export language_customization_id=

4) View Customizations
curl -k -X GET -u "apikey:${API_KEY}" "https://${CLUSTER_IP}/speech-to-text/api/v1/customizations"
Notes: Verify that the model was created - will show in pending state


5) Add a Corpus
curl -k -X POST -u "apikey:${API_KEY}" --data-binary @IT-corpora.txt "https://${CLUSTER_IP}/speech-to-text/api/v1/customizations/${language_customization_id}/corpora/corpus1"
Notes: Add a corpus to the language model

6) View the corpora
curl -k -X GET -u "apikey:${API_KEY}" "https://${CLUSTER_IP}/speech-to-text/api/v1/customizations/${language_customization_id}/corpora/corpus1"
Notes: Verify that the corpus was added to the language model. Status of analyzed is expected.   If it seems stuck in "being_processed" for more than 30 minutes then perform the instructions in the "Steps to Resolve a DB connection issue.txt" document

7) Add OOV Dictionary
curl -k -X POST -u "apikey:${API_KEY}" --header "Content-Type: application/json" --data @words_list.json "https://${CLUSTER_IP}/speech-to-text/api/v1/customizations/${language_customization_id}/words"
Notes: Add an OOV words dictionary

8) View the OOV words
curl -k -X GET -u "apikey:${API_KEY}" "https://${CLUSTER_IP}/speech-to-text/api/v1/customizations/${language_customization_id}/words"
Notes: Verify that the OOV words dictionary was successfully added

9) Train the custom language model
curl -k -X POST -u "apikey:${API_KEY}" "https://${CLUSTER_IP}/speech-to-text/api/v1/customizations/${language_customization_id}/train"
Notes: Train the language model

10) View Customizations
curl -k -X GET -u "apikey:${API_KEY}" "https://${CLUSTER_IP}/speech-to-text/api/v1/customizations"
Notes: Verify that the language model training is complete and the model moves into the available Status

11) Transcribe with language model
curl -k -X POST -u "apikey:${API_KEY}" --header "Content-Type: audio/wav" --data-binary @JSON.wav "https://${CLUSTER_IP}/speech-to-text/api/v1/recognize?timestamps=true&word_alternatives_threshold=0.9&language_customization_id=${language_customization_id}&customization_weight=0.8"
Notes: Transcribe an audio file with the trained language model, the transcription should return "JSON" and not "J. son"

12) Create an acoustic model
curl -k -X POST -u "apikey:${API_KEY}" --header "Content-Type: application/json" --data "{\"name\": \"Custom Acoustic Model by Victor Povar v1\", \"base_model_name\": \"en-US_BroadbandModel\", \"description\": \"Custom Acoustic Model by Victor Povar v1\"}" "https://${CLUSTER_IP}/speech-to-text/api/v1/acoustic_customizations"
Notes: Create an acoustic model, note the acoustic model id and replace all instances of {acoustic_customization_id} with the returned acoustic model id


13) List en-US acoustic model
curl -k -X GET -u "apikey:${API_KEY}" "https://${CLUSTER_IP}/speech-to-text/api/v1/acoustic_customizations?language=en-US"
Notes: Verify that the acoustic model was created

#set your acoustic customization ID from the previous command response
export acoustic_customization_id=

14) Add audio resource
curl -k -X POST -u "apikey:${API_KEY}" --header "Content-Type: application/zip" --data-binary @sample.zip "https://${CLUSTER_IP}/speech-to-text/api/v1/acoustic_customizations/${acoustic_customization_id}/audio/audio1"
Notes: Add audio files to the acoustic model

15) List audio resources
curl -k -X GET -u "apikey:${API_KEY}" "https://${CLUSTER_IP}/speech-to-text/api/v1/acoustic_customizations/${acoustic_customization_id}/audio"
Notes: Ensure that the files added to the acoustic model exceed 10 minutes (minimum required to train an acoustic model) and that all audio files were successfully processed

16) Train an acoustic model with a language model
curl -k -X POST -u "apikey:${API_KEY}" "https://${CLUSTER_IP}/speech-to-text/api/v1/acoustic_customizations/${acoustic_customization_id}/train?custom_language_model_id=${language_customization_id}"
Notes: Train the acoustic model

17) View Acoustic Model Status
curl -k -X GET -u "apikey:${API_KEY}" "https://${CLUSTER_IP}/speech-to-text/api/v1/acoustic_customizations?language=en-US"
Notes: Verify that the acoustic model training is complete and the model moves into the available Status

18) Transcribe with language model and acoustic model
curl -k -X POST -u "apikey:${API_KEY}" --header "Content-Type: audio/wav" --data-binary @JSON.wav "https://${CLUSTER_IP}/speech-to-text/api/v1/recognize?timestamps=true&word_alternatives_threshold=0.9&language_customization_id=${language_customization_id}&customization_weight=0.8&acoustic_customization_id=${acoustic_customization_id}"
Notes: Transcribe the audio file with the acoustic and language model, ensure that a valid transcription is returned

19) Add a grammar to a language model
curl -k -X POST -u "apikey:${API_KEY}" --header "Content-Type: application/srgs" --data-binary @YesNo.abnf "https://${CLUSTER_IP}/speech-to-text/api/v1/customizations/${language_customization_id}/grammars/{grammar_name}"
Notes: Create a new grammar, replace all instances of {grammar_name} with the name of the grammar

20) Monitor grammars
curl -k -X GET -u "apikey:${API_KEY}" "https://${CLUSTER_IP}/speech-to-text/api/v1/customizations/${language_customization_id}/grammars/{grammar_name}"
Notes: Verify that the grammar was created.  Status will go from being_processed to analyzed.

21) Train the custom language model
curl -k -X POST -u "apikey:${API_KEY}" "https://${CLUSTER_IP}/speech-to-text/api/v1/customizations/${language_customization_id}/train"
Notes: Train the language model, since grammar is an extention of the language model, the language model has to be retrained for the grammar to be available

22) Monitor custom language model training with grammar
curl -k -X GET -u "apikey:${API_KEY}" "https://${CLUSTER_IP}/speech-to-text/api/v1/customizations"
Notes: Verify that the language model training successfully completes


23) Transcribe with a grammar
curl -k -X POST -u "apikey:${API_KEY}" --header "Content-Type: audio/wav" --data-binary @JSON.wav "https://${CLUSTER_IP}/speech-to-text/api/v1/recognize?customization_id=${language_customization_id}&language_customization_enabled={grammar_name}&language_customization_weights=0.7"
Notes: Transcribe an audio file with the new language model that contains a grammar, since the audio file is not tailored to the grammar, it is normal to receive hypothesis of 0.0

24) Delete a language model
curl -k -X DELETE -u "apikey:${API_KEY}" "https://${CLUSTER_IP}/speech-to-text/api/v1/customizations/${language_customization_id}"
Notes: Remove the language model

25) Delete an acoustic model
curl -k -X DELETE -u "apikey:${API_KEY}" "https://${CLUSTER_IP}/speech-to-text/api/v1/acoustic_customizations/${acoustic_customization_id}"
Notes: Remove the acoustic model
_________________________________________________________

#Speech Analytics
If you have Speech Analytics installed, perform the tests below to validate, otherwise skip to collecting docs
_________________________________________________________

1) Transcribe with Speech Analytics.
Note: Speech Analytic requests are processed in batch mode on a collection of audio files that are uploaded to a Cloud Object Storage (COS). Speech Analytics supports the use of any COS server that is compatible with Amazon S3, such as Minio or IBM Cloud Object Storage, additional details for how to create the COS as well as populate the credentials file can be found here: https://cloud.ibm.com/docs/services/speech-to-text-icp?topic=speech-to-text-icp-batch#batchCOS

curl -k -X POST -u "apikey:${API_KEY}" --header "Content-Type: multipart/form-data" --form input_credentials_file=@my_cos_credentials.json --form input_bucket_location={bucket_location} --form input_bucket_name={bucket_name} "https://${CLUSTER_IP}/speech-to-text/api/v1/batches?function=recognize&speech_analytics=true"

Note: It is possible to add a custom language, acoustic model to the above request. The service will always set the following parameters to true: speaker_labels and timestamps. The service will ignore the following parameters: base_model_version, grammar_name, keywords, keywords_threshold, max_alternatives and. word_alternatives_threshold
 

2) List batch-processing jobs, the jobs can also be viewed via GUI, details instruction on how to view the job status via the GUI can be found here: https://cloud.ibm.com/docs/services/speech-to-text-icp?topic=speech-to-text-icp-batch#batchCheckGUI
curl -k -X GET -u "apikey:${API_KEY}" "https://${CLUSTER_IP}/speech-to-text/api/v1/batches"
Notes: monitor the status of the job. 
a) If the job status is "completed", navigate the COS bucket and examine the outputs. For every audio file, there will be a JSON file created with the analytics for that specific audio files. Additionally, 2 zip files: speaker.zip and conversation.zip will be created. The zip files contain cumulative conversation- and speaker-level results derived from the .json files for all input audio files. Further details for the created output files can be found here: https://cloud.ibm.com/docs/services/speech-to-text-icp?topic=speech-to-text-icp-analytics#analytics
b) If the job status is "failed", examine the associated "error_message" field to identify the cause of the failure and address it accordingly.

3) Delete a batch-processing job
curl -k -X DELETE -u "apikey:${API_KEY}" "https://${CLUSTER_IP}/speech-to-text/api/v1/batches/{batch_id}"

_________________________________________________________

#Capture information about deployment
kubectl get nodes --show-labels >icp-clustername_nodes.out

`kubectl get nodes -o=jsonpath="{range .items[*]}{.metadata.name}{'\t'}{.status.allocatable.memory}{'\t'}{.status.allocatable.cpu}{'\n'}{end}" >icp-clustername_compute.out`

helm status --tls ${icp_deploy} >icp-deployment-name_helm_status.out
kubectl describe nodes>describe_nodes.out
helm get ${icp_deploy} --tls >helm_release_icp-deployment-name.out
_________________________________________________________


##to Delete Deployment 

Two ways to delete the deployment - full and partial. 

Use Partial delete if you had install trouble and need to purge and attempt the install again without reloading the Watson chart.

Use Full delete if you want to install everything, including the Watson chart, for example if changing versions.

_____________________

#Partial Delete - Use partial delete when you need to remove everything EXCEPT the PPA Archive (chart)

#Delete the deployment
helm delete --purge --tls icp-deployment-name

#Find and remove everything in icp-namespace except secrets - when keeping chart 

`for i in `kubectl get jobs,pods,svc,cm,pvc,deploy,statefulsets,ingress -n icp-namespace| grep icp-deployment-name |awk '{print $1}'`; do kubectl delete $i -n icp-namespace --grace-period=0 --force ; done`


#Delete PVs 
cd to /speech directory
./pv.sh delete

Note:  For multiple install attempts on the same cluster, you must delete the PVs and you must delete the prior data on each of the worker nodes before attempting the reinstallation.  To do this, you will require ssh access to the worker nodes - by default, if using the provided scripts, the directory to remove is:  /mnt/local-storage/storage.    Alternately, you can choose to modify the directory path used when creating the PVs, but keep in mind that this will not release the storage space used.   

IMPORTANT:  Failure to remove the /mnt/local-storage/storage directory or change the path used with the pv.sh script will likely result in a failed install with trouble on the stateful sets - minio, mongo, postgres, etc.

____________________

#Full Delete - Use full delete when you need to remove everything INCLUDING the Watson chart and start over from scratch

#Delete the deployment
helm delete --purge --tls icp-deployment-name

#Find and remove everything in icp-namespace including secrets - only use this if reloading chart 

`for i in `kubectl get jobs,pods,svc,secret,cm,pvc,deploy,statefulsets,ingress -n icp-namespace| grep icp-deployment-name |awk '{print $1}'`; do kubectl delete $i -n icp-namespace --grace-period=0 --force ; done`

#Delete PVs 
cd to /speech directory
./pv.sh delete

Note:  For multiple install attempts on the same cluster, you must delete the PVs and you must delete the prior data on each of the worker nodes before attempting the reinstallation.  To do this, you will require ssh access to the worker nodes - by default, if using the provided scripts, the directory to remove is:  /mnt/local-storage/storage.    Alternately, you can choose to modify the directory path used when creating the PVs, but keep in mind that this will not release the storage space used.   

IMPORTANT:  Failure to remove the /mnt/local-storage/storage directory or change the path used with the pv.sh script will likely result in a failed install with trouble on the stateful sets - minio, mongo, postgres, etc.

#Delete Chart
Cloudctl catalog delete-helm-chart --name ibm-watson-speech-prod

#Delete Namespace
kubectl delete namespace icp-namespace


