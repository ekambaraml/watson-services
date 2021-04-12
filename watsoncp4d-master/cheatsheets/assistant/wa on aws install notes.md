
Note:  this are raw notes from a WA 1.4 on CP4D 2.5 (Openshift 311) on AWS with Docker runtime using EBS storage

This cluster is not available for testing


openshift admin:  https://aws-cpd-f-openshif-6q65tfbdu35m-1577270092.us-east-2.elb.amazonaws.com/console/catalog

cp4d admin page: https://aws-cpd-f-containe-1y1onqnq2usjl-1174494118.us-east-2.elb.amazonaws.com/zen/#/myInstances
-u admin -p waiocadmin

#login to bastion host
ssh -i wai-ocp.pem ec2-user@ec2-3-135-183-29.us-east-2.compute.amazonaws.com

#remote to master node with 300g /root
ssh -i wai-ocp.pem 10.0.45.140 

cp4d namespace = zen

assistant release name = assistant2



NAME                                        STATUS    ROLES           AGE       VERSION           INTERNAL-IP   EXTERNAL-IP   OS-IMAGE               KERNEL-VERSION           CONTAINER-RUNTIME
ip-10-0-25-167.us-east-2.compute.internal   Ready     master          3d        v1.11.0+d4cacc0   10.0.25.167   <none>        OpenShift Enterprise   3.10.0-1062.el7.x86_64   docker://1.13.1

ip-10-0-25-57.us-east-2.compute.internal    Ready     compute,infra   3d        v1.11.0+d4cacc0   10.0.25.57    <none>        OpenShift Enterprise   3.10.0-1062.el7.x86_64   docker://1.13.1

ip-10-0-31-42.us-east-2.compute.internal    Ready     compute,infra   3d        v1.11.0+d4cacc0   10.0.31.42    <none>        OpenShift Enterprise   3.10.0-1062.el7.x86_64   docker://1.13.1

ip-10-0-40-155.us-east-2.compute.internal   Ready     compute,infra   3d        v1.11.0+d4cacc0   10.0.40.155   <none>        OpenShift Enterprise   3.10.0-1062.el7.x86_64   docker://1.13.1

ip-10-0-45-140.us-east-2.compute.internal   Ready     master          3d        v1.11.0+d4cacc0   10.0.45.140   <none>        OpenShift Enterprise   3.10.0-1062.el7.x86_64   docker://1.13.1

ip-10-0-53-213.us-east-2.compute.internal   Ready     compute,infra   3d        v1.11.0+d4cacc0   10.0.53.213   <none>        OpenShift Enterprise   3.10.0-1062.el7.x86_64   docker://1.13.1

ip-10-0-82-223.us-east-2.compute.internal   Ready     compute,infra   3d        v1.11.0+d4cacc0   10.0.82.223   <none>        OpenShift Enterprise   3.10.0-1062.el7.x86_64   docker://1.13.1

ip-10-0-88-75.us-east-2.compute.internal    Ready     master          3d        v1.11.0+d4cacc0   10.0.88.75    <none>        OpenShift Enterprise   3.10.0-1062.el7.x86_64   docker://1.13.1

ip-10-0-89-192.us-east-2.compute.internal   Ready     compute,infra   3d        v1.11.0+d4cacc0   10.0.89.192   <none>        OpenShift Enterprise   3.10.0-1062.el7.x86_64   docker://1.13.1
[root@ip-10-0-45-140 clusterAdministration]# 

_________________________________________________________

Log into your cluster
ssh -i wai-ocp.pem ec2-user@ec2-3-135-183-29.us-east-2.compute.amazonaws.com

#master node with 300g root
ssh -i wai-ocp.pem 10.0.45.140

#Login to OpenShift & Docker 
oc login aws-cpd-f-containe-1y1onqnq2usjl-1174494118.us-east-2.elb.amazonaws.com -u admin -p waiocadmin
sudo su
docker login -u $(oc whoami) -p $(oc whoami -t ) $(oc get routes docker-registry -n default -o template={{.spec.host}})


_________________________________________________________

#STEP 3 Verify Prereqs using commands below.  
_________________________________________________________

#Verify CPUs has AVX2 support 
cat /proc/cpuinfo | grep avx2

#Verify OpenShift version 3.11 
oc version

#Verify Ample space in to extract tar file & load images - 300 gb  for root, /tmp and /var/local/docker
df -h

