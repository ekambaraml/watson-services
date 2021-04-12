# WDS 2.1.2 GA on CP4D 2.5 (OpenShift 311) 

# Warning - 2.1.2 hotfix uses new procedure for loading images, installing and uninstalling discovery. 
If you are upgrading from Watson Discovery 2.1.1 or earlier you must uninstall that version of Watson Discovery before you can install Watson Discovery 2.1.2.    

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
This cheatsheet can be used to do a vanilla development installation of Watson Discovery 2.1.2 on CP4D 2.5 on Openshift 3.11 with portworx Storage.  

### Overview
* Do a Find and replace for the variables below to update the syntax of the commands below for your installation.   Do not use cheatsheet from box as the formatting of commands is lost. 
* Verify prereqs are met
* Follow instructions to install & verify
_________________________________________________________

## STEP 1 - Replace variables for your deploy  
* Find and replace `cp4d-clustername` with your clustername (typically load balancer fqdn) - ex: wp-wa-stt-feb23.icp.ibmcsf.net
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
scp xfer@9.30.44.60:/root/ga/ibm-watson-discovery-prod-2.1.2.tar.xz .
```

Extract Watson archive to filesystem that has ample space 
```
cd /workingdir
mkdir /workingdir/ibm-watson-discovery-ppa
tar -xvf ibm-watson-discovery-prod-2.1.2.tar.xz  -C /workingdir/ibm-watson-discovery-ppa
```

_________________________________________________________

#### Optional Content Intelligence (requires separate license)

* Can't figure out how to untar this file so...
* Download Content Intelligence PPA to your workstation
* Unzip the file
* Transfer the override file and swidtag-file to the master node in `/workingdir/ibm-watson-discovery-ppa`

_________________________________________________________

Check for cp4d-namespace label - don't think you have to do this, think new install process does.....
```
kubectl get namespace cp4d-namespace --show-labels
```

Run labelNamespace.sh  (if needed - only needs to be done once per cluster when installing multiple services)
```
kubectl label --overwrite namespace/cp4d-namespace ns=cp4d-namespace
```

_________________________________________________________


## Loading Watson Discovery Docker images into your container registry

Before you can install Watson Discovery, you must load all of the Docker images distributed as part of the PPA archive into the cluster's internal container registry using the `loadImages.sh` script from the `bin` subdirectory.

```
#Change into discovery ppa directory
cd /workingdir/ibm-watson-discovery-ppa

#Load Images
./bin/loadImages.sh --registry $(oc get routes docker-registry -n default -o template={{.spec.host}}) --namespace cp4d-namespace
```

## Installing Watson Discovery

Installing Watson Discovery deploys a single Watson Discovery application into an IBM Cloud Pak environment. You can deploy to a `Development` or `Production` environment. **By default, Watson Discovery will install in `Development` mode.** See [High availability (Production) configuration](#high-availability-configuration) for instructions on deploying to `Production`.

To install Watson Discovery to your cluster, run the `installDiscovery.sh` script from the `bin` subdirectory.

* Run `./installDiscovery.sh -h` for help.
* By default the script runs in non-interactive mode, so all arguments must be specified using command-line flags. Use `--interactive true` to run the script in interactive mode.
* The required arguments to `installDiscovery.sh` are
    * `--cluster-pull-prefix PREFIX`: Should always be the internal registry name `docker-registry.default.svc.cluster.local:5000/cp4d-namespace`
    * `--api-host HOSTNAME`: The host name (do not include a port or scheme in this value) to the Kubernetes API Endpoint for your cluster. You can retrieve this using `kubectl cluster-info`
    * `--api-ip IP_ADDR`: The IPv4 address of the API host name provided to `--api-host`
    * `--namespace NAMESPACE`: The namespace you want to install Watson Discovery into
    * `--storageclass STORAGE_CLASS`: The name of the storage class to use for Watson Discovery's ReadWriteOnce storage. When using Portworx, Watson Discovery recommends `portworx-db-gp3`
    * `--shared-storageclass STORAGE_CLASS`: The name of the storage class to use for Watson Discovery's ReadWriteMany storage. When using Portworx, Watson Discovery recommends `portworx-shared-gp2`
* To install Watson Discovery in High Availability mode, append `--production` to your command.
* To install Watson Discovery with optional Content Intelligence, append `specify --override ci-override.yaml` to your command

```
#Install Discovery Dev chart (or add --production to the end for a HA chart)
cd /workingdir/ibm-watson-discovery-ppa
./bin/installDiscovery.sh -c docker-registry.default.svc.cluster.local:5000/cp4d-namespace -a "cp4d-clustername" -I IP_address -n cp4d-namespace -s portworx-db-gp3 -S portworx-shared-gp2

