
# Assistant 1.4.2 on CP4D 3.0 (OpenShift 4.3) Draft 1


## Reference 

* Source:  https://github.ibm.com/watson-deploy-configs/conversation/blob/wa-icp-1.4.2/templates/icp.d/stable/ibm-watson-assistant-prod-bundle/charts/ibm-watson-assistant-prod/README.md
* Documentation:  https://www.ibm.com/support/knowledgecenter/SSQNUZ_3.0.1/cpd/svc/watson/assistant-install.html
* Readme:  https://github.ibm.com/watson-deploy-configs/conversation/blob/master/templates/icp.d/stable/ibm-watson-assistant/README.md
* Watson Install Requirements:  https://apps.na.collabserv.com/wikis/home?lang=en-us#!/wiki/Wd855b33ea663_4b57_a7c7_f5e8e37c2716/page/Watson%20Install%20Prereqs%20(Q4%202019%20Release)
* Release info here: https://apps.na.collabserv.com/wikis/home?lang=en-us#!/wiki/Wd855b33ea663_4b57_a7c7_f5e8e37c2716/page/Watson%20on%20Cloud%20Pak%20Releases

URLs
* OpenShift Admin URL:  https://console-openshift-console.apps.cp4d-clustername
* Cloud Pak Admin URL:  https://zen-cpd-zen.apps.cp4d-clustername
  

CLI Login 
```
oc login -u kubeadmin -p `cat ~/auth/kubeadmin-password` 
oc login --token=$(oc whoami -t ) --server=https://api.cp4d-clustername:6443
```

_________________________________________________________

##  START HERE
This cheatsheet can be used to do a vanilla installation of Watson Assistant 1.4.2 on CP4D 3.0 on Openshift 4.3 with portworx Storage.  


Overview
* Do a Find and replace for the variables below to update the syntax of the commands below for your installation.   Do not use cheatsheet from box as the formatting of commands is lost. 
* Verify prereqs are met
* Follow instructions to install & verify

_________________________________________________________

## STEP #1 - Replace variables for your deploy  


* Find and replace `cp4d-clustername` with your clustername (fyre example: jwalesmay23.os.fyre.ibm.com)
* Find and replace your `cp4d-namespace` with your CP4D namespace or project name - ex: zen

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

# Verify Portworx is operational

PX_POD=$(kubectl get pods -l name=portworx -n kube-system -o jsonpath='{.items[0].metadata.name}')
kubectl exec $PX_POD -n kube-system -- /opt/pwx/bin/pxctl status


# Verify Portworx is running on all worker nodes
oc get pods --all-namespaces -o wide | grep portworx-api

# Verify Portworx StorageClasses are available 
oc get storageclasses | grep portworx 

# Verify Cloud Pak for Data 3 Control Plane installed 
oc get pods --all-namespaces | grep cp4d-namespace
```

Do not proceed to installation unless all prereqs are confirmed

_________________________________________________________

## STEP #4 Install Procedures  


This cheat pulls Watson Assistant images from the entitled registry and loads to local registry.  


1.  Bind restricted SCC for cp4d-namespace
```
oc adm policy add-scc-to-group restricted system:serviceaccounts:cp4d-namespace
```

2.  Verify Portworx Storage class for Assistant.  If missing create.
```
oc get storageclass |grep portworx-assistant
```

2a.  Create Portworx Storage Class by pasting text below (Only if missing above)

```
cat <<EOF | oc create -f -
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: portworx-assistant
parameters:
   repl: "3"
   priority_io: "high"
   io_profile: "db_remote"
   block_size: "64k"
allowVolumeExpansion: true
provisioner: kubernetes.io/portworx-volume
reclaimPolicy: Retain
volumeBindingMode: Immediate
EOF
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

5.  Grab the default-dockercfg secret needed for wa-override.yaml 
```
oc get secrets | grep default-dockercfg
```

6.  Create wa-override.yaml

Modify wa-override.yaml below 

