WKS 1.0.1 on Cloud pak for data 2.1.0.1 as a premium add on

Updates Sept 4 
Draft 1

_________________________________________________________


#Preparation Steps
This cheatsheet can be used to do a vanilla development installation of Watson Knowledge Studio 1.0.1 on CP4D 2.1.0.1 in the 'zen' Namespace.    It assumes you will be working from the master node.  

What is your cluster name?  (load balancer address if multiple masters) 
What is the public IP of your primary master node?  
What is the private IP of your master node (fyre)
What is your ICP Password?  Passw0rdPassw0rdPassw0rdPassw0rd
What do you want to call your deployment?


Find and replace `icp-clustername` with your clustername - ex: wp-wa-stt-feb23.icp.ibmcsf.net
Find and replace your `icp-deployment-name` with the deployment name
Find and replace your `icp-namespace` with your Namespace name - 'for Discovery, install to zen'
Find and replace your `icp-password` with your Namespace name - 'Passw0rdPassw0rdPassw0rdPassw0rd'
Find and replace your `public_master_ip` with your public ip address
Find and replace your `$NFS_SERVER` with the IP address of your NFS Server
Find and replace your `$NFS_DIR` with the root directory root of the NFS server



ICP Console Admin URL:https://icp-clustername:8443/console/welcome
Cloud Pak Admin URL:  https://icp-clustername:31843
CLI Login: cloudctl login -a https://icp-clustername:8443 --skip-ssl-validation -u admin -p icp-password


_________________________________________________________
#WKS Storage

WKS can use NFS or Local-storage - NSF is preferred.   This must be done prior to installing.  If you do not have NFS setup follow instructions below to prepare your cluster.  
https://ibm.box.com/s/xi7szy9l0yu7mblk2rby85n3i0pucb3q


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

#Initiate Helm
helm init --client-only

#Login to ICP Cluster 
cloudctl login -a https://icp-clustername:8443 --skip-ssl-validation -u admin -p icp-password

Select the zen namespace

#Login to docker  
docker login icp-clustername:8500

#Run Healthcheck on your cluster and check for trouble.  You can ignore Glusterd status as WDS doesn't use it.
cd /ibm/InstallPackage/utils/ICP4D-Support-Tools
./icp4d_tools.sh --health


#Verify ICP cluster meets minimum requirements for # workers, memory and cores
x86 processors 

`kubectl get nodes`

`kubectl get nodes -o=jsonpath="{range .items[*]}{.metadata.name}{'\t'}{.status.allocatable.memory}{'\t'}{.status.allocatable.cpu}{'\n'}{end}"`


#Download Watson Package and transfer to master node 

Release info here: https://apps.na.collabserv.com/wikis/home?lang=en-us#!/wiki/Wd855b33ea663_4b57_a7c7_f5e8e37c2716/page/Watson%20on%20Cloud%20Pak%20Releases

Can optionally use wget to download directly to master node if you know the url:  wget {url} --no-check-certificate 

wget https://ak-dsw-mul.dhe.ibm.com/sdfdl/v2/fulfill/CC2NVEN/Xa.2/Xb.htcOMovxHCAgZGTTtBvfmSss_YKz16a-/Xc.CC2NVEN/ibm-watson-discovery-prod-2.0.1.tar.xz/Xd./Xf.lPr.A6VR/Xg.10350064/Xi./XY.knac/XZ.EcxByPsRYTiuQ_mi08MqJ54o1KU/ibm-watson-discovery-prod-2.0.1.tar.xz#anchor --no-check-certificate 

#Run Preinstall scripts

#Extract tar
mkdir ibm-watson-discovery-ppa
tar -xvf ibm-watson-discovery-prod-2.0.1.tar.xz  -C ibm-watson-discovery-ppa
cd ibm-watson-discovery-ppa/deploy/pak_extensions/pre-install/clusterAdministration

#Run labelNamespace.sh
./labelNamespace.sh zen

#Check zen label with:
kubectl get namespace zen --show-labels

#Run createSecurityClusterPrereqs.sh
./createSecurityClusterPrereqs.sh

#Run createSecurityNamespacePrereqs.sh
cd ../namespaceAdministration
./createSecurityNamespacePrereqs.sh zen


#Create oketi-nfs storageclass
#Paste text below to create oketi-nfs.yaml
`
cat > oketi-nfs.yaml << EOF
  apiVersion: storage.k8s.io/v1
  kind: StorageClass
  metadata:
    name: oketi-nfs
  parameters:
    nodes: |
      [
        { "Hostname":"HOST", "IP":"$NFS_SERVER", "Path":"$NFS_DIR" }
      ]
    volumeType: nfs
  provisioner: oketi
  reclaimPolicy: Retain
  volumeBindingMode: Immediate
EOF
`
#Apply oketi-nfs.yaml
kubectl apply -f oketi-nfs.yaml

#Verify system virtual memory max map - ElasticSearch will not start unless vm.max_map_count is greater than or equal to 262144
sysctl -a | grep vm.max_map_count

_________________________________________________________

#Run Deploy.sh to install the helm chart and install Watson
cd /ibm-watson-discovery-ppa/deploy
./deploy.sh -d /ibm-watson-discovery-ppa/ibm-watson-discovery -e icp-deployment-name -c 31843 -n zen 

