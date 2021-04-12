WA 1.2 on Cloud pak for data 2.1 / ICP 3.1.2  as a premium add on

Updated July 20
updated wa url from passport adv
added draft instructions for 2nd instance

July 26
Must install to conversation namespace for v2 api support and support for sireG languages:  (`ja`, `de`, `ko`, `tw`, `cn`) 

Aug 17
Added delete step to include /mnt directories on worker nodes and using Magesh's script for pv with affinity
Added step for healthcheck

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
Find and replace your `icp-namespace` with your Namespace name - 'conversation' - Warning - must use 'conversation' for v2 support
Find and replace your `icp-password` with your Namespace name - 'Passw0rdPassw0rdPassw0rdPassw0rd'
Find and replace your `public_master_ip` with your public ip address

If installing 2 instances:

Find and replace your `2nd-deployment-name` with your 2nd deployment name
Find and replace your `2nd-namespace` with your 2nd Namespace name - 'devconversation'


ICP Console Admin URL:https://icp-clustername:8443/console/welcome
Cloud Pak Admin URL:  https://icp-clustername:31843
CLI Login: cloudctl login -a https://icp-clustername:8443 --skip-ssl-validation -u admin -p icp-password


_________________________________________________________
#Assistant Storage

Storage options are local-storage, vSphere volumes or Portworx.

WARNING!  
Local-storage should be used for non production environments only.  Statefulsets using local-storage (without affinity) cannot survive a cluster restart which could result in data loss.   If using local-storage for your non-production environment, setup automatic backup of skills and assistants to prevent data loss.

Instructions below will setup your PVs with affinity - see this document for background:  https://ibm.box.com/s/dbiddxoptmfo72shx7c9gakuri5szqh7


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

Select the default namespace for now


#Run Healthcheck (must be run from master node)
cd /ibm/InstallPackage/utils/ICP4D-Support-Tools
./icp4d_tools.sh --health


#Verify ICP cluster meets minimum requirements for # workers, memory and cores
x86 processors / AVX support -Assistant only

`kubectl get nodes`

`kubectl get nodes -o=jsonpath="{range .items[*]}{.metadata.name}{'\t'}{.status.allocatable.memory}{'\t'}{.status.allocatable.cpu}{'\n'}{end}"`

#Create Namespace 
#Warning:  Must install to conversation namespace for v2 api support and support for sireG languages:  (`ja`, `de`, `ko`, `tw`, `cn`) 
kubectl create namespace icp-namespace

#Login to cluster again and select assistant namespace
cloudctl login -a https://icp-clustername:8443 --skip-ssl-validation -u admin -p icp-password

#Download Watson Package directly to master node (timeconsuming) 
wget {url to package} --no-check-certificate 


#Load the Watson Archive to the registry
cloudctl catalog load-archive --registry "icp-clustername:8500" --archive ibm-watson-assistant.1.2.0.tar.gz  --repo local-charts

##Preinstall scripts
#Grab pre-install scripts from archive
wget --no-check-certificate https://icp-clustername:8443/helm-repo/requiredAssets/ibm-watson-assistant-prod-1.2.0.tgz

#Extract tar
tar -xvf ibm-watson-assistant-prod-1.2.0.tgz


#Run pre-install scripts
cd ibm-watson-assistant-prod/ibm_cloud_pak/pak_extensions/pre-install/namespaceAdministration
./createSecurityNamespacePrereqs.sh icp-namespace

#Label Zen namespace
kubectl label --overwrite namespace/zen ns=zen

#Check zen label with:
kubectl get namespace zen --show-labels

#create required PV (2 options)
Option 1 - Use provided script in clusterAdministration (pv without affinity)
./createLocalVolumePV.sh

Option 2 - To create PV with affinity (recommended) 
Download script https://ibm.box.com/s/jvgb60kxaihhnddthto7x7tqxvjisuii
Open 2nd terminal window and move the script to your master node
scp ./createLocalVolumePV-affinity.sh root@public_master_ip:/root

Return to terminal window remoted into master node
chmod 755 createLocalVolumePV-affinity.sh
./createLocalVolumePV-affinity.sh


#Edit the cluster image policy 
#Copy the text below and save into a file called policy.yaml
`apiVersion: securityenforcement.admission.cloud.ibm.com/v1beta1
kind: ClusterImagePolicy
metadata:
 name: watson-assistant-icp-deployment-name-policy
spec:
 repositories:
    - name: "icp-clustername:8500/*"
      policy:
        va:
          enabled: false` 

#Apply policy.yaml
kubectl apply -f policy.yaml


