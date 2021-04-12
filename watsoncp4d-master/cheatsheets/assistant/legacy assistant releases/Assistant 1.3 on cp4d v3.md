WA 1.3 on Cloud pak for data 2.1.0.1 as a premium add on

Updates Sept 10
Updated with new variable names
Fixed typo in install line

_________________________________________________________


#Preparation Steps
This cheatsheet can be used to do a vanilla development installation of Watson Assistant 1.3 on CP4D 2.1.0.1 with local-storage / node affinity.    It assumes you will be working from the master node.  For installing on OpenShift, please consult documentation:  https://cloud.ibm.com/docs/services/assistant-data?topic=assistant-data-install-130#install-130-choose-cluster

What is your cluster name?  (load balancer address if multiple masters)
What is the public IP of your primary master node?  
What is the private IP of your master node (fyre)
What is your ICP Password?  Passw0rdPassw0rdPassw0rdPassw0rd
What do you want to call your deployment?


Find and replace `cp4d-clustername` with your clustername - ex: wp-wa-stt-feb23.icp.ibmcsf.net
Find and replace your `release-name` with your deployment name
Find and replace your `cp4d-namespace` with your Namespace name 
Find and replace your `icp-password` with your Namespace name - 'Passw0rdPassw0rdPassw0rdPassw0rd'
Find and replace your `public_master_ip` with your public ip address


ICP Console Admin URL:https://cp4d-clustername:8443/console/welcome
Cloud Pak Admin URL:  https://cp4d-clustername:31843
CLI Login: cloudctl login -a https://cp4d-clustername:8443 --skip-ssl-validation -u admin -p icp-password


_________________________________________________________
#Assistant Storage

Storage options are local-storage, vSphere volumes or Portworx.

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

Select the default namespace for now

#Run Healthcheck on your cluster and check for trouble.  
cd /ibm/InstallPackage/utils/ICP4D-Support-Tools
./icp4d_tools.sh --health


#Verify ICP cluster meets minimum requirements for # workers, memory and cores
x86 processors / AVX support -Assistant only

`kubectl get nodes`

`kubectl get nodes -o=jsonpath="{range .items[*]}{.metadata.name}{'\t'}{.status.allocatable.memory}{'\t'}{.status.allocatable.cpu}{'\n'}{end}"`

#SKIP this step unless you are installing to a Namespace other than Zen 
kubectl create namespace cp4d-namespace
cloudctl login -a https://cp4d-clustername:8443 --skip-ssl-validation -u admin -p icp-password

#Download Watson Package and transfer to master node 

Release info here: https://apps.na.collabserv.com/wikis/home?lang=en-us#!/wiki/Wd855b33ea663_4b57_a7c7_f5e8e37c2716/page/Watson%20on%20Cloud%20Pak%20Releases

Can optionally use wget to download directly to master node if you know the url:  wget {url} --no-check-certificate 


#Load the Watson Archive to the registry
Note - you should not have http in the clustername below or load archive will fail.  If using NFS, your load-archive may fail mid way.  Just restart and repeat until all of the images have loaded.

cloudctl catalog load-archive --registry "cp4d-clustername:8500" --archive ibm-watson-assistant-prod-1.3.0.tar.gz  --repo local-charts

##Preinstall scripts
#Grab pre-install scripts from archive
wget --no-check-certificate https://cp4d-clustername:8443/helm-repo/requiredAssets/ibm-watson-assistant-prod-1.3.0.tgz

#Extract tar
tar -xvf ibm-watson-assistant-prod-1.3.0.tgz


#Run pre-install scripts
#Setup Security Policies
cd ibm-watson-assistant-prod/ibm_cloud_pak/pak_extensions/pre-install/namespaceAdministration
./createSecurityNamespacePrereqs.sh cp4d-namespace


#Label Zen namespace
kubectl label --overwrite namespace/zen ns=zen

#Check zen label with:
kubectl get namespace zen --show-labels

