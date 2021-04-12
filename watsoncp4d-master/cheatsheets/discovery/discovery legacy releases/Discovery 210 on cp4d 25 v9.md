WDS 2.1.0 on CP4D 2.5 (OpenShift 311) 

_________________________________________________________

#Reference 

Documentation:  https://www.ibm.com/support/knowledgecenter/SSQNUZ_2.5.0/cpd/svc/watson/discovery-install.html
Readme:  https://github.com/ibm-cloud-docs/data-readmes/blob/master/discovery-README.md
Requirements:  https://apps.na.collabserv.com/wikis/home?lang=en-us#!/wiki/Wd855b33ea663_4b57_a7c7_f5e8e37c2716/page/Watson%20Install%20Prereqs%20(Q4%202019%20Release)/edit

URLs
OpenShift Admin URL:  
https://cp4d-clustername:8443

Cloud Pak Admin URL:  
https://cp4d-namespace-cpd-cp4d-namespace.apps.cp4d-clustername

CLI Login 
oc login cp4d-clustername:8443 -u ocadmin -p ocadmin
docker login -u $(oc whoami) -p $(oc whoami -t ) $(oc get routes docker-registry -n default -o template={{.spec.host}})

_________________________________________________________

#START HERE
This cheatsheet can be used to do a vanilla development installation of Watson Discovery 2.1.0 on CP4D 25 on Openshift 3.11 with portworx Storage.  

#Overview
Do a Find and replace for the variables below to update the syntax of the commands below for your installation.   Do not use cheatsheet from box as the formatting of commands is lost. 
Verify prereqs are met
Follow instructions to install & verify
_________________________________________________________

#STEP 1 - Replace variables for your deploy  
Find and replace `cp4d-clustername` with your clustername (typically load balancer fqdn) - ex: wp-wa-stt-feb23.icp.ibmcsf.net
Find and replace your `release-name` with the deployment name
Find and replace your `cp4d-namespace` with your CP4D namespace or project name - ex: zen
_________________________________________________________

#STEP 2 - Log into your cluster
ssh root@IP_address

#Login to OpenShift & Docker 
oc login cp4d-clustername:8443 -u ocadmin -p ocadmin
docker login -u $(oc whoami) -p $(oc whoami -t ) $(oc get routes docker-registry -n default -o template={{.spec.host}})

_________________________________________________________

#STEP 3 Verify Prereqs using commands below.  
_________________________________________________________

#Verify CPUs has AVX2 support 
cat /proc/cpuinfo | grep avx2

#Verify OpenShift version 3.11 
oc version

#Verify Cluster is using CRI-O Container Runtime as required for Portworx
oc get nodes -o wide

#Verify Default thread count is set to 8192 pids
`for node in $(oc get node -o=jsonpath={.items[*].metadata.name}); do echo -n "${node} " ; ssh root@${node} cat /etc/crio/crio.conf | grep pids_limit ; done`

#Verify Ample space in to extract tar file & load images - 300 gb  for root, /tmp and /var/local/docker
df -h

#Verify Portworx is operational
`PX_POD=$(kubectl get pods -l name=portworx -n kube-system -o jsonpath='{.items[0].metadata.name}')
kubectl exec $PX_POD -n kube-system -- /opt/pwx/bin/pxctl status`

#Verify Portworx is running on all worker nodes
oc get pods --all-namespaces -o wide | grep portworx-api

#Verify Portworx StorageClasses are available - Discovery uses portworx-shared-gp and portworx-nonshared-gp
oc get storageclasses | grep portworx 

#Verify Cloud Pak for Data 2.5 Control Plane installed 
`oc get pods --all-namespaces | grep zen`

#Verify vm.max_map_count = 262144
vm.max_map_count = 262144 
`for node in $(oc get node -o=jsonpath={.items[*].metadata.name}); do echo -n "${node} " ; ssh root@${node} sysctl -a | grep vm.max_map_count ; done`

#Verify Selinux set to Enforcing
`for node in $(oc get node -o=jsonpath={.items[*].metadata.name}); do echo -n "${node} " ; ssh root@${node} getenforce; done`

Do not proceed to installation unless all prereqs are confirmed
_________________________________________________________

#STEP 4 Install Procedures  
_________________________________________________________

#Download Watson Package and transfer to master node 

Release info here: https://apps.na.collabserv.com/wikis/home?lang=en-us#!/wiki/Wd855b33ea663_4b57_a7c7_f5e8e37c2716/page/Watson%20on%20Cloud%20Pak%20Releases

#Extract Watson archive to filesystem that has ample space 
mkdir /ibm/ibm-watson-discovery-ppa
tar -xvf ibm-watson-discovery-prod-2.1.0.tar.xz  -C /ibm/ibm-watson-discovery-ppa

#Extract chart
cd /ibm/ibm-watson-discovery-ppa/ibm-watson-discovery/charts
tar -xvf ibm-watson-discovery-prod-2.1.0.tgz