#Verify Default thread count is set to 8192 pids
`for node in $(oc get node -o=jsonpath={.items[*].metadata.name}); do echo -n "${node} " ; ssh root@${node} cat /etc/sysconfig/docker | grep pids_limit ; done`


#Verify Cloud Pak for Data 2.5 Control Plane installed 
`oc get pods --all-namespaces | grep zen`

#Verify Storage I/O Performance (efs)
#Disk Latency Performance must be better or comparable to: 512000 bytes (512 KB) copied, 1.7917 s, 286 KB/s
dd if=/dev/zero of=/mnt/storage/testfile bs=512 count=1000 oflag=dsync
dd if=/dev/zero of=/testfile bs=512 count=1000 oflag=dsync

#Disk throughput Performance must be better or comparable to: 1073741824 bytes (1.1 GB) copied, 5.14444 s, 209 MB/s
dd if=/dev/zero of=/mnt/storage/testfile bs=1G count=1 oflag=dsync
dd if=/dev/zero of=/testfile bs=1G count=1 oflag=dsync


Do not proceed to installation unless all prereqs are confirmed
_________________________________________________________

#STEP 4 Install Procedures  
_________________________________________________________

#Download Watson Package and transfer to master node 

Release info here: https://apps.na.collabserv.com/wikis/home?lang=en-us#!/wiki/Wd855b33ea663_4b57_a7c7_f5e8e37c2716/page/Watson%20on%20Cloud%20Pak%20Releases


wget https://ak-dsw-mul.dhe.ibm.com/sdfdl/v2/fulfill/CC4F1EN/Xa.2/Xb.htcOMovxHCAgZGTTtBvfmSss_YKGkJYK/Xc.CC4F1EN/ibm-watson-assistant-prod-1.4.0.tar.gz/Xd./Xf.lPr.A6VR/Xg.10576677/Xi./XY.knac/XZ.z_GSUUTloCr2x0FGqghWluBid2c/ibm-watson-assistant-prod-1.4.0.tar.gz#anchor


#Extract Watson archive to filesystem that has ample space 
mkdir /ibm/wa-ppa
tar xvfz ibm-watson-assistant-prod-1.4.0.tar.gz -C /ibm/wa-ppa

oc project zen

#Extract chart
cd /ibm/wa-ppa/charts
tar -xvf ibm-watson-assistant-prod-1.4.0.tgz

#Load the Docker Images (external repo address)
cd /ibm/wa-ppa/pak_extensions/pre-install/clusterAdministration
chmod +x loadImagesOpenShift.sh
export DOCKER_REGISTRY_PREFIX=$(oc get routes docker-registry -n default -o template={{.spec.host}})
echo $DOCKER_REGISTRY_PREFIX
./loadImagesOpenShift.sh --path /ibm/wa-ppa --namespace zen --registry $DOCKER_REGISTRY_PREFIX

#To view images
oc get images
_________________________________________________________

#Run Pre-install steps

#Check zen label with:
kubectl get namespace zen --show-labels

#Label Namespace  (if needed)
cd /ibm/wa-ppa/pak_extensions/pre-install/clusterAdministration
chmod +x labelNamespace.sh
./labelNamespace.sh zen

_________________________________________________________

#Prepare override yaml file

#Copy values.yaml to values-override.yaml 
cd /ibm/wa-ppa/charts/ibm-watson-assistant-prod
cp values.yaml ../values-override.yaml
cd ..

#grab IP for Masternode
oc get nodes -o wide    

#Edit values-override.yaml & set values for your deployment
vi values-override.yaml

Set global.deploymentType to Development or Production
Set global.image.repository: docker-registry.default.svc.cluster.local:5000/zen
Set MasterHostname to the cluster name (cannot be mixed case):  aws-cpd-f-openshif-6q65tfbdu35m-1577270092.us-east-2.elb.amazonaws.com

Set masterIP to the master node ip:  10.0.45.140
Set languages as needed 
Set license to accept

Globally change storageclass from local-storage to gp2: 
Enter `:`
Paste the following to search and replace strings: `%s/local-storage/gp2/g`
Enter `:wq` to Save and Exit

_________________________________________________________

