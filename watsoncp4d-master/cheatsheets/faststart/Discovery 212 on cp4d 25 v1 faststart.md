# Fast Start - WDS 2.1.2 GA on CP4D 2.5 (OpenShift 311) 

**This is a customized cheat sheet for use with Fast Start only.**

# Warning - 2.1.2 hotfix uses new procedure for loading images, installing and uninstalling discovery. 
If you are upgrading from Watson Discovery 2.1.1 or earlier you must uninstall that version of Watson Discovery before you can install Watson Discovery 2.1.2. 

_________________________________________________________

## Reference 

* Documentation:  https://www.ibm.com/support/knowledgecenter/SSQNUZ_2.5.0/cpd/svc/watson/discovery-install.html
* Readme:  https://github.com/ibm-cloud-docs/data-readmes/blob/master/discovery-README.md
* Requirements:  https://apps.na.collabserv.com/wikis/home?lang=en-us#!/wiki/Wd855b33ea663_4b57_a7c7_f5e8e37c2716/page/Watson%20Install%20Prereqs%20(Q4%202019%20Release)/edit

_________________________________________________________

## START HERE
This cheatsheet can be used to do a vanilla development installation of Watson Discovery 2.1.2 on CP4D 2.5 on Openshift 3.11 with portworx Storage.  

### Overview
* Do a Find and replace for the variables below to update the syntax of the commands below for your installation.   Do not use cheatsheet directly from github since the commands need find and replace which is not possible directly in git website. 
* Verify prereqs are met
* Follow instructions to install & verify
_________________________________________________________

## STEP 1 - Replace variables for your deploy  

Skytap environment exposes specific ports of each cluster with a different port number within services-uscentrl.skytap.com. 

Customize cheatsheet for your skytap environment by doing a find / replace for:

* Find and replace `sshport`  with your custom ssh port. For example, if for your cluster, Port 22 is mapped to services-uscentrl.skytap.com:9179, use `9179` here.
* Find and replace `adminport`  with your custom port associated with 32247 port # of NFSServer VM. For example, if for your cluster, Port 8443 of NFSServer is mapped to services-uscentrl.skytap.com:9735, use `9735` here.

