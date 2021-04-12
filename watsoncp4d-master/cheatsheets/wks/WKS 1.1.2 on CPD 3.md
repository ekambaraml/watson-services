
# WKS 1.1.2 on CP4D 3.0 (OpenShift 4.3) Draft 2


## Reference 

* Source: https://www.ibm.com/support/knowledgecenter/SSQNUZ_3.0.1/cpd/svc/watson/knowledge-studio-install.html 
* Dev Resources:  https://pages.github.ibm.com/watson-discovery-and-exploration/WKS-issue-manager/cp4d/
* Requirements:  https://apps.na.collabserv.com/wikis/home?lang=en-us#!/wiki/Wd855b33ea663_4b57_a7c7_f5e8e37c2716/page/Watson%20Install%20Prereqs%20(Q4%202019%20Release)


URLs
* OpenShift Admin URL:  https://console-openshift-console.apps.cp4d-clustername
* Cloud Pak Admin URL:  https://cp4d-namespace-cpd-cp4d-namespace.apps.cp4d-clustername
  

CLI Login 
```
oc login -u kubeadmin -p `cat ~/auth/kubeadmin-password` 
oc login --token=$(oc whoami -t ) --server=https://api.cp4d-clustername:6443
```

_________________________________________________________

##  START HERE
This cheatsheet can be used to do a vanilla installation of Watson Knowledge Studio 1.1.2 on CP4D 3.0 on Openshift 4.3 with portworx Storage.  


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


This cheat pulls Watson images from the entitled registry and loads to local registry.  


1.  Switch to cp4d-namespace namespace
```
oc project cp4d-namespace
```

2.  Create wks override file

```
cat <<EOF > "${PWD}/wks-override.yaml"
awt:
 persistentVolume:
  storageClassName: portworx-shared-gp3
EOF
```


3.  Create wks-repo.yaml

* Add apikey from passport advantage & paste contents below to create file

### wks-repo.yaml
	
```
cat <<EOF > "${PWD}/wks-repo.yaml"
registry:
  - url: cp.icr.io/cp/cpd
    username: "cp"
    apikey: <entitlement-key>
    namespace: ""
    name: base-registry
  - url: cp.icr.io
    username: cp
    apikey: <entitlement-key>
    namespace: "cp/knowledge-studio"
    name: wks-registry
fileservers:
  - url: https://raw.github.com/IBM/cloud-pak/master/repo/cpd3
EOF

```

4. Install WKS 1.1.2

Run cpd-linux adm command first by pasting contents below

```
NAMESPACE=cp4d-namespace
OPENSHIFT_USERNAME=kubeadmin 
OPENSHIFT_REGISTRY_PULL=image-registry.openshift-image-registry.svc:5000
	
echo $NAMESPACE
echo $OPENSHIFT_USERNAME
echo $OPENSHIFT_REGISTRY_PULL

./cpd-linux adm \
  --repo "wks-repo.yaml" \
  --assembly watson-ks \
  --namespace "$NAMESPACE" \
  --apply
```

Run cpd-linux command to install WKS by pasting contents below

```
./cpd-linux --repo wks-repo.yaml --assembly watson-ks --namespace $NAMESPACE --transfer-image-to $(oc registry info)/$NAMESPACE --target-registry-username $OPENSHIFT_USERNAME --target-registry-password=$(oc whoami -t) --insecure-skip-tls-verify --cluster-pull-prefix $OPENSHIFT_REGISTRY_PULL/$NAMESPACE -o wks-override.yaml --silent-install --storageclass "portworx-db-gp3" --accept-all-licenses
```

Watson Service will now be installed.   First the images will be pulled from the entitled docker registry and pushed to the OpenShift registry.  Once loaded, the Watson install will begin.  The whole process should take about an hour and a half.   An hour to load the images then about 30 mins to install Watson.


After the images have been loaded, you can watch the deployment spin up.  

**To Watch install**

Open up a second terminal window and wait for all pods to become ready.  You are looking for all of the Jobs to be in `Successful=1`  Control C to exit watch