#Run labelNamespace.sh  #only needs to be done once per cluster when installing multiple services
cd /ibm/ibm-watson-discovery-ppa/deploy/pak_extensions/pre-install/clusterAdministration
./labelNamespace.sh cp4d-namespace

_________________________________________________________

#Optionally prepare Override File (for Prod deploy or other custom settings, otherwise skip to next section)
cd /ibm/ibm-watson-discovery-ppa/ibm-watson-discovery/charts/ibm-watson-discovery-prod

#Get docker secret name
oc get secrets | grep default-dockercfg

#Modify below with Docker secret from above then paste text to create values-override.yaml
cat <<EOF > ${PWD}/values-override.yaml
global:
  deploymentType: "Production"
  imagePullSecretName: "default-dockercfg-{yoursecret}"
  license: "accept"
EOF

_________________________________________________________

#Get Helm from Tiller pod #only needs to be done once per cluster when installing multiple services
cd /usr/local/bin
tiller_pod=$(oc get po | grep icpd-till | awk '{print $1}')
oc cp ${tiller_pod}:helm helm
chmod +x helm
./helm init --client-only

Note - you will see a messsage about "Not installing tiller due to 'client-only' flag having been set" this is normal

#Set targeted namespace
oc project cp4d-namespace

#Change into deploy directory
cd /ibm/ibm-watson-discovery-ppa/deploy

#Establish the certificate and key for Helm Tiller
export TILLER_NAMESPACE=cp4d-namespace
oc get secret helm-secret -n $TILLER_NAMESPACE -o yaml|grep -A3 '^data:'|tail -3 | awk -F: '{system("echo "$2" |base64 --decode > "$1)}'
export HELM_TLS_CA_CERT=$PWD/ca.cert.pem
export HELM_TLS_CERT=$PWD/helm.cert.pem
export HELM_TLS_KEY=$PWD/helm.key.pem
helm version  --tls


#Run deploy script 
Note:  know your IP address before starting.  Optionally add `-O values-override.yaml` if adding override

#Get external registry
export EXTERNAL_REGISTRY_PREFIX=$(oc get routes docker-registry -n default -o template={{.spec.host}})/cp4d-namespace

./deploy.sh -d /ibm/ibm-watson-discovery-ppa/ibm-watson-discovery -c "cp4d-clustername" -C cp4d-namespace  -r docker-registry.default.svc.cluster.local:5000/cp4d-namespace -R $EXTERNAL_REGISTRY_PREFIX -s portworx-nonshared-gp -S portworx-shared-gp -e release-name

Follow the prompts confirming your settings

Reference:
-c set to `cp4d-clustername`
-C set to `cp4d-namespace`
-I set to the IP address of the `cp4d-clustername`
-r and -R The dockerimage prefix for kubernetes to pull /push images.  {docker-registry}/cp4d-namespace
-s set to `portworx-nonshared-gp2` or `portworx-nonshared-gp3` #this is the storageclass for ReadWriteOnce access mode (2 or 3 replicas)
-S set to `portworx-shared-gp2` or `portworx-shared-gp3` #this is the storageclass for ReadWriteMany access mode (2 or 3 replicas)
-O optionally set to `values-override.yaml` 
 
Prior to starting Image Upload, you will be prompted with an overview of your settings as shown below:

########################################################################
Module:                      ibm-watson-discovery
Release Name:                release-name
Namespace:                   cp4d-namespace
CP4D Namespace               cp4d-namespace
Tiller Namespace:            cp4d-namespace
Docker Registry Push Prefix: {External docker-registry}/cp4d-namespace 
Docker Registry Pull Prefix: docker-registry.default.svc.cluster.local:5000/cp4d-namespace
Cluster Host (IP):           cp4d-clustername ({Cluster_IP_Address})
Storage Class:               
########################################################################

The deploy.sh will load the images to the cp4d repo.  If something goes wrong with loading an image, restart the script again to keep going.  Log file created in /ibm/ibm-watson-discovery-ppa/deploy/tmp

_________________________________________________________

#To watch the pods come up 
Open a second terminal session
watch kubectl get job,pod,pv --namespace cp4d-namespace -l release=release-name

If all goes well, in 30 mins or so, you should see something like below:
NOTES:
ibm-watson-discovery-prod chart successfully deployed.
** It may take a few minutes for the addon to become available. Please be patient. **

_________________________________________________________

#OPTIONAL DEBUG

#To debug failures, start with the tiller log
oc get pods | grep till
oc logs {tiller-pod-name}
example:  icpd-till-5d89c7967-qwdlq

#If elastic won't start 
1) Verify Discovery pods are using the ibm-discovery-prod-scc (and not nonroot which is a bug)
oc get pods | grep elastic-0

oc get pod {elastic pod name} -o yaml | grep scc 
you are looking for: `openshift.io/scc: ibm-discovery-prod-scc`
todo - add instructions to fix if set to nonroot

