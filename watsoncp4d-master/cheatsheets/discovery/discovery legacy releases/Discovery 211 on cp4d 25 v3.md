#WDS 2.1.1 on CP4D 2.5 (OpenShift 311) 

_________________________________________________________

## Reference 

* Documentation:  https://www.ibm.com/support/knowledgecenter/SSQNUZ_2.5.0/cpd/svc/watson/discovery-install.html
* Readme:  https://github.com/ibm-cloud-docs/data-readmes/blob/master/discovery-README.md
* Requirements:  https://apps.na.collabserv.com/wikis/home?lang=en-us#!/wiki/Wd855b33ea663_4b57_a7c7_f5e8e37c2716/page/Watson%20Install%20Prereqs%20(Q4%202019%20Release)/edit

URLs
* OpenShift Admin URL:  https://cp4d-clustername:8443

* Cloud Pak Admin URL:  https://cp4d-namespace-cpd-cp4d-namespace.apps.cp4d-clustername

CLI Login 
```
oc login cp4d-clustername:8443 -u ocadmin -p ocadmin
docker login -u $(oc whoami) -p $(oc whoami -t ) $(oc get routes docker-registry -n default -o template={{.spec.host}})
```

_________________________________________________________

## START HERE
This cheatsheet can be used to do a vanilla development installation of Watson Discovery 2.1.1 on CP4D 2.5 on Openshift 3.11 with portworx Storage.  

### Overview
* Do a Find and replace for the variables below to update the syntax of the commands below for your installation.   Do not use cheatsheet from box as the formatting of commands is lost. 
* Verify prereqs are met
* Follow instructions to install & verify
_________________________________________________________

## STEP 1 - Replace variables for your deploy  
* Find and replace `cp4d-clustername` with your clustername (typically load balancer fqdn) - ex: wp-wa-stt-feb23.icp.ibmcsf.net
* Find and replace your `release-name` with the deployment name
* Find and replace your `cp4d-namespace` with your CP4D namespace or project name - ex: zen
* Find and replace `IP_address` with the IP address of the node you are installing from.  If not a node within the Openshift cluster should have docker and oc cli installed.
* Find and replace `workingdir` with the name of the directory you will be working from.   example:  data/ibm (fyre) or ibm

_________________________________________________________

## STEP 2 - Login into Openshift & Docker from the node you will be installing from

```
ssh root@IP_address
oc login cp4d-clustername:8443 -u ocadmin -p ocadmin
docker login -u $(oc whoami) -p $(oc whoami -t ) $(oc get routes docker-registry -n default -o template={{.spec.host}})
```

_________________________________________________________

## STEP 3 Verify Prereqs using oc-healthcheck.sh script or commands below


### To use Script

Grab oc-healthcheck.sh from Dimply - password is Trans001!
```
cd /root
scp xfer@9.30.44.60:/root/ga/oc-healthcheck.sh .
chmod +x oc-healthcheck.sh
./oc-healthcheck.sh
```

### or via Commands
```
# Verify CPUs has AVX2 support (not sure required for wks)
cat /proc/cpuinfo | grep avx2

# Verify OpenShift version 3.11 
oc version

# Verify Cluster is using CRI-O Container Runtime as required for Portworx
oc get nodes -o wide

# Verify Default thread count is set to 8192 pids
for node in $(oc get node -o=jsonpath={.items[*].metadata.name}); do echo -n "${node} " ; ssh root@${node} cat /etc/crio/crio.conf | grep pids_limit ; done


# Verify Ample space in to extract tar file & load images - 300 gb  for root, /tmp and /var/local/docker
df -h

# Verify Portworx is operational

PX_POD=$(kubectl get pods -l name=portworx -n kube-system -o jsonpath='{.items[0].metadata.name}')
kubectl exec $PX_POD -n kube-system -- /opt/pwx/bin/pxctl status


# Verify Portworx is running on all worker nodes
oc get pods --all-namespaces -o wide | grep portworx-api

# Verify Portworx StorageClasses are available 
oc get storageclasses | grep portworx 

# Verify Cloud Pak for Data 2.5 Control Plane installed 
oc get pods --all-namespaces | grep zen

#Verify vm.max_map_count = 262144
for node in $(oc get node -o=jsonpath={.items[*].metadata.name}); do echo -n "${node} " ; ssh root@${node} sysctl -a | grep vm.max_map_count ; done

#Verify Selinux set to Enforcing
for node in $(oc get node -o=jsonpath={.items[*].metadata.name}); do echo -n "${node} " ; ssh root@${node} getenforce; done

```

Do not proceed to installation unless all prereqs are confirmed
_________________________________________________________

## STEP 4 Install Procedures  
_________________________________________________________

Download Watson Package and transfer to master node 

Release info here: https://apps.na.collabserv.com/wikis/home?lang=en-us#!/wiki/Wd855b33ea663_4b57_a7c7_f5e8e37c2716/page/Watson%20on%20Cloud%20Pak%20Releases

Optionally Grab Archive from Dimply - password is Trans001!
```
scp xfer@9.30.44.60:/root/ga/ibm-watson-discovery-prod-2.1.1.tar.xz .
```