### Already done for you:
* CP4D Clustername =  `nfsserver.ibm.demo` 
* CP4D Namespace / Project = `zen` 
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
mkdir /ibm/ibm-watson-discovery-ppa
tar -xvf ibm-watson-discovery-prod-2.1.2.tar.xz  -C /ibm/ibm-watson-discovery-ppa
```
_________________________________________________________

#### Optional Content Intelligence (requires separate license)
* Download Content Intelligence PPA and transfer to master node
```
mkdir /ibm/wds_ci
tar -xvf ibm-wat-dis-content-intel-2.1.2.tgz  -C /ibm/wds_ci
cp /ibm/wds_ci/ci-override.yaml /ibm/wds_ci/*.swidtag ibm/ibm-watson-discovery-ppa/
```
_________________________________________________________

Check for zen label 
```
kubectl get namespace zen --show-labels
```

Run labelNamespace.sh  (if needed - only needs to be done once per cluster when installing multiple services)
```
kubectl label --overwrite namespace/zen ns=zen
```

_________________________________________________________


## Loading Watson Discovery Docker images into your container registry
**already done for you** 

Before you can install Watson Discovery, you must load all of the Docker images distributed as part of the PPA archive into the cluster's internal container registry using the `loadImages.sh` script from the `bin` subdirectory.

```
#Change into discovery ppa directory
cd /ibm/ibm-watson-discovery-ppa

#Load Images
nohup ./bin/loadImages.sh --registry docker-registry.default.svc:5000 --namespace zen &
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
* To install Watson Discovery with optional Content Intelligence, append `--override ci-override.yaml` to your command

```
#Install Discovery Dev chart (or add --production to the end for a HA chart)
cd /ibm/ibm-watson-discovery-ppa/bin
./installDiscovery.sh -c docker-registry.default.svc:5000/zen -a "nfsserver.ibm.demo" -I 10.0.10.5 -n zen -s portworx-db-gp3 -S portworx-shared-gp2

```

Open up a second terminal window to watch the deployment spin up

```
ssh root@services-uscentral.skytap.com -p sshport
```
*password=IBMDem0s! (zero, not o)*

```
watch "oc get pods -l 'release in(admin,bedrock,core,substrate)'"
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
oc get pods  -l 'release in(admin,bedrock,core,substrate)' | grep -Ev '1/1|2/2|3/3|4/4|5/5|6/6|7/7|8/8' | grep -v 'Completed' 
```

## Additional Step needed for Content Intelligence only; else skip

Add the `Software Identification Tags` to the required pod
```
oc cp /ibm/ibm-watson-discovery-ppa/ibm.com_IBM_Watson_Discovery_for_Cloud_Pak_for_Data_Content_Intelligence-2.1.0.swidtag core-discovery-gateway-0:/swidtag/ -c management
_________________________________________________________

## Provision your instance
Login to Cloud Pak Cluster:  https://services-uscentral.skytap.com:adminport/zen/#/addons

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
* Login to Cloud Pak Cluster:  https://services-uscentral.skytap.com:adminport/zen/#/addons

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
cd /ibm/ibm-watson-discovery-ppa
./bin/openshiftCollector.sh -c nfsserver.ibm.demo -u ocadmin -p ocadmin -n zen -t
```
_________________________________________________________

### How to Delete WD 2.1.2

To remove Watson Discovery from an OpenShift or IBM Cloud Private cluster, use the `uninstallDiscovery.sh` script provided in the `bin` subdirectory.

* Use `./uninstallDiscovery.sh -h` for help.
* The argument to `--namespace` should be the namespace Watson Discovery is running in

```
./uninstallDiscovery.sh -n zen
```

By default this script will not remove persistent volume claims or specific secrets required to access or retrieve any data stored in Watson Discovery. To delete all objects associated with this instance of Watson Discovery, including any and all ingested data, include the `--force` flag.

```
./uninstallDiscovery.sh -n zen --force
#Cleanup pending resources that might be left out
oc delete secrets sh.helm.release.v1.bedrock.v1 sh.helm.release.v1.admin.v1
```


_________________________________________________________
### How to install optional Language pack 

The following enrichments are supported in English only, unless you download and install the language extension pack `ibm-watson-discovery-pack1` from Passport Advantage. For a breakdown of supported languages, see [Language support](https://cloud.ibm.com/docs/services/discovery-data?topic=discovery-data-language-support).

- Entities
- Keywords
- Sentiment of documents

**Discovery must be installed and running & must use same release name**

* Download language pack &  transfer to master node **already done for you**
* Create directory & Extract Tar **already done for you**
* Run loadimages.sh to load image to registry **NOTE** The copy of `loadImages.sh` from ibm-watson-discovery-pack1 and ibm-watson-discovery are not interchangeable.
* Run `installLanguagePack.sh` to install

```
mkdir /ibm/ibm-watson-discovery-language-pack
tar -xvf ibm-wat-dis-pack1-prod-2.1.2.tar.xz -C /ibm/ibm-watson-discovery-language-pack

#Make sure you are authenticated to oc & Docker
oc login nfsserver.ibm.demo:8443 -u ocadmin -p ocadmin
docker login -u $(oc whoami) -p $(oc whoami -t ) docker-registry.default.svc:5000

#Change into bin directory
cd /ibm/ibm-watson-discovery-language-pack/bin

#Load Images
./loadImages.sh --registry docker-registry.default.svc:5000 --namespace zen

#Install Language Pack
./installLanguagePack.sh -c docker-registry.default.svc:5000/zen -n zen
```

Once installed, the substrate-discovery-hdp-worker pods will be patched, starting with hdp-worker-2.   Once all hdp-worker pods have been reinitialized with the patch, you can test using the language pack.  Be patient.

### To Watch the deployment
```
watch "oc get pods -l 'release in(substrate)'"
```