```
ssh root@IP_address
watch oc get pods -l release=wks
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
Status for assembly lite and relevant modules in project cp4d-namespace:

		
[INFO] [2020-06-18 07:48:43-0225] Arch override not found. Assuming default architecture x86_64
[INFO] [2020-06-18 07:48:43-0404] Displaying CR status for all assemblies and relevant modules
[INFO] [2020-06-18 07:48:50-0216] 
Displaying CR status for all assemblies and relevant modules

Status for assembly lite and relevant modules in project cp4d-namespace:

Assembly Name           Status           Version          Arch    
lite                    Ready            3.0.1            x86_64  

  Module Name                     Status           Version          Arch      Storage Class     
  0010-infra                      Ready            3.0.1            x86_64    portworx-shared-gp
  0015-setup                      Ready            3.0.1            x86_64    portworx-shared-gp
  0020-core                       Ready            3.0.1            x86_64    portworx-shared-gp

=========================================================================================

Status for assembly watson-ks and relevant modules in project cp4d-namespace:

Assembly Name           Status           Version          Arch    
watson-ks               Ready            1.1.2            x86_64  

  Module Name                     Status           Version          Arch      Storage Class     
  0010-infra                      Ready            3.0.1            x86_64    portworx-shared-gp
  0015-setup                      Ready            3.0.1            x86_64    portworx-shared-gp
  0020-core                       Ready            3.0.1            x86_64    portworx-shared-gp
  watson-ks                       Ready            1.1.2            x86_64    portworx-wks      

=========================================================================================

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

4.  Run Helm Test  
```
helm test wks --tls

```

**Note:**  To delete pods from prior test chart execution, run with  --cleanup flag then you can run again with or without flag.

```
helm test wks --tls --cleanup
```

**Optional:  To see what values were set when installed**
```
helm get values {chart} --tls
```

_________________________________________________________

## STEP #6 Provision Instance   


1.  Login to Cloud Pak Cluster:  https://cp4d-namespace-cpd-cp4d-namespace.apps.cp4d-clustername/cp4d-namespace/#/addons

https://cp4d-namespace-cpd-cp4d-namespace.apps.cp4d-clustername/cp4d-namespace/#/addons
**credentials:  admin / pw: password**

* Select Watson Service
* Select Provision Instance
* Give it a name and click Create
* Launch tooling 

**Note: If you have trouble with the tooling, try incognito mode**

_________________________________________________________

### OpenShift Collector  
_________________________________________________________

Use OpenShift Collector to capture information about deployment / gather baseline information / or use for debugging

**Need an Openshift 4.3 version**

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
./cpd-linux uninstall --assembly watson-ks --namespace cp4d-namespace

#Remove artifacts that are labeled
oc delete all,configmaps,jobs,secrets,service,persistentvolumeclaims,poddisruptionbudgets,podsecuritypolicy,securitycontextconstraints,clusterrole,clusterrolebinding,role,rolebinding,serviceaccount,networkpolicy -l release=wks

#Remove the configmap
oc delete configmap stolon-cluster-wks-postgresql

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
./cpd-linux uninstall --assembly watson-ks --namespace cp4d-namespace

#Remove artifacts that are labeled
oc delete all,configmaps,jobs,secrets,service,persistentvolumeclaims,poddisruptionbudgets,podsecuritypolicy,securitycontextconstraints,clusterrole,clusterrolebinding,role,rolebinding,serviceaccount,networkpolicy -l release=wks

#if installing the same assembly version (prerelease only)
rm -fr cpd-linux-workspace
```

#Good to know

Running the install creates a cpd-<release name>-workspace folder where the command was run, where it stores the downloaded files and logs. You can also check the logs of the cpd-operator-pod in the namespace using

```
  oc logs <cpd operator pod> --since-time=1h
```

You can resume/retry installing modules by editing the CPDInstall Custom Resource Definition. This controls how the cpd-operator pod behaves. For example, if the install times out, but the module it was stuck on finished correctly, you can run (in the namespace that CP4D is installed in):

```
oc edit CPDInstall cr-cpdinstall
```
and change retryCount from 0 to 1. This will restart the installation, which will verify the previous modules and then continue installing the next module. You can then follow the progress by running oc logs <cpd operator pod> --tail 10 -f


