# Fast Start WA 1.4.1 on CP4D 2.5 (Openshift 311)

**This is a customized cheat sheet for use with Fast Start only.**
_________________________________________________________

## Reference 

* Documentation:  https://cloud.ibm.com/docs/services/assistant-data?topic=assistant-data-install-141
* Readme:  https://github.ibm.com/watson-deploy-configs/conversation/blob/master/templates/icp.d/stable/ibm-watson-assistant/README.md
* Watson Install Requirements:  https://apps.na.collabserv.com/wikis/home?lang=en-us#!/wiki/Wd855b33ea663_4b57_a7c7_f5e8e37c2716/page/Watson%20Install%20Prereqs%20(Q4%202019%20Release)/edit

_________________________________________________________

##  START HERE
This cheatsheet can be used to do a vanilla development installation of Watson Assistant  1.4.1 on CP4D 25 on Openshift 3.11 with portworx Storage.  

### Overview
* Do a Find and replace for the variables below to update the syntax of the commands below for your installation.   Do not use cheatsheet from box as the formatting of commands is lost. 
* Verify prereqs are met
* Follow instructions to install & verify
_________________________________________________________

## STEP 1 - Replace variables for your deploy  
Customize cheatsheet for your skytap environment by doing a find / replace for:

* Find and replace `sshport`  with your custom ssh port. For example, if for your cluster, Port 22 is mapped to services-uscentrl.skytap.com:9179, use `9179` here.
* Find and replace `adminport`  with your custom port associated with 32247 port # of NFSServer VM. For example, if for your cluster, Port 8443 of NFSServer is mapped to services-uscentrl.skytap.com:9735, use `9735` here.

### Already done for you:
* CP4D Clustername =  `nfsserver.ibm.demo` 
* CP4D Namespace / Project = `zen` 
* Deployment Name = `wa141`
* IP Address of Cluster hostname = `10.0.10.5`

CP4D Admin URL = https://services-uscentral.skytap.com:adminport/zen/#/gettingStarted
_________________________________________________________

## STEP 2 - Login into Openshift & Docker from the node you will be installing from
### SSH to Master node 
```
ssh root@services-uscentral.skytap.com -p sshport
```
*password=IBMDem0s! (zero, not o)*

```
# Login to OpenShift & Docker 
oc login nfsserver.ibm.demo:8443 -u ocadmin -p ocadmin
docker login -u $(oc whoami) -p $(oc whoami -t ) docker-registry.default.svc:5000
```

_________________________________________________________

## STEP 3 Verify Prereqs using oc-healthcheck.sh script


### To use Script
```
cd /ibm
./oc-healthcheck.sh
```
**Do not proceed to installation unless all prereqs are confirmed**
_________________________________________________________

## STEP 4 Install Procedures  
_________________________________________________________

### Download Watson Package and transfer to master node 
**already done for you**

Release info here: https://apps.na.collabserv.com/wikis/home?lang=en-us#!/wiki/Wd855b33ea663_4b57_a7c7_f5e8e37c2716/page/Watson%20on%20Cloud%20Pak%20Releases


### Extract Watson archive to filesystem that has ample space 
**already done for you**
```
cd /ibm
mkdir /ibm/wa-ppa
tar xvfz ibm-watson-assistant-prod-1.4.1.tar.gz -C /ibm/wa-ppa
```

### Extract chart
**already done for you**
```
cd /ibm/wa-ppa/charts
tar -xvf ibm-watson-assistant-prod-1.4.1.tgz
```

### Load the Docker Images  - using external repo address
**already done for you**
```
cd /ibm/wa-ppa/pak_extensions/pre-install/clusterAdministration
chmod +x loadImagesOpenShift.sh
./loadImagesOpenShift.sh --path /ibm/wa-ppa --namespace zen --registry docker-registry.default.svc:5000
```

To view images
```
oc get images
```

Create Portworx Storage Class wa-portworx.yaml by pasting text below
***Note:  Watson Assistant does not use one of the standard storageclasses preconfigured during Portworx install (yet)***

```
cat <<EOF > "${PWD}/wa-portworx.yaml"

kind: StorageClass
apiVersion: storage.k8s.io/v1
metadata:
   name: portworx-assistant
provisioner: kubernetes.io/portworx-volume
parameters:
   repl: "3"
   priority_io: "high"
   snap_interval: "0"
   io_profile: "db"
   block_size: "64k"
EOF
```


