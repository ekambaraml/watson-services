Fyre 4.3 end to end

Draft #1 - not tested

# Step 1 - Provision VM / Prepare Nodes / OpenShift 4.3 Install

Source: 
https://github.ibm.com/watson-engagement-advisor/WA-ICP4D-Openshift-Documentation/wiki/OpenShift-4.3-with-CP4D-3.0-using-PPA

-----------------------

# Step 1 - Provision VM / Prepare Nodes / OpenShift 4.3 Install


### Create Fyre Cluster 

```
curl -X POST -k -u ${fyre_user_name}:${fyre_api_key} 'https://api.fyre.ibm.com/rest/v1/?operation=deployopenshiftcluster' --data '{ "cluster_name" : ${clustername}, "site" : "svl", "ocp_version" : "4.3", "master_quantity" : 3, "master_cpu" : 16, "master_memory" : 32, "worker_quantity" : 5, "worker_cpu" : 16, "worker_memory" : 64}'
```

Results

```
Here are the details for when it's fully finished:
Embers									Public IP		Private IP 	Additional Disks
jwalesmay23-bootstrap.fyre.ibm.com 	--	10.16.24.116	--
jwalesmay23-inf.fyre.ibm.com 			9.30.57.231		10.16.24.121	1000
jwalesmay23-master-1.fyre.ibm.com 		--				10.16.24.122	--
jwalesmay23-master-2.fyre.ibm.com 		--				10.16.24.123	--
jwalesmay23-master-3.fyre.ibm.com 		--				10.16.24.124	--
jwalesmay23-worker-1.fyre.ibm.com 		--				10.16.24.125	500,500
jwalesmay23-worker-2.fyre.ibm.com 		--				10.16.25.133	500,500
jwalesmay23-worker-3.fyre.ibm.com 		--				10.16.25.179	500,500
jwalesmay23-worker-4.fyre.ibm.com 		--				10.16.25.181	500,500
jwalesmay23-worker-5.fyre.ibm.com 		--				10.16.25.182	500,500
```

Hi jennifer d. wales,

Your OpenShift cluster 'jwalesmay23' has finished building.

You may now access your OpenShift portal here:

https://console-openshift-console.apps.jwalesmay23.os.fyre.ibm.com

Credentials:
Username: kubeadmin
Password: 

All the masters and workers in your cluster have private IPs. If you need to access the cluster via SSH, you can log into the 'infrastructure node' which has a public IP (9-dot) and runs haproxy, NFS, etc. From there you can ssh to the master/worker nodes by private IP or hostname. Please note: to get to the master and worker nodes, you need to log in as the 'core' user. Not as 'root'.

The inf VM for this cluster is: jwalesmay23-inf.fyre.ibm.com.

### Remote into cluster and continue setup

```
ssh root@9.30.57.231
```

Login as kubeadmin
```
oc login -u kubeadmin -p `cat ~/auth/kubeadmin-password`
```

Generate token for temp use (lasts 24 hours)
```
oc login --token=$(oc whoami -t ) --server=https://api.jwalesjune12.os.fyre.ibm.com:6443
```


Find your console address
```
oc get routes console -n openshift-console -o template={{.spec.host}}
```

Make a place to work
```
mkdir /ibm
```

### Setup local users


1.  Install httpd-tools if not avail
```
yum install httpd-tools
```