2) If scc is correct - might be timing - delete elastic pod and see if goes to running:
oc delete {elastic pod} 


3) If elastic starts, you may need to manually restart elastic-init-plugin-job
oc get job release-name-watson-discovery-elastic-init-plugin-job -o yaml > elastic.yaml

vi elastic.yaml
-remove status section
-delete all of this: 
`selector:
    matchLabels:
      controller-uid: b5a0c003-1622-11ea-9e97-00163e01c9ab`
-delete the `controller-uid` key and value
-Save the file 

Rerun the elastic-init job:
oc delete job release-name-watson-discovery-elastic-init-plugin-job && oc apply -f ./elastic.yaml
watch kubectl get job,pod,svc,secret,cm,pvc --namespace cp4d-namespace -l release=release-name

#To check status of your deployment
helm status --tls release-name --debug
_________________________________________________________


#Provision your instance
Login to Cloud Pak Cluster:  https://cp4d-namespace-cpd-cp4d-namespace.apps.cp4d-clustername/cp4d-namespace/#/addons   
credentials:  admin / pw: password

Select Watson Service
Select Provision Instance
Select Create Instance and give it a name 

Open Watson Tooling 
Click on Sample project and wait for it to setup
Try a sample query

_________________________________________________________

#Verify deployment

#Run Test chart
helm test --tls release-name


Note:  To delete pods from prior test chart execution, run with  --cleanup flag then you can run again with or without flag.
helm test --tls release-name -cleanup



#Find Token and API endpoint
Login to Cloud Pak Cluster:  https://cp4d-namespace-cpd-cp4d-namespace.apps.cp4d-clustername   
credentials:  admin / pw: password

Click on Hamburger and go to My Instances, Provisioned Instances
For your Instance, Select ... far right of Start Date  and View Details

#Copy / Paste the token and api end point below, then copy / paste the lines into a terminal window
export TOKEN=
export API_URL=
echo $TOKEN >cp4d-release-token.out
echo $TOKEN
echo $API_URL >release-name_api_url.out
echo $API_URL
 
#list Collections
curl $API_URL/v1/environments/default/collections?version=2019-06-10 -H "Authorization: Bearer $TOKEN" -k

#set your collection ID from the previous command response
export collection_id=
example: export collection_id=5ff68cfa-178c-a5e9-0000-016bd308bb79

#Ingest document
Sample file here: https://ibm.box.com/s/cw86w7rbegcr3aqcwo5gm619gljxg2gl
curl -k -H "Authorization: Bearer $TOKEN" -X POST -F "file=@FAQ.docx" $API_URL/v1/environments/default/collections/$collection_id/documents?version=2019-06-10

#Query result
curl -k -H "Authorization: Bearer $TOKEN" $API_URL/v1/environments/default/collections/$collection_id/query?version=2019-06-10&query=text:'ATM'

_________________________________________________________

#Capture information about deployment / gather baseline information (Highly recommended)

#Download openshift Collector script and copy to Master node (ibm directory): https://ibm.box.com/s/5r0bzqawsusbf81iiwp7kukw5d0nhf91

#Capture information about deployment
chmod +x openshiftCollector.sh
./openshiftCollector.sh -c cp4d-clustername -u ocadmin -p ocadmin -n cp4d-namespace -t


or 

#run commands below to capture manually
kubectl get nodes --show-labels >cp4d-clustername_nodes.txt

`kubectl get nodes -o=jsonpath="{range .items[*]}{.metadata.name}{'\t'}{.status.allocatable.memory}{'\t'}{.status.allocatable.cpu}{'\n'}{end}" >cp4d-clustername_compute.txt`

kubectl get pods -o wide -l release=release-name >cp4d-clustername_pods.txt

helm status --tls release-name >cp4d-clustername_helm_status.txt

kubectl describe nodes>describe_nodes.txt

helm get release-name --tls >helm_release_cp4d-clustername.txt

helm get values release-name --tls >helm_values_cp4d-clustername.txt

_________________________________________________________

#How to Delete Deployment 

1. Delete Instance from My Instances Page

Login to Cloud Pak Cluster:  https://cp4d-namespace-cpd-cp4d-namespace.apps.cp4d-clustername/cp4d-namespace/#/myInstances   credentials:  admin / pw: password
Click on Hamburger, go to My Instances
Click on ... to right of Start date and select Delete
Confirm

2.  Delete Deployment

helm delete --tls --no-hooks --purge release-name 

3.  Post uninstall cleanup

kubectl delete job,deploy,rs,pod,statefulset,configmap,secret,ingress,service,serviceaccount,role,rolebinding,pvc,poddisruptionbudget --selector=release=release-name --namespace=cp4d-namespace

4.  Remove the configmap
kubectl delete cm stolon-cluster-release-name-postgresql

5.  Delete Role binding
kubectl delete rolebinding ibm-discovery-prod-rolebinding