Apply Portworx Storage Class wa-portworx.yaml
```
oc create -f wa-portworx.yaml
```

Check for zen label 
```
kubectl get namespace zen --show-labels
```

Run labelNamespace.sh  (if needed - only needs to be done once per cluster when installing multiple services)
```
kubectl label --overwrite namespace/zen ns=zen
```

Copy values.yaml to values-override.yaml 
```
cd /ibm/wa-ppa/charts/ibm-watson-assistant-prod
cp values.yaml ../values-override.yaml
cd ..
```

Grab IP for Masternode for use in the next step
```
oc get nodes -o wide | awk '$3~/.*master.*/' | awk '{print $6}'    
```
_________________________________________________________

### Edit values-override.yaml & set values for your deployment
```
vi values-override.yaml
```
Down arrow to navigate to the line you need to change
`i` to enter insert mode

Under global

* Set global.deploymentType to Development or Production

Under image:
* Set global.image.repository `repository` to `docker-registry.default.svc:5000/zen`

Under icp:
* Set masterHostname to the cluster load balancer to  `nfsserver.ibm.demo`
* Set masterIP to the IP of master node you recorded in the step above

**Note - If you wanted to enable languages, you would set in this file by changing language from false to true in Under global.languages**

Accept license and set storage to portworx:
* Hit `esc` and `/license` to search for license line
* Set license to `accept`
* Hit `esc` and `:` 
* Paste the following to search and replace strings: 
```
%s/local-storage/portworx-assistant/g
```
You should see 6 substitutions on 6 lines

* Enter `esc` `:wq` to Save and Exit

_________________________________________________________

### Get Helm from Tiller pod

**only needs to be done once per cluster when installing multiple services**
```
cd /usr/local/bin
tiller_pod=$(oc get po | grep icpd-till | awk '{print $1}')
oc cp ${tiller_pod}:helm helm
chmod +x helm
./helm init --client-only
```

Note - you will see a messsage about "Not installing tiller due to 'client-only' flag having been set" this is normal

```
#Set targeted namespace 
oc project zen

#Change into charts directory
cd /ibm/wa-ppa/charts

#Establish the certificate and key for Helm Tiller
export TILLER_NAMESPACE=zen
oc get secret helm-secret -n $TILLER_NAMESPACE -o yaml|grep -A3 '^data:'|tail -3 | awk -F: '{system("echo "$2" |base64 --decode > "$1)}'
export HELM_TLS_CA_CERT=$PWD/ca.cert.pem
export HELM_TLS_CERT=$PWD/helm.cert.pem
export HELM_TLS_KEY=$PWD/helm.key.pem
helm version  --tls
```
_________________________________________________________

## Run Helm Install 

```
DOCKER_SECRET=$(oc get secrets | grep default-dockercfg| awk '{ printf $1 }')
helm install --set master.slad.dockerRegistryPullSecret=$DOCKER_SECRET --values values-override.yaml --namespace zen --name wa141 ibm-watson-assistant-prod --tls
```

Watch deployment spin up - the majority of the install goes fast, with the **recommends pod taking up to 45 minutes to create**.  Be patient.

Open up a second terminal window 

```
ssh root@services-uscentral.skytap.com -p sshport
```
*password=IBMDem0s! (zero, not o)*

```
watch oc get job,pod --namespace zen -l release=wa141
```
Wait for all pods to become ready.  You are looking for all of the Jobs to be in Successful=1


Control C to exit watch

To watch for jobs and pods not Running or Running but not ready
```
watch "oc get jobs,pods --namespace zen -l release=wa141 | grep -v '1[[:blank:]]*1' | grep -v Completed | grep -Ev '1/1|2/2|3/3|4/4'"
```


To check status of your deployment
```
export TILLER_NAMESPACE=zen
oc get secret helm-secret -n $TILLER_NAMESPACE -o yaml|grep -A3 '^data:'|tail -3 | awk -F: '{system("echo "$2" |base64 --decode > "$1)}'
export HELM_TLS_CA_CERT=$PWD/ca.cert.pem
export HELM_TLS_CERT=$PWD/helm.cert.pem
export HELM_TLS_KEY=$PWD/helm.key.pem
helm status --tls wa141 --debug
```