Extract Watson archive to filesystem that has ample space 
```
cd /workingdir
mkdir /workingdir/ibm-watson-discovery-ppa
tar -xvf ibm-watson-discovery-prod-2.1.1.tar.xz  -C /workingdir/ibm-watson-discovery-ppa
```

Extract chart
```
cd /workingdir/ibm-watson-discovery-ppa/ibm-watson-discovery/charts
tar -xvf ibm-watson-discovery-prod-2.1.1.tgz
```
_________________________________________________________

#### Optional Content Intelligence (requires separate license)
* Download Content Intelligence PPA and transfer to master node
```
mkdir /workingdir/wds_ci
tar -xJf <ci-service-ppa-archive>  -C /workingdir/wds_ci
cp /workingdir/wds_ci/ci-override.yaml workingdir/ibm-watson-discovery-ppa/deploy
```
_________________________________________________________

Check for cp4d-namespace label 
```
kubectl get namespace cp4d-namespace --show-labels
```

Run labelNamespace.sh  (if needed - only needs to be done once per cluster when installing multiple services)
```
kubectl label --overwrite namespace/cp4d-namespace ns=cp4d-namespace
```

_________________________________________________________

#### Optionally prepare Override File (for Prod deploy or other custom settings, otherwise skip to next section)
```
cd /workingdir/ibm-watson-discovery-ppa/ibm-watson-discovery/charts/ibm-watson-discovery-prod

#Get docker secret name
oc get secrets | grep default-dockercfg

#Modify below with Docker secret from above then paste text to create values-override.yaml
cat <<EOF > ${PWD}/values-override.yaml
global:
  deploymentType: "Production"
  imagePullSecretName: "default-dockercfg-{yoursecret}"
  license: "accept"
EOF
```
_________________________________________________________

Get Helm from Tiller pod

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
oc project cp4d-namespace

#Change into deploy directory
cd /workingdir/ibm-watson-discovery-ppa/deploy

#Establish the certificate and key for Helm Tiller
export TILLER_NAMESPACE=cp4d-namespace
oc get secret helm-secret -n $TILLER_NAMESPACE -o yaml|grep -A3 '^data:'|tail -3 | awk -F: '{system("echo "$2" |base64 --decode > "$1)}'
export HELM_TLS_CA_CERT=$PWD/ca.cert.pem
export HELM_TLS_CERT=$PWD/helm.cert.pem
export HELM_TLS_KEY=$PWD/helm.key.pem
helm version  --tls
```

Run deploy script 
**Note:  know your IP address before starting**
* Optionally add `-O values-override.yaml` if adding custom override
* Optionally add `-O ci-override.yaml` if installing with Content Intelligence
* Modify deploy.sh below with desired storageclasses to be used
* -s set to `portworx-nonshared-gp2` or `portworx-nonshared-gp3` #this is the storageclass for ReadWriteOnce access mode (2 or 3 replicas)
* -S set to `portworx-shared-gp2` or `portworx-shared-gp3` #this is the storageclass for ReadWriteMany access mode (2 or 3 replicas)

```
#Get external registry
export EXTERNAL_REGISTRY_PREFIX=$(oc get routes docker-registry -n default -o template={{.spec.host}})/cp4d-namespace