```

Open up a second terminal window to watch the deployment spin up

```
ssh root@9.30.119.23
watch "oc get pods -l 'release in(bedrock,core,substrate)'"
```
Wait for all pods to become ready.  You are looking for all of the Jobs to be in Successful=1


Control C to exit watch


To check status of your deployment
```
./linux/helm list
./linux/helm status admin
./linux/helm status bedrock
./linux/helm status substrate
./linux/helm status core
```

To check for pods not Running or Running but not ready
```
oc get pods --all-namespaces | grep -Ev '1/1|2/2|3/3|4/4|5/5|6/6|7/7|8/8' | grep -v 'Completed'
```

## Additional Step needed for Content Intelligence only; else skip

Add the `Software Identification Tags` to the required pod
```
oc cp /workingdir/ibm-watson-discovery-ppa/ibm.com_IBM_Watson_Discovery_for_Cloud_Pak_for_Data_Content_Intelligence-2.1.0.swidtag core-discovery-gateway-0:/swidtag/ -c management
```
_________________________________________________________

## OPTIONAL DEBUG


# To debug failures

* No idea how to debug this.....

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
./linux/helm test core
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

* Run Script
```
cd /workingdir/ibm-watson-discovery-ppa
./bin/openshiftCollector.sh -c cp4d-clustername -u ocadmin -p ocadmin -n cp4d-namespace -t
```
_________________________________________________________

### How to Delete WD 2.1.2

To remove Watson Discovery from an OpenShift or IBM Cloud Private cluster, use the `uninstallDiscovery.sh` script provided in the `bin` subdirectory.

* Use `./uninstallDiscovery.sh -h` for help.
* The argument to `--namespace` should be the namespace Watson Discovery is running in



```
./uninstallDiscovery.sh -n cp4d-namespace
```

By default this script will not remove persistent volume claims or specific secrets required to access or retrieve any data stored in Watson Discovery. To delete all objects associated with this instance of Watson Discovery, including any and all ingested data, include the `--force` flag.

```
./uninstallDiscovery.sh -n cp4d-namespace --force
```

Make sure everything is deleted:
```
oc get jobs | grep core
```
if found, delete core-job-name
```
oc delete job {core-job-name}
```

_________________________________________________________
### How to install optional Language pack 

The following enrichments are supported in English only, unless you download and install the language extension pack `ibm-watson-discovery-pack1` from Passport Advantage. For a breakdown of supported languages, see [Language support](https://cloud.ibm.com/docs/services/discovery-data?topic=discovery-data-language-support).

- Entities
- Keywords
- Sentiment of documents

**Discovery must be installed and running & must use same release name**

* Download language pack &  transfer to master node
* Create directory & Extract Tar
* Run loadimages.sh to load image to registry **NOTE** The copy of `loadImages.sh` from ibm-watson-discovery-pack1 and ibm-watson-discovery are not interchangeable.
* Run `installLanguagePack.sh` to install

```
mkdir /workingdir/ibm-watson-discovery-language-pack
tar xJf ibm-wat-dis-pack1-prod-2.1.2.tar.xz -C /workingdir/ibm-watson-discovery-language-pack

#Make sure you are authenticated to oc & Docker
oc login wp-feb14-master-1.fyre.ibm.com:8443 -u ocadmin -p ocadmin
docker login -u $(oc whoami) -p $(oc whoami -t ) $(oc get routes docker-registry -n default -o template={{.spec.host}})

#Change into bin directory
cd /workingdir/ibm-watson-discovery-language-pack/bin

#Load Images
./loadImages.sh --registry $(oc get routes docker-registry -n default -o template={{.spec.host}}) --namespace cp4d-namespace

#Install Language Pack
./installLanguagePack.sh -c docker-registry.default.svc.cluster.local:5000/cp4d-namespace -n cp4d-namespace
```

Once installed, the substrate-discovery-hdp-worker pods will be patched, starting with hdp-worker-2.   Once all hdp-worker pods have been reinitialized with the patch, you can test using the language pack.  Be patient.

# to Watch
```
watch "oc get pods -l 'release in(substrate)'"
```