_________________________________________________________

##Command line install 

#Copy values.yaml to values-override.yaml, edit then move to same directory as the chart
Navigate back to ibm-watson-assistant-prod directory
cd ../../../../
cp values.yaml ../values-override.yaml
cd ..
vi values-override.yaml

Set global.deploymentType to Development or Production 
Set MasterHostname to the ip of the load balancer:  icp-clustername
Set master-ip to the PRIVATE ip of master node - impt - fyre only - needs to be private ip
Set license to accept
Deselect Czech
Verify the image paths are set to your cluster:  icp-clustername/icp-namespace



#Install
helm install --tls --values values-override.yaml --namespace icp-namespace --name icp-deployment-name ibm-watson-assistant-prod-1.2.0.tgz

#Wait for all pods to become ready. This will take 30-45 mins.  
Open up a second terminal window and use watch command below to see the progress.
watch kubectl get job,pod,svc,secret,cm,pvc --namespace icp-namespace -l release=icp-deployment-name 

#To check status of your deployment
helm status --tls icp-deployment-name --debug

#Provision your instance
Login to Cloud Pak Cluster:  https://icp-clustername:31843   credentials:  admin / pw: password
Click on Add On icon in upper right hand corner
Go to your addon
Select Provision Instance
Select Create Instance and give it a name 

_________________________________________________________

#Verify deployment

#Run Test chart
helm test --tls icp-deployment-name

Note:  To delete pods from prior test chart execution, run with  --cleanup flag then you can run again with or without flag.
helm test --tls icp-deployment-name -cleanup

#To check values used for your deployment
helm get values icp-deployment-name --tls

#Verify tooling can be accessed via Browser:
Login to Tooling with Cloud Pak credentials:  admin / pw: password
https://icp-clustername:31843/assistant/icp-deployment-name

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
Login to Cloud Pak Cluster:  https://icp-clustername:31843   credentials:  admin / pw: icpd-password
Click on Hamburger and go to My Instances, Provisioned Instances
For your Instance, Select ... far right of Start Date  and View Details
Copy Access Token to clipboard
export TOKEN=youraccesstoken
Copy URL to clipboard
export API_URL=your api endpoint


#Capture TOKEN and service endpoint for documentation
echo $TOKEN >icp-deployment-name_TOKEN.out
echo $TOKEN
echo $API_URL >icp-deployment-name_endpoint_url
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

#Capture information about deployment 

kubectl get nodes --show-labels >icp-clustername_nodes.out

`kubectl get nodes -o=jsonpath="{range .items[*]}{.metadata.name}{'\t'}{.status.allocatable.memory}{'\t'}{.status.allocatable.cpu}{'\n'}{end}" >icp-clustername_compute.out`

kubectl get pods -o wide >icp-clustername_pods.out

helm status --tls icp-deployment-name >icp-clustername_helm_status.out

kubectl describe nodes>describe_nodes.out

helm get icp-deployment-name --tls >helm_release_icp-clustername.out

or optionally run icpCollector_without_jq.sh to snapshot config / logs post install (recommended)
#copy script to master node.  https://ibm.box.com/s/q87wpr3vy92u46cmywue7m69ri13zjyx
./icpCollector_without_jq.sh -c icp-clustername -a id-mycluster-account -n icp-namespace -u admin -p icp-password


_________________________________________________________

###to Delete Deployment 

#Delete Instance from My Instances Page

Login to Cloud Pak Cluster:  https://icp-clustername:31843   credentials:  admin / pw: password
Click on Hamburger, go to My Instances
Click on ... to right of Start date and select Delete
Confirm

#Clean up artifacts left over from instance
kubectl -n zen exec zen-metastoredb-0 \
-- sh /cockroach/cockroach.sh sql  \
--insecure -e "DELETE FROM zen.service_instances WHERE deleted_at IS NOT NULL RETURNING id;" \
--host='zen-metastoredb-public'

#Delete Deployment

helm delete --tls --purge icp-deployment-name
helm delete --tls --no-hooks --purge icp-deployment-name (use --no-hooks if above command fails)

#Delete everything else
kubectl delete job,deploy,rs,pod,statefulset,configmap,secret,ingress,service,serviceaccount,role,rolebinding,pvc,poddisruptionbudget -l release=icp-deployment-name


#Delete the PVs 

Find the pattern of your pv:
kubectl get pv

If using the development script - modify line below with date for the pattern
`for i in `kubectl get pv | grep {date} |awk '{print $1}'`; do kubectl delete pv $i -n icp-namespace --grace-period=0 --force ; done`