2.  Create a temporary htpasswd file with a user (-c_
```
htpasswd -c -B -b /tmp/htpasswd {username} {password}
htpasswd -B -b /tmp/htpasswd {username} {password}
```
3.  Create a secret based on the file
```
oc create secret generic htpasswd-secret  --from-file htpasswd=/tmp/htpasswd -n openshift-config
```

4.  Get oauth config to update
```
cd /ibm
oc get oauth cluster -o yaml >oauth.yaml
```

5.  Modify oauth config with htpasswd identity provider
```
vi oauth.yaml
```
add spec section
```
spec:
  identityProviders:
  - htpasswd:
      fileData:
        name: htpasswd-secret
    mappingMethod: claim
    name: localusers
    type: HTPasswd
```    
6.  Apply new oauth yaml - this will generate something to watch - authentication changes progressing to true
```
oc apply -f oauth.yaml
oc get clusteroperators | grep authentication
```
7.  cluster role if admin access is desired:  
```
oc adm policy add-cluster-role-to-user cluster-admin {user}
```

-----------------------

# Step 2 - Storage Setup - Installed Portworx 2.5.0.1

https://github.ibm.com/jennifer-wales/watsoncp4d/blob/master/cheatsheets/portworx/portworx%202.5.0.1%20on%20openshift%204.3.md

-----------------------


# Step 3 - Install CPD 3.0 

1. Create a folder to keep everything together for the CP4D install
   ```bash
   cd /ibm
   ```
2.  Download and set up the executable to use for install
   ```
   #3.0
   wget http://icpfs1.svl.ibm.com/zen/cp4d-builds/3.0.0.0/dev/installer/latest/cpd-linux

   #3.0.1
   wget http://icpfs1.svl.ibm.com/zen/cp4d-builds/3.0.1/dev/GMC/installer/10/cpd-linux

   chmod +x cpd-linux
   ```
3.  Download the **repo.yaml** file
   ```
   wget http://icpfs1.svl.ibm.com/zen/cp4d-builds/3.0.0.0/dev/components/lite/latest/repo.yaml
   ```
4.  Add your Artifactory user login and api key to the repo.yaml file.  Get these values from:
   ```
   1. go to https://na.artifactory.swg-devops.com/artifactory/
   2. click on your username to the right-top corner of the page
   3. in the page note your user name as User Profile: xxx
   4. generate and note your key
   5. use key and password in repo.yaml for internal testing
   6. use url for registry
   		3.0:   url: http://icpfs1.svl.ibm.com/zen/cp4d-builds/3.0.0.0/dev/components/lite/250
   		3.0.1: url: http://icpfs1.svl.ibm.com/zen/cp4d-builds/3.0.1/dev/GMC
   ```

   registry:
  - url: hyc-cp4d-team-bootstrap-docker-local.artifactory.swg-devops.com
    username: jennifer_wales@us.ibm.com
    apikey: {artificatory key to match artifactory url above}
    namespace: ""
    name: base-registry
fileservers:
  - url: http://icpfs1.svl.ibm.com/zen/cp4d-builds/3.0.0.0/dev/components/lite/250


5.  Download and install **helm**
   ```
   wget https://get.helm.sh/helm-v2.14.3-linux-amd64.tar.gz
   tar -xvf helm-v2.14.3-linux-amd64.tar.gz
   cp linux-amd64/helm /usr/local/bin/
   ```
6.  Create an `override.yaml` file
   ```yaml
   nginxRepo:
     resolver: "dns-default.openshift-dns"

   zenCoreMetaDb:
     storageClass: "portworx-db-gp3"
   ```
7.  Export env vars used for install
   ```bash
 export NAMESPACE=zen
 export STORAGE_CLASS=portworx-shared-gp
   ```
8.  Create the zen namespace and set up admin
   ```
   ./cpd-linux adm -s repo.yaml -a lite --verbose --namespace $NAMESPACE --apply
   ```
9.  Install cp4d
   ```
   ./cpd-linux --repo repo.yaml --assembly lite --namespace zen --storageclass $STORAGE_CLASS -o override.yaml
   ```

### Results
```
Installs 3 packages - 

		Module                         Arch       Version    Status
		0010-infra                     x86_64     3.0.0      Ready
		0015-setup                     x86_64     3.0.0      Ready
		0020-core                      x86_64     3.0.0      Ready
		
		[INFO] [2020-05-28 04:07:36-0940] Access the web console at https://zen-cpd-zen.apps.jwalesmay23.os.fyre.ibm.com

		*** Initializing version configmap for assembly lite ***

		[INFO] [2020-05-28 04:07:37-0333] Assembly configmap update complete

		[INFO] [2020-05-28 04:07:37-0334] *** Installation for assembly lite completed successfully ***

Compute for zen namespace:
			Producing CPU and Memory request and limit summary for:
			Namespace: zen
			File: /tmp/describe-zen.txt

			CPU REQ: 3540m
			CPU LIM: 20650m
			MEM REQ: 7156Mi
			MEM LIM: 23540Mi
```
10.  Grant zenuser admin rights to zen project
```
oc policy add-role-to-user admin zenuser -n zen
```

# Step 4 - Add-on Install - Install Watson Assistant 1.4.2 & Verify

Source:  https://github.ibm.com/watson-deploy-configs/conversation/blob/wa-icp-1.4.2/templates/icp.d/stable/ibm-watson-assistant-prod-bundle/charts/ibm-watson-assistant-prod/README.md

1.  Bind restricted SCC for Zen
```
oc adm policy add-scc-to-group restricted system:serviceaccounts:zen
```

2.  Verify Portworx Storage class for Assistant
```
oc get storageclass |grep portworx-assistant
```

3.  Check / Set Project label needed for Watson Services
```
oc get project zen --show-labels 
```

Label Namespace 
```
oc label --overwrite namespace zen ns=zen
```

Confirm Project label needed for Watson Services (ns=zen)
```
oc get project zen --show-labels 
```

4.  Switch to Zen namespace
```
oc project zen
```

5.  Grab the secret - you will need for wa-override.yaml:
```
oc get secrets | grep default-dockercfg
```

6.  Create wa-override.yaml

* Set global.deploymentType to Development or Production
* Set image.pullSecret to secret name from above, ex:  pullSecret: "default-dockercfg-rgmsl"
* Do not set MasterHostname, or  masterIP as was done in previous releases
* Set languages as needed 
* Set ingress.wcnAddon.addon.platformVersion to match CPD version, 3.0.0.0 or 3.0.1 (GA)
* Save and exit

```
global:
  # The storage class used for datastores
  storageClassName: "portworx-assistant"

  # Choose between "Development" and "Production"
  deploymentType: "Production"

  # The name of the secret for pulling images
  image:
    pullSecret: "default-dockercfg-pwlsb" 

  icp:
    # Hostname of the CP4D cluster master node
    masterHostname: ""
    # Address of the master node that can be accessible from inside the cluster
    masterIP: ""
    # Hostname of the proxy node inside the CP4D cluster
    proxyHostname:

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
      platformVersion: "3.0.0.1"
```


7.  Create wa-repo.yaml
	
```
	registry:
  - url: hyc-cp4d-team-bootstrap-docker-local.artifactory.swg-devops.com
    username: "jennifer_wales@us.ibm.com"
    apikey: {apikey from artifactory}
    namespace: ""
    name: base-registry
  - url: cp.icr.io
    username: "cp"
    apikey: {entitlement key from https://myibm.ibm.com/products-services/containerlibrary}
    namespace: "cp/watson-assistant"
    name: wa-registry
fileservers:
  - url: http://icpfs1.svl.ibm.com/zen/cp4d-builds/3.0.1/dev/GMC
  - url: http://icpfs1.svl.ibm.com/zen/cp4d-builds/3.0.1/dev/components/ibm-watson-assistant/RC5
```

	8.  Install WA 1.4.2

```
ASSEMBLY_VERSION=1.4.2
NAMESPACE=zen
OPENSHIFT_USERNAME=kubeadmin 
export OPENSHIFT_REGISTRY_PUSH=$(oc get routes default-route -n openshift-image-registry -o template={{.spec.host}})
OPENSHIFT_REGISTRY_PULL=image-registry.openshift-image-registry.svc:5000
	
echo $ASSEMBLY_VERSION
echo $NAMESPACE
echo $OPENSHIFT_USERNAME
echo $OPENSHIFT_REGISTRY_PUSH
echo $OPENSHIFT_REGISTRY_PULL
	
./cpd-linux --repo wa-repo.yaml --assembly ibm-watson-assistant --version $ASSEMBLY_VERSION --namespace $NAMESPACE --transfer-image-to $OPENSHIFT_REGISTRY_PUSH/$NAMESPACE --target-registry-username $OPENSHIFT_USERNAME --target-registry-password=$(oc whoami -t) --insecure-skip-tls-verify --cluster-pull-prefix $OPENSHIFT_REGISTRY_PULL/$NAMESPACE -o wa-override.yaml --silent-install --accept-all-licenses
```


9.  Verify WA

Check the status of the assembly and modules
```
./cpd-linux status --namespace zen
```
```
Results:	
		[INFO] [2020-06-08 14:50:22-0371] Arch override not found. Assuming default architecture x86_64
		[INFO] [2020-06-08 14:50:22-0643] Displaying CR status for all assemblies and relevant modules
		[INFO] [2020-06-08 14:50:27-0054] 
		Displaying CR status for all assemblies and relevant modules

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

Setup your Helm environment
```
export TILLER_NAMESPACE=zen
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

Check the status of resources
```
helm status watson-assistant --tls
```
Run Helm Tests (timeout is not optional, else bdd test times out (5 min))
```
helm test watson-assistant --tls --timeout=18000
```

Provision Instance & create test skill / assistant
(Need to add details)  

Run API tests
(add script)

Dev & Production compute (./compute.sh watson-assistant)

	Development Compute:  
	CPU REQ: 2585m
	CPU LIM: 114500m
	MEM REQ: 35110Mi
	MEM LIM: 35160Mi"

	Production Compute: 
	CPU REQ: 4995m
	CPU LIM: 177000m
	MEM REQ: 72886Mi
	MEM LIM: 72986Mi"



-----------------------

# Lessons:

wa-repo.yaml picky "ERROR] [2020-06-04 06:07:58-0978] Failed to parse the assembly version yaml - open cpd-linux-workspace/assembly/ibm-watson"

have to match WA version with cpd version  - I was testing with 3.0.1 version of WA on 3.0 version of cpd and it didn't like it

WA deployment name is fixed at watson-assistant.   This release does not support multiple helm installs. 


If you have trouble with an install and hit control c because you want to nuke it and try again, the install won't continue because it thinks it's still installing.

You have to get rid of cpd lock file & a few more artifacts before you can reinstall. (my install did not complete after several hours - had trouble with ETCD and slots jobs due to problem on worker 4)

When reinstalling WA with a new version of CPD, remember to update your docker secret

When working with pre-release code and uninstalling / reinstalling - have to purge cpd-linux workspace along with wa uninstall.  If assembly changes on fileserver but name/version is same cpd-linux does not download new code and this caused WA to install, but without proper config map needed to verify it:


helm status watson-assistant --tls

Error: getting deployed release "watson-assistant": release: "watson-assistant" not found

helm ls --tls
```
	NAME      REVISION UPDATED                 STATUS  CHART              APP VERSION NAMESPACE
	0010-infra 1       Thu Jun  4 13:29:57 2020 DEPLOYED 0010-infra-3.0.1   3.0.1      zen      
	0015-setup 1       Thu Jun  4 13:35:41 2020 DEPLOYED 0015-setup-3.0.1   3.0.1      zen      
	0020-core 1       Thu Jun  4 13:36:05 2020 DEPLOYED 0020-zen-base-3.0.1 3.0.1      zen      
```

Can't run helm test either:

```
helm test watson-assistant --tls [--timeout=18000] [--cleanup]

helm test watson-assistant --tls 
Error: release: "watson-assistant" not found
```

If you hit tooling errors - use incognito mode

-----------------------

# How to uninstall Watson Assistant

```
#Delete lock
rm .cpd.lock

#Remove assembly
./cpd-linux uninstall --assembly ibm-watson-assistant --namespace zen
#get rid of everything else that is labeled
oc delete job,deploy,replicaset,pod,statefulset,configmap,secret,ingress,service,serviceaccount,role,rolebinding,persistentvolumeclaim,poddisruptionbudget,horizontalpodautoscaler,networkpolicies,cronjob -l release=watson-assistant

#get rid of stolon cm - it's not labeled so won't be deleted with step 2
oc delete configmap stolon-cluster-watson-assistant

#if installing the same assembly version (prega only)
rm -fr cpd-linux-workspace
```

# How to purge lock files if reinstall won't go

```
#delete the cpd lock:
rm .cpd.lock

#delete the cpd-install configmaps:
for i in `oc get cm| grep cpd-install | awk '{ print $1 }'`; do oc delete pod $i ; done
```

Find and delete the operator pod
```
oc get pods | grep operator
```

oc delete pod {cpd-install-operator-pod}

-----------------------

# How to uninstall 3.0

```
oc delete ns zen

for i in `oc get pv | grep portworx-shared-sc | awk '{ print $1}'`; do oc delete pv $i; done
	
rm -fr cpd-linux-workspace
```

-----------------------










To delete WA

check for and if found delete lock

removing again - had to delete lock
#Step 1
./cpd-linux uninstall --assembly ibm-watson-assistant --namespace zen


#Step 2 - get rid of everything else that is labeled
oc delete job,deploy,replicaset,pod,statefulset,configmap,secret,ingress,service,serviceaccount,role,rolebinding,persistentvolumeclaim,poddisruptionbudget,horizontalpodautoscaler,networkpolicies,cronjob -l release=watson-assistant

#Step 3 - get rid of stolon cm - it's not labeled so won't be deleted with step 2
oc delete configmap stolon-cluster-watson-assistant






How to Delete CPD 
		oc delete ns zen
		for i in `oc get pv | grep portworx-shared-sc | awk '{ print $1}'`; do oc delete pv $i; done
		rm -fr cpd-linux-workspace

	2.  Create zen
		oc new-project zen
		oc policy add-role-to-user admin zenuser -n zen

	3.  download 3.0.1cpd-linux
		wget http://icpfs1.svl.ibm.com/zen/cp4d-builds/3.0.1/dev/GMC/installer/10/cpd-linux

	4.  Modify repo.yaml with 3.0.1 registry url

		registry:
	  - url: hyc-cp4d-team-bootstrap-docker-local.artifactory.swg-devops.com
	    username: jennifer_wales@us.ibm.com
	    apikey: mykeyhere
	    namespace: ""
	    name: base-registry
	 fileservers:
	  - url: http://icpfs1.svl.ibm.com/zen/cp4d-builds/3.0.1/dev/GMC