#Create the image Policy
#Paste text below to create policy.yaml
`
cat > policy.yaml << EOF
apiVersion: securityenforcement.admission.cloud.ibm.com/v1beta1
kind: ClusterImagePolicy
metadata:
 name: watson-assistant-release-name-policy
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

#Verify policy:  
kubectl get ClusterImagePolicy -o yaml

#Get your worker IPs:
kubectl get nodes | grep worker  | awk '{ print $1 }'

#create required PV with affinity using provided script in clusterAdministration directory
Script requires 4 IP addresses.   If you have less than 4 workers, repeat same worker IPs until you have 4 but note, your cluster may not survive a worker node outage.


Example:
./createLocalVolumePV.sh --release wa131 --path /mnt/local-storage/storage/watson/assistant --nodeAffinities 172.16.19.119,172.16.20.199,172.16.21.72,172.16.24.37

cd ../clusterAdministration
./createLocalVolumePV.sh --release release-name --path /mnt/local-storage/storage/watson/assistant --nodeAffinities {workerip},{workerip},{workerip},{workerip}

#Verify PVs were created:
kubectl get persistentvolumes -l release=release-name --show-labels


_________________________________________________________

##Command line install 

#Prepare override yaml files
#Copy values.yaml to values-override.yaml, edit then move to same directory as the chart
Navigate back to ibm-watson-assistant-prod directory
cd ../../../../
cp values.yaml ../values-override.yaml
cd ..
vi values-override.yaml

Set global.deploymentType to Development or Production 
Set MasterHostname to the ip of the load balancer:  cp4d-clustername
Set master-ip to the ip of master node: public_master_ip  #IMPT FYRE must be set to private IP
Set license to accept
Deselect Czech
Verify the image paths are set to your cluster:  cp4d-clustername/cp4d-namespace

#Create wa-persistence.yaml in the ibm-watson-assistant-prod directory
#Paste text below to create wa-persistence.yaml
`
cat >wa-persistence.yaml <<EOF
cos:  
 minio:    
  persistence:      
   useDynamicProvisioning: false      
   selector:        
    label: "dedication"        
    value: "wa-release-name-minio"
etcd:  
 config:    
  persistence:      
   useDynamicProvisioning: false    
  dataPVC:      
   selector:        
    label: "dedication"        
    value: "wa-release-name-etcd"
postgres:  
 config:    
  persistence:      
   useDynamicProvisioning: false    
  dataPVC:      
   selector:        
    label: "dedication"        
    value: "wa-release-name-postgres"
mongodb:  
 config:    
  persistentVolume:      
   useDynamicProvisioning: false      
  selector:        
   label: "dedication"        
   value: "wa-release-name-mongodb"