* Set global.deploymentType to Development or Production
* Set image.pullSecret to secret name from above, ex:  pullSecret: "default-dockercfg-rgmsl"
* Do not set MasterHostname, or  masterIP as was done in previous releases
* Set languages as needed 
* Set ingress.wcnAddon.addon.platformVersion to match CPD version, 3.0.0.0 or 3.0.1 (GA)
* Paste contents below to create file


### wa-override.yaml
```
cat <<EOF > "${PWD}/wa-override.yaml"
global:
  # The storage class used for datastores
  storageClassName: "portworx-assistant"

  # Choose between "Development" and "Production"
  deploymentType: "Production"

  # The name of the secret for pulling images.
  # The value for "global.image.pullSecret" below does not need to be changed for Development
  # installations where pods will pull docker images directly from the Entitled Docker Registry.
  # For Production installations where docker images will be pulled locally to the Openshift
  # Docker Registry, "global.image.pullSecret" will need to be set to the value obtained by
  # running oc get secrets | grep default-dockercfg in the namespace where IBM Cloud
  # Pak for Data is installed.
  
  image:
    pullSecret: "docker-pull-{{ .Release.Namespace }}-cp-icr-io-wa-registry-registry"

  # global.languages.[language] - Specifies whether [language] should be installed or not.
  languages:
    english: true
    german:  false
    arabic: false
    spanish: false
    french: false
    italian: false
    japanese: false
    korean: false
    portuguese: false
    czech: false
    dutch: false
    chineseTraditional: false
    chineseSimplified: false

# the storageclass used for postgres backup
postgres:
  backup:
    dataPVC:
      storageClassName: portworx-assistant

# use "2.5.0.0" for CP4D 2.5.0 (carbon 9) and "3.0.0.0" for CP4D 3.0.0 and 3.0.1 (carbon 10)
ingress:
  wcnAddon:
    addon:
      platformVersion: "3.0.0.0"
EOF
```

7.  Create wa-repo.yaml 

* Modify wa-override.yaml below with apikey from passport advantage then paste contents below to create file

### wa-repo.yaml
	
```
cat <<EOF > "${PWD}/wa-repo.yaml"
registry:
  - url: cp.icr.io/cp/cpd
    username: "cp"
    apikey: <entitlement-key>
    namespace: ""
    name: base-registry
  - url: cp.icr.io
    username: "cp"
    apikey: <entitlement-key>
    namespace: "cp/watson-assistant"
    name: wa-registry
fileservers:
  - url: https://raw.github.com/IBM/cloud-pak/master/repo/cpd3
EOF

```
8.  Install WA 1.4.2

Paste contents below to kickoff WA 1.4.2

```
ASSEMBLY_VERSION=1.4.2
NAMESPACE=cp4d-namespace
OPENSHIFT_USERNAME=kubeadmin 
OPENSHIFT_REGISTRY_PULL=image-registry.openshift-image-registry.svc:5000
	
echo $ASSEMBLY_VERSION
echo $NAMESPACE
echo $OPENSHIFT_USERNAME
echo $OPENSHIFT_REGISTRY_PULL
	
./cpd-linux --repo wa-repo.yaml --assembly ibm-watson-assistant --version $ASSEMBLY_VERSION --namespace $NAMESPACE --transfer-image-to $(oc registry info)/$NAMESPACE --target-registry-username $OPENSHIFT_USERNAME --target-registry-password=$(oc whoami -t) --insecure-skip-tls-verify --cluster-pull-prefix $OPENSHIFT_REGISTRY_PULL/$NAMESPACE -o wa-override.yaml --silent-install --accept-all-licenses
```

Watson Assistant will now be installed.   First the images will be pulled from the entitled docker registry and pushed to the OpenShift registry.  Once loaded, the Watson install will begin.  The whole process should take at least 2 hours; 1 hour to load images and another hour to install Watson Assistant.


After the image load has completed, you can watch the deployment spin up.  The majority of the install goes fast, with the recommends pod taking up to 45 minutes to create.  Be patient.

**To Watch install**

Open up a second terminal window and wait for all pods to become ready.  You are looking for all of the Jobs to be in `Successful=1`  Control C to exit watch