_________________________________________________________

## Provision your instance
Login to Cloud Pak Cluster:  https://services-uscentral.skytap.com:adminport/zen/#/addons   
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

**Note: If you have trouble with the tooling, verify your master IP address is set correctly**
```
helm get values wa141 --tls
```
_________________________________________________________

## Verify deployment

Run Test chart
```
helm test --tls wa141
```


**Note:  To delete pods from prior test chart execution, run with  --cleanup flag then you can run again with or without flag.**
```
helm test --tls wa141 -cleanup
```
_________________________________________________________

## Test via API

Find Token and API endpoint
* Login to Cloud Pak Cluster:  https://services-uscentral.skytap.com:adminport/zen/#/gettingStarted   
**credentials:  admin / pw: password**
* Click on Hamburger and go to My Instances, Provisioned Instances
* For your Instance, Select ... far right of Start Date  and View Details

Copy / Paste the token and api end point below, then copy / paste the lines into a terminal window
```
export TOKEN=
export API_URL=
echo $TOKEN >cp4d-release-token.out
echo $TOKEN
echo $API_URL >wa141_api_url.out
echo $API_URL
 
#list workspaces - paste the curl command below to list workspaces
curl $API_URL/v1/workspaces?version=2018-09-20 -H "Authorization: Bearer $TOKEN" -k

#set your workspace ID from the previous command response
export workspace_id=
#example:  export workspace_id=5028f3f1-27fb-43ac-9544-89a0c529ce55
```

```
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
```

```
#Create a V2 session using the assistant ID from previous step
curl -k -H "Authorization: Bearer $TOKEN"  -X POST "$API_URL/v2/assistants/${assistant_id}/sessions?version=2019-02-28"

#Sample Response: {“session_id”:“65a44d76-bc84-41bf-9b20-22ae5903bd46"}

#set your session ID from the previous command response
export session_id=
```

#Send a hello message to test workspace using V2 API - using the Assistant ID and session ID obtained in previous steps

```
curl -k -H "Authorization: Bearer $TOKEN" -H "Content-Type:application/json" -X POST -d "{\"input\": {\"text\": \"Hello\"}}" "$API_URL/v2/assistants/${assistant_id}/sessions/${session_id}/message?version=2019-02-28"
```

Sample response:


{“output”:{“generic”:[{“response_type”:“text”,“text”:“I’m looking forward to helping you today. What can I help you with?“}],“intents”:[{“intent”:“Help-Greetings”,“confidence”:0.776085901260376}],“entities”:[]}}

_________________________________________________________

## OpenShift Collector

* Capture information about deployment / gather baseline information / or use for debugging

* Download openshift Collector script and copy to Master node (ibm directory): https://ibm.box.com/s/5r0bzqawsusbf81iiwp7kukw5d0nhf91
**This has already been downloaded and kept in /ibn**

**Note:  there is a version deployed with WA that can be used if you don't need portworx checks**
```
cd /ibm/wa-ppa/pak_extensions/post-install/namespaceAdministration
```

* Run Script
```
chmod +x openshiftCollector.sh
./openshiftCollector.sh -c nfsserver.ibm.demo -u ocadmin -p ocadmin -n zen -t
```

_________________________________________________________

### How to Delete Deployment 

```
#Establish the certificate and key for Helm Tiller
export TILLER_NAMESPACE=zen
oc get secret helm-secret -n $TILLER_NAMESPACE -o yaml|grep -A3 '^data:'|tail -3 | awk -F: '{system("echo "$2" |base64 --decode > "$1)}'
export HELM_TLS_CA_CERT=$PWD/ca.cert.pem
export HELM_TLS_CERT=$PWD/helm.cert.pem
export HELM_TLS_KEY=$PWD/helm.key.pem

#Delete Deployment
helm delete --tls --no-hooks --purge wa141

#Post uninstall cleanup
kubectl delete job,deploy,rs,pod,statefulset,configmap,secret,ingress,service,serviceaccount,role,rolebinding,pvc,poddisruptionbudget --selector=release=wa141 --namespace=zen

#Remove the configmap
kubectl delete cm stolon-cluster-wa141
```