#Get Helm from Tiller pod #only needs to be done once per cluster when installing multiple services
cd /usr/local/bin
tiller_pod=$(oc get po | grep icpd-till | awk '{print $1}')
oc cp ${tiller_pod}:helm helm
chmod +x helm
./helm init --client-only

Note - you will see a messsage about "Not installing tiller due to 'client-only' flag having been set" this is normal

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


#Run Helm Install 

DOCKER_SECRET=$(oc get secrets | grep default-dockercfg| awk '{ printf $1 }')
echo $DOCKER_SECRET
helm install --set master.slad.dockerRegistryPullSecret=$DOCKER_SECRET --values values-override.yaml --namespace zen --name assistant2 ibm-watson-assistant-prod --tls


_________________________________________________________

#Open a second terminal window and watch deployment spin up.  
#Wait for all pods to become ready. This will take 30-45 mins. 

Open up a second terminal window 
ssh to master node
watch oc get job,pod --namespace zen -l release=assistant2


#To check status of your deployment
helm status --tls assistant2 --debug

_________________________________________________________

#Provision your instance
Login to Cloud Pak Cluster:  https://aws-cpd-f-containe-1y1onqnq2usjl-1174494118.us-east-2.elb.amazonaws.com/zen/#/addons

credentials:  -u admin -p waiocadmin

Select Watson Service
Select Provision Instance
Select Create Instance and give it a name 
Open Watson Assistant Tooling & Create a skill
Switch to Skills
Create Skill, Dialog Skill, Next
Select to Use Sample Skill
Click the Sample Skill and it will open 
Click Try it panel and make sure it understands you - type hello (after training completes)

Go to Assistants (Skills, Assistants)
Create Assistant, Give it a name, Click Create Assistant
Click Add Dialog Skill, Add existing Skill (Pick customer care sample skill created previously)

Note: If you have trouble with the tooling, verify your master IP address is set correctly
helm get values assistant2 --tls

_________________________________________________________

#Verify deployment

#Run Test chart
helm test --tls assistant2

Note:  To delete pods from prior test chart execution, run with  --cleanup flag then you can run again with or without flag.
helm test --tls assistant2 --cleanup

_________________________________________________________

#Test via API

#Find Token and API endpoint
Login to Cloud Pak Cluster:  https://aws-cpd-f-containe-1y1onqnq2usjl-1174494118.us-east-2.elb.amazonaws.com/zen/#/addons

credentials:  -u admin -p waiocadmin

Click on Hamburger and go to My Instances, Provisioned Instances
For your Instance, Select ... far right of Start Date  and View Details

#Copy / Paste the token and api end point below, then copy / paste the lines into a terminal window
export TOKEN=
export API_URL=
echo $TOKEN >cp4d-release-token.out
echo $TOKEN
echo $API_URL >assistant2_api_url.out
echo $API_URL

 
#list workspaces - paste the curl command below to list workspaces
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

Download openshift Collector script (with portworx checks) and copy to Master node (ibm directory): https://ibm.box.com/s/5r0bzqawsusbf81iiwp7kukw5d0nhf91

#had to modify script to remove port 8443 for oc login

#Capture information about deployment
chmod +x openshiftCollector.sh
./openshiftCollector.sh -c aws-CPD-f-OpenShif-6Q65TFBDU35M-1577270092.us-east-2.elb.amazonaws.com -u admin -p waiocadmin -n zen -t

./openshiftCollector.sh -c aws-cpd-f-openshif-6q65tfbdu35m-1577270092.us-east-2.elb.amazonaws.com -u admin -p waiocadmin -n zen -t

_________________________________________________________

#How to Delete Deployment 

1. Delete Instance from My Instances Page

Login to Cloud Pak Cluster:  https://zen-cpd-zen.apps.aws-cpd-f-containe-1y1onqnq2usjl-1174494118.us-east-2.elb.amazonaws.com/zen/#/myInstances   credentials:  admin / pw: password
Click on Hamburger, go to My Instances
Click on ... to right of Start date and select Delete
Confirm

2.  Delete Deployment

helm delete --tls --no-hooks --purge assistant2 

3.  Post uninstall cleanup

kubectl delete job,deploy,rs,pod,statefulset,configmap,secret,ingress,service,serviceaccount,role,rolebinding,pvc,poddisruptionbudget --selector=release=assistant2 --namespace=zen

4.  Remove the configmap
kubectl delete cm stolon-cluster-assistant2  