If using the script with affinity - modify line below with 'pv-' for the pattern
`for i in `kubectl get pv | grep pv- |awk '{print $1}'`; do kubectl delete pv $i -n icp-namespace --grace-period=0 --force ; done`


#Delete the data from the PV on each of your worker nodes 
To find your worker ips:
kubectl get nodes

Remote into each worker node and check directory and purge if you find PV data for the PV there
ssh root@{workernodeip}
ls /mnt/local-storage/storage/watson/assistant
rm -r -f /mnt/local-storage/storage/watson/assistant
exit

Repeat for remaining worker nodes


_________________________________________________________
#Draft 
#Optional 2nd Instance Installation (Sharing same chart / same Namespace)
To install in different namespace, more work required

Multiple instances of WA can be installed to support lifecycle management or to test out new versions.  To install a 2nd instance of WA (of the same version) perform the following additional steps.

Requirements:  
-must have enough capacity to support 2 instances - double the compute, double the local storage
-must use unique release names


#Instructions

#creates required PVs for 2nd instance
Use provided script in clusterAdministration
cd /root/gold/test/ibm-watson-assistant-prod/ibm_cloud_pak/pak_extensions/pre-install/clusterAdministration/
./createLocalVolumePV.sh
	

#Perform 2nd Instance install 
Prepare Yaml


Modify your values-override.yaml and set ingress.wcnAddon.addon.maxDeployments: 2

mv values-override.yaml values-override2.yaml
vi values-override2.yaml
Under ingress.wcnAddon.addon:
add:  `maxDeployment: 2` 

#Install
helm install --tls --values values-override2.yaml --namespace icp-namespace --name 2nd-deployment-name ibm-watson-assistant-prod-1.2.0.tgz

kubectl get pods -l release=2nd-deployment-name -n icp-namespace

#Wait for all pods to become ready. This will take 30-45 mins.  
Open up a second terminal window and use watch command below to see the progress.
watch kubectl get job,pod,svc,secret,cm,pvc --namespace icp-namespace

#To check status of your deployment
helm status --tls 2nd-deployment-name --debug

#Reload nginx

kubectl -n zen get po | grep zen-core
On any of the zen-core-xxxxxx (xxxxxxx is just the format of the pod name) pods run:

kubectl -n zen exec -it zen-core-xxxxxxx -- /bin/bash
Once inside the pod, reload the nginx configuration:  
/user-home/.scripts/system/utils/nginx-reload

#Provision your instance
Login to Cloud Pak Cluster:  icp-clustername:31843   credentials:  admin / pw: password
Click on Add On icon in upper right hand corner
Go to your addon
Select Provision Instance
Select Create Instance and give it a name 


#Verify 2nd deployment

#Run Test chart
helm test --tls 2nd-deployment-name

Note:  To delete pods from prior test chart execution, run with  --cleanup flag then you can run again with or without flag.
helm test --tls 2nd-deployment-name --cleanup

#To check values used for your deployment
helm get values 2nd-deployment-name  --tls

#Verify tooling can be accessed via Browser:
Login to Tooling with Cloud Pak credentials:  admin / pw: password
https://icp-clustername:31843/assistant/2nd-deployment-name

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
Login to Cloud Pak Cluster:  https://icp-clustername:31843   credentials:  admin / pw: icpd-password
Click on Hamburger and go to My Instances, Provisioned Instances
For your Instance, Select ... far right of Start Date  and View Details
Copy Access Token to clipboard
export TOKEN=youraccesstoken
Copy URL to clipboard
export API_URL=your api endpoint


#Capture TOKEN and service endpoint for documentation
echo $TOKEN >wa2nd_TOKEN.out
echo $TOKEN
echo $API_URL >wa2nd_endpoint_url
echo $API_URL
 
#list workspaces
curl $API_URL/v1/workspaces?version=2018-09-20 -H "Authorization: Bearer $TOKEN" 


#Capture information about 2nd deployment

kubectl get pods -o wide >wp-five-node-june24-balancer.fyre.ibm.com_pods.out

helm status --tls 2nd-deployment-name t >wa2nd_helm_status.out

or optionally run icpCollectorjw.sh (version without jq) to snapshot config / logs post install (recommended)
#copy script to master node.  https://ibm.box.com/s/q87wpr3vy92u46cmywue7m69ri13zjyx
scp ./icpCollector.sh root@micp-masterip:/ibm 

run icpcollector from Masternode
./icpCollectorjw.sh -c wp-five-node-june24-balancer.fyre.ibm.com -a id-mycluster-account -n icp-namespace -u admin -p icp-password