./deploy.sh -d {compressed_file_name} -e {release_name_postfix}
```

- `{compressed_file_name}` is the name of the file that you downloaded from Passport Advantage.
- `{release_name_postfix}` is the postfix of Helm release name of this installation.

The command will interactively ask you the following information, so answer like the following.

Select Y or y to accept the values and when prompted, provide the remaining values:
-----------------------------------------------------------------------------
namespace:                       zen
Console Port:                    31843
clusterDockerImagePrefix:        icp-clustername:8500/zen
externalDockerImagePrefix:       icp-clustername:8500/zen
useDynamicProvisioning:          true
storageClassName:                oketi-nfs
-----------------------------------------------------------------------------

The deploy.sh will load the images to the cp4d repo.  If something goes wrong with loading an image, you can press Y to try again.  
Once the images are loaded, you will see a message `Starting the installation...`

#To watch the status, open up a second terminal window and tail install.log
ssh root@public_master_ip
cd /ibm-watson-discovery-ppa/deploy
tail -f install.log 

#To watch the pods come up 
watch kubectl get job,pod,svc,secret,cm,pvc --namespace icp-namespace

If all goes well, in 30 mins or so, you should see something like below:

`
Package  Release zen-wds201 installed.
Running command: /wds/ibm-watson-discovery-ppa/deploy/dpctl_linux --config /wds/ibm-watson-discovery-ppa/deploy/install.yaml helm waitChartReady -r zen-wds201 -t 60
Pods:         [===============================================================>--------------] 59s (23/28) 82 %
Pods:         [==============================================================================] 2m37s (28/28) done
PVCs:         [==============================================================================] 0s (13/13) done
Deployments:  [==============================================================================] 2m36s (12/12) done
StatefulSets: [==============================================================================] 2m10s (11/11) done
Jobs:         [==============================================================================] 0s (1/1) done
The deploy script finished successfully
`


#Check status of your deployment
helm status --tls zen-icp-deployment-name 

#Provision your instance
Login to Cloud Pak Cluster:  https://icp-clustername:31843   credentials:  admin / pw: password
Click on Add On icon in upper right hand corner
Go to your addon
Select Provision Instance
Select Create Instance and give it a name 

_________________________________________________________

#Verify deployment

#Run Test chart
helm test --tls zen-icp-deployment-name

Note:  To delete pods from prior test chart execution, run with  --cleanup flag then you can run again with or without flag.
helm test --tls zen-icp-deployment-name -cleanup

#To check values used for your deployment
helm get values zen-icp-deployment-name --tls

#Verify tooling
Login to Tooling with Cloud Pak credentials:  admin / pw: password
https://icp-clustername:31843/discovery/zen-icp-deployment-name/collections

Create collection
Select upload data
name:  verify
Create collection
Upload sample pdf and test query (save faq.doc for api test)

Sample files here: https://ibm.box.com/s/cw86w7rbegcr3aqcwo5gm619gljxg2gl


#Test via API

#Find Token and API endpoint 
Login to Cloud Pak Cluster:  https://icp-clustername:31843   credentials:  admin / pw: password
Click on Hamburger and go to My Instances, Provisioned Instances
For your Instance, Select ... far right of Start Date  and View Details
Copy Access Token to clipboard
export TOKEN=youraccesstoken
Copy URL to clipboard
export API_URL=your api endpoint

#Capture TOKEN and service endpoint for documentation
echo $TOKEN >zen-icp-deployment-name_TOKEN.out
echo $TOKEN
echo $API_URL >zen-icp-deployment-name_endpoint_url
echo $API_URL
 
#list Collections
curl $API_URL/v1/environments/default/collections?version=2019-06-10 -H "Authorization: Bearer $TOKEN" -k

#set your collection ID from the previous command response
export collection_id=
example: export collection_id=5ff68cfa-178c-a5e9-0000-016bd308bb79

#Ingest document
curl -k -H "Authorization: Bearer $TOKEN" -X POST -F "file=@FAQ.docx" $API_URL/v1/environments/default/collections/$collection_id/documents?version=2019-06-10

#Query result
curl -k -H "Authorization: Bearer $TOKEN" $API_URL/v1/environments/default/collections/$collection_id/query?version=2019-06-10&query=text:'ATM'

_________________________________________________________

#Capture information about deployment / gather baseline information (Highly recommended)

Download icpCollector script and copy to Master node (ibm directory): https://ibm.box.com/s/q87wpr3vy92u46cmywue7m69ri13zjyx
#Run icpcollector from Masternode
./icpCollector_without_jq.sh -c icp-clustername -a id-mycluster-account -n zen -u admin -p icp-password


_________________________________________________________

###to Delete Deployment 


#Delete Instance from My Instances Page

Login to Cloud Pak Cluster:  https://icp-clustername:31843   credentials:  admin / pw: password
Click on Hamburger, go to My Instances
Click on ... to right of Start date and select Delete
Confirm

#Delete Deployment

helm delete --tls --purge zen-icp-deployment-name


#Post uninstall cleanup
#To see what's remained:
kubectl get configmaps,jobs,pods,statefulsets,deployments,roles,rolebindings,secrets,serviceaccounts,persistentvolumeclaims --selector=release=zen-icp-deployment-name --namespace=zen

#To Delete:
kubectl delete configmaps,jobs,pods,statefulsets,deployments,roles,rolebindings,secrets,serviceaccounts,persistentvolumeclaims --selector=release=zen-icp-deployment-name --namespace=zen


#Delete the PVs 

`kubectl delete persistentvolumes $(kubectl get persistentvolumes \
  --output=jsonpath='{range .items[*]}{@.metadata.name}:{@.status.phase}:{@.spec.claimRef.name}{"\n"}{end}' \
  | grep ":Released:" \
  | grep "zen-icp-deployment-name-" \
  | cut -d ':' -f 1)`