```
ssh root@IP_address
watch oc get job,pod --namespace cp4d-namespace -l release=watson-assistant
```


**To check for pods not Running or Running but not ready**
```
oc get pods --all-namespaces | grep -Ev '1/1|2/2|3/3|4/4|5/5|6/6|7/7|8/8' | grep -v 'Completed'
```

_________________________________________________________

## STEP #5 Verify   


1.  Check the status of the assembly and modules
```
./cpd-linux status --namespace cp4d-namespace
```

Looking for something like this:
```
Status for assembly lite and relevant modules in project zen:

		Assembly Name           Status           Version          Arch    
		lite                    Ready            3.0.1            x86_64  

		  Module Name                     Status           Version          Arch      Storage Class     
		  0010-infra                      Ready            3.0.1            x86_64    portworx-shared-gp
		  0015-setup                      Ready            3.0.1            x86_64    portworx-shared-gp
		  0020-core                       Ready            3.0.1            x86_64    portworx-shared-gp

		=========================================================================================

		Status for assembly ibm-watson-assistant and relevant modules in project zen:

		Assembly Name           Status           Version          Arch    
		ibm-watson-assistant    Ready            1.4.2            x86_64  

		  Module Name                     Status           Version          Arch      Storage Class     
		  0010-infra                      Ready            3.0.1            x86_64    portworx-shared-gp
		  0015-setup                      Ready            3.0.1            x86_64    portworx-shared-gp
		  0020-core                       Ready            3.0.1            x86_64    portworx-shared-gp
		  ibm-watson-assistant            Ready            1.4.2            x86_64                      
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
Server: &version.Version{SemVer:"v2.14.3", GitCommit:"0e7f3b6637f7af8fcfddb3d2941fcc7cbebb0085", GitTre
```

3.  Check the status of resources
```
helm status watson-assistant --tls
```

4.  Run Helm Tests (timeout is not optional, else bdd test times out with default timer of 5 mins.  Test takes about 30 mins. 
```
helm test watson-assistant --tls --timeout=18000
```

**Note:**  To delete pods from prior test chart execution, run with  --cleanup flag then you can run again with or without flag.
```
helm test watson-assistant --tls --timeout=18000 -cleanup
```

**Optional:  To see what values were set when installed**
```
helm get values watson-assistant --tls
```

_________________________________________________________

## STEP #6 Provision Instance   


1.  Login to Cloud Pak Cluster:  https://zen-cpd-zen.apps.cp4d-clustername/zen/#/addons
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

**Note: If you have trouble with the tooling, try incognito mode**


_________________________________________________________

## STEP #7 Test via API    


Find Token and API endpoint
* Login to Cloud Pak Cluster:  
https://zen-cpd-zen.apps.cp4d-clustername/zen/#/myInstances
**credentials:  admin / pw: password**
* Click on Instance name 
* Copy / Paste the token and api end point from the Access information section, then copy / paste the lines into a terminal window

```
export TOKEN= 
export API_URL=
echo $TOKEN
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
./cpd-linux uninstall --assembly ibm-watson-assistant --namespace cp4d-namespace

#Remove artifacts that are labeled
oc delete job,deploy,replicaset,pod,statefulset,configmap,secret,ingress,service,serviceaccount,role,rolebinding,persistentvolumeclaim,poddisruptionbudget,horizontalpodautoscaler,networkpolicies,cronjob -l release=watson-assistant

#Remove the configmapit's not labeled so won't be deleted with step 2
oc delete configmap stolon-cluster-watson-assistant

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
./cpd-linux uninstall --assembly ibm-watson-assistant --namespace cp4d-namespace

#Remove artifacts that are labeled
oc delete job,deploy,replicaset,pod,statefulset,configmap,secret,ingress,service,serviceaccount,role,rolebinding,persistentvolumeclaim,poddisruptionbudget,horizontalpodautoscaler,networkpolicies,cronjob -l release=watson-assistant

#Remove the configmap 
oc delete configmap stolon-cluster-watson-assistant
```