EOF
`

#Set targeted namespace
cloudctl target -n cp4d-namespace

#Install
helm install --tls --values values-override.yaml,wa-persistence.yaml --namespace cp4d-namespace --name release-name ibm-watson-assistant-prod-1.3.0.tgz


#Wait for all pods to become ready. This will take 30-45 mins.  
Open up a second terminal window and use watch command below to see the progress.
watch kubectl get job,pod,svc,secret,cm,pvc --namespace cp4d-namespace -l release=release-name

#To check status of your deployment
helm status --tls release-name --debug

#Provision your instance
Login to Cloud Pak Cluster:  https://cp4d-clustername:31843   credentials:  admin / pw: password
Click on Add On icon in upper right hand corner
Go to your addon
Select Provision Instance

Select Create Instance and give it a name 

_________________________________________________________

#Verify deployment

#Run Test chart
helm test --tls release-name

Note:  To delete pods from prior test chart execution, run with  --cleanup flag then you can run again with or without flag.
helm test --tls release-name -cleanup

#To check values used for your deployment
helm get values release-name --tls

#Verify tooling 
Login to Tooling with Cloud Pak credentials:  admin / pw: password
https://cp4d-clustername:31843/assistant/release-name

Go to Skills
Create Skill, Dialog Skill, Next
Select to Use Sample Skill
Click the Sample Skill and it will open 
Click Try it panel and make sure it understands you - type hello (after training completes)

Go to Assistants (Skills, Assistants)
Create Assistant, Give it a name, Click Create Assistant
Click Add Dialog Skill, Add existing Skill (Pick customer care sample skill created previously)


#Test via API

#Find Token and API endpoint
Login to Cloud Pak Cluster:  https://cp4d-clustername:31843   credentials:  admin / pw: password
Click on Hamburger and go to My Instances, Provisioned Instances
For your Instance, Select ... far right of Start Date  and View Details
Copy Access Token to clipboard
export TOKEN=youraccesstoken
Copy URL to clipboard
export API_URL=your api endpoint


#Capture TOKEN and service endpoint for documentation
echo $TOKEN >release-name_TOKEN.out
echo $TOKEN
echo $API_URL >release-name_endpoint_url
echo $API_URL
 
#list workspaces
curl $API_URL/v1/workspaces?version=2018-09-20 -H "Authorization: Bearer $TOKEN" -k


#set your workspace ID from the previous command response
export workspace_id=
example:  export workspace_id=5028f3f1-27fb-43ac-9544-89a0c529ce55

#list intents
curl $API_URL/v1/workspaces/${workspace_id}/intents?version=2018-09-20 -H "Authorization: Bearer $TOKEN" -k


#list entities
curl $API_URL/v1/workspaces/${workspace_id}/entities?version=2018-09-20 -H "Authorization: Bearer $TOKEN" -k


#list dialog nodes
curl $API_URL/v1/workspaces/${workspace_id}/dialog_nodes?version=2018-09-20 -H "Authorization: Bearer $TOKEN" -k


#get message - send a hello to the test workspace
curl $API_URL/v1/workspaces/${workspace_id}/message?version=2018-09-20 -H "Authorization: Bearer $TOKEN" -k --header "Content-Type:application/json" --data "{\"input\": {\"text\": \"Hello\"}}"


#grab Assistant ID
`curl -k -H "Authorization: Bearer $TOKEN" -X GET "$API_URL/v1/agents/definitions?version=2018-12-20"`

#set your Assistant ID from the previous command response
export assistant_id=

#Create a V2 session using the assistant ID from previous step
`curl -k -H "Authorization: Bearer $TOKEN"  -X POST "$API_URL/v2/assistants/${assistant_id}/sessions?version=2019-02-28"`

Sample Response:
{“session_id”:“65a44d76-bc84-41bf-9b20-22ae5903bd46"}

#set your session ID from the previous command response
export session_id=

#Send a hello message to test workspace using V2 API - using the Assistant ID and session ID obtained in previous steps

`curl -k -H "Authorization: Bearer $TOKEN" -H "Content-Type:application/json" -X POST -d "{\"input\": {\"text\": \"Hello\"}}" "$API_URL/v2/assistants/${assistant_id}/sessions/${session_id}/message?version=2019-02-28"`

Sample response:

{“output”:{“generic”:[{“response_type”:“text”,“text”:“I’m looking forward to helping you today. What can I help you with?“}],“intents”:[{“intent”:“Help-Greetings”,“confidence”:0.776085901260376}],“entities”:[]}}

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

###to Delete Deployment 


#Delete Instance from My Instances Page

Login to Cloud Pak Cluster:  https://cp4d-clustername:31843   credentials:  admin / pw: password
Click on Hamburger, go to My Instances
Click on ... to right of Start date and select Delete
Confirm


#Delete Deployment

helm delete --tls --no-hooks --purge release-name 

#Post uninstall cleanup

kubectl delete job,deploy,rs,pod,statefulset,configmap,secret,ingress,service,serviceaccount,role,rolebinding,pvc,poddisruptionbudget --selector=release=release-name --namespace=cp4d-namespace

#To remove the configmap
kubectl delete cm stolon-cluster-release-name  


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
ls /mnt/local-storage/storage/watson/assistant/release-name/
rm -r -f /mnt/local-storage/storage/watson/assistant/release-name/
exit

#Run command below to purge the ICP4D Addon service instance database if you intend to re-use the release name on a future install

kubectl -n zen exec zen-metastoredb-0 \
  -- sh /cockroach/cockroach.sh sql \
  --insecure -e "DELETE FROM zen.service_instances WHERE deleted_at IS NOT NULL RETURNING id;" \
  --host='zen-metastoredb-public'


_________________________________________________________


#How to reload nginx # for problems related to finding Instance in UI

kubectl -n zen get po | grep zen-core
On any of the zen-core-xxxxxx (xxxxxxx is just the format of the pod name) pods run:

kubectl -n zen exec -it zen-core-xxxxxxx -- /bin/bash
Once inside the pod, reload the nginx configuration:  
/user-home/.scripts/system/utils/nginx-reload


kubectl -n zen exec zen-metastoredb-0 \
  -- sh /cockroach/cockroach.sh sql \
  --insecure -e "DELETE FROM zen.service_instances WHERE deleted_at IS NOT NULL RETURNING id;" \
  --host='zen-metastoredb-public'