./deploy.sh -d /workingdir/ibm-watson-discovery-ppa/ibm-watson-discovery -c "cp4d-clustername" -C cp4d-namespace  -r docker-registry.default.svc.cluster.local:5000/cp4d-namespace -R $EXTERNAL_REGISTRY_PREFIX -s portworx-nonshared-gp3 -S portworx-shared-gp3 -e release-name
```

* Follow the prompts confirming your settings

* Reference:
* -c set to `cp4d-clustername`
* -C set to `cp4d-namespace`
* -I set to the IP address of the `cp4d-clustername`
* -r and -R The dockerimage prefix for kubernetes to pull /push images.  {docker-registry}/cp4d-namespace
* -s set to `portworx-nonshared-gp2` or `portworx-nonshared-gp3` #this is the storageclass for ReadWriteOnce access mode (2 or 3 replicas)
* -S set to `portworx-shared-gp2` or `portworx-shared-gp3` #this is the storageclass for ReadWriteMany access mode (2 or 3 replicas)
* -O optionally set to `values-override.yaml` 
 
* Prior to starting Image Upload, you will be prompted with an overview of your settings as shown below:

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

The deploy.sh will load the images to the cp4d repo then start the helm install.  If something goes wrong with loading an image, restart the script again to keep going.  If all goes well, in 30 mins or so, you should see something like below:
`ibm-watson-discovery-prod chart successfully deployed`


Open up a second terminal window to watch the deployment spin up

```
ssh root@IP_address
watch oc get job,pod --namespace cp4d-namespace -l release=release-name
```
Wait for all pods to become ready.  You are looking for all of the Jobs to be in Successful=1


Control C to exit watch


To check status of your deployment
```
export TILLER_NAMESPACE=zen
oc get secret helm-secret -n $TILLER_NAMESPACE -o yaml|grep -A3 '^data:'|tail -3 | awk -F: '{system("echo "$2" |base64 --decode > "$1)}'
export HELM_TLS_CA_CERT=$PWD/ca.cert.pem
export HELM_TLS_CERT=$PWD/helm.cert.pem
export HELM_TLS_KEY=$PWD/helm.key.pem
helm status --tls release-name --debug
```

To check for pods not Running or Running but not ready
```
oc get pods --all-namespaces | grep -Ev '1/1|2/2|3/3|4/4' | grep -v 'Completed'
```
_________________________________________________________

## OPTIONAL DEBUG


#To debug failures

* Review the Log file created in /workingdir/ibm-watson-discovery-ppa/deploy/tmp

* Review the tiller log - example:  icpd-till-5d89c7967-qwdlq
```
oc get pods | grep till
oc logs {tiller-pod-name}
```

_________________________________________________________


## Provision your instance
Login to Cloud Pak Cluster:  https://cp4d-namespace-cpd-cp4d-namespace.apps.cp4d-clustername/cp4d-namespace/#/addons   
**credentials:  admin / pw: password**

* Select Watson Service
* Select Provision Instance
* Select Create Instance and give it a name 

* Open Watson Tooling 
* Click on Sample project and wait for it to setup
* Try a sample query

_________________________________________________________

## Verify deployment

Run Test chart
```
helm test --tls release-name
```


**Note:  To delete pods from prior test chart execution, run with  --cleanup flag then you can run again with or without flag.**
```
helm test --tls release-name -cleanup
```
_________________________________________________________

## Test via API

Find Token and API endpoint
* Login to Cloud Pak Cluster:  https://cp4d-namespace-cpd-cp4d-namespace.apps.cp4d-clustername   
**credentials:  admin / pw: password**
* Click on Hamburger and go to My Instances, Provisioned Instances
* For your Instance, Select ... far right of Start Date  and View Details

Copy / Paste the token and api end point below, then copy / paste the lines into a terminal window
```
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
#example: export collection_id=5ff68cfa-178c-a5e9-0000-016bd308bb79
```

Ingest document 

* Download document from here: https://ibm.box.com/s/cw86w7rbegcr3aqcwo5gm619gljxg2gl
```
curl -k -H "Authorization: Bearer $TOKEN" -X POST -F "file=@FAQ.docx" $API_URL/v1/environments/default/collections/$collection_id/documents?version=2019-06-10

#Query result
curl -k -H "Authorization: Bearer $TOKEN" $API_URL/v1/environments/default/collections/$collection_id/query?version=2019-06-10&query=text:'ATM'
```
_________________________________________________________

## OpenShift Collector

* Capture information about deployment / gather baseline information / or use for debugging

* Download openshift Collector script and copy to Master node (ibm directory): https://ibm.box.com/s/5r0bzqawsusbf81iiwp7kukw5d0nhf91
**Note:  there is a version deployed with WA that can be used if you don't need portworx checks
cd /workingdir/wa-ppa/pak_extensions/post-install/namespaceAdministration**

* Run Script
```
chmod +x openshiftCollector.sh
./openshiftCollector.sh -c cp4d-clustername -u ocadmin -p ocadmin -n cp4d-namespace -t
```
_________________________________________________________

### How to Delete Deployment 

```
#Establish the certificate and key for Helm Tiller
export TILLER_NAMESPACE=cp4d-namespace
oc get secret helm-secret -n $TILLER_NAMESPACE -o yaml|grep -A3 '^data:'|tail -3 | awk -F: '{system("echo "$2" |base64 --decode > "$1)}'
export HELM_TLS_CA_CERT=$PWD/ca.cert.pem
export HELM_TLS_CERT=$PWD/helm.cert.pem
export HELM_TLS_KEY=$PWD/helm.key.pem

#Delete Deployment
helm delete --tls --no-hooks --purge release-name

#Post uninstall cleanup
kubectl delete job,deploy,rs,pod,statefulset,configmap,secret,ingress,service,serviceaccount,role,rolebinding,pvc,poddisruptionbudget --selector=release=release-name --namespace=cp4d-namespace

#Remove the configmap
kubectl delete cm stolon-cluster-release-name-postgresql

#Delete Role binding
kubectl delete rolebinding ibm-discovery-prod-rolebinding
```

_________________________________________________________
### How to install optional Language pack

**Discovery must be installed and running & must use same release name**

* Download language pack &  transfer to master node
* Change into deploy directory
* Get external registry
* Run deploy.sh

```
mkdir /workingdir/wds-lang
tar xJf ibmwatsondiscoverypack1-prod2.1.1.tar.xz -C /workingdir/wds-lang

#Change into deploy directory
cd /workingdir/wds-lang/deploy

#Get external registry
export EXTERNAL_REGISTRY_PREFIX=$(oc get routes docker-registry -n default -o template={{.spec.host}})/cp4d-namespace

./deploy.sh -d /data/ibm/wds-lang/ibm-watson-discovery-pack1  -r docker-registry.default.svc.cluster.local:5000/cp4d-namespace -R $EXTERNAL_REGISTRY_PREFIX -e release-name

```







