

-----------------------

### Add cluster info below

```
export INFRA={IPADDRESS}
export CP4DCLUSTERNAME=yourcluster.cp.fyre.ibm.com
```

kubadamin
password: 

To find OpenShift console:

```
oc whoami --show-console
```

-----------------------

### Remote into cluster

```
ssh root@$INFRA
```

Login as kubeadmin 
```
oc login -u kubeadmin -p `cat ~/auth/kubeadmin-password`
oc login --token=$(oc whoami -t ) --server=https://api.${CP4DCLUSTERNAME}:6443
mkdir /ibm
```

-----------------------

### Create ocadmin Cluster-admin User (optional - so you do not have to login with kubeadmin)

1.  Install utilities

```
yum install httpd-tools
```
2.  Paste below to create ocadmin login or modify as desired 
```
export OCADMIN=ocadmin
export OCADMINPASS=ocadmin

htpasswd -c -B -b /tmp/htpasswd $OCADMIN $OCADMINPASS
cat /tmp/htpasswd
sleep 2
#creating htpasswd-secret in openshift-config
oc create secret generic htpasswd-secret  --from-file htpasswd=/tmp/htpasswd -n openshift-config
sleep 2
# adding identity provider htpasswd to cluster oauth config
oc replace -f - <<EOF_ADD_IDP
apiVersion: config.openshift.io/v1
kind: OAuth
metadata:
  name: cluster
spec:
  identityProviders:
  - htpasswd:
      fileData:
        name: htpasswd-secret
    mappingMethod: claim
    name: localusers
    type: HTPasswd
EOF_ADD_IDP
sleep 5
# granting $OCADMIN cluster-admin priv
oc adm policy add-cluster-role-to-user cluster-admin $OCADMIN
sleep 5
watch oc get pods -n openshift-authentication
```


-----------------------


### Storage Setup - Portworx 2.6.2

Portworx 262 Install - GA docs don't work - missing patch part and login to private registry so push fails.  Used these:  https://github.ibm.com/PrivateCloud-analytics/CEA-Zen/wiki/How-to-install-Portworx-2.6.x-on-RedHat-OpenShift-4.x-System

1.  Install Podman
```
yum install podman
```

2.  Download Portworx to infra node 

```
mkdir /ibm
cd /ibm
wget http://icpfs1.svl.ibm.com/zen/cp4d-builds/3.0.1/misc/portworx/cpd35-portworx-v2.6.2.0.tgz
tar xzvf cpd35-portworx-v2.6.2.0.tgz
```

3.  Clean disks to prepare for Portworx
```
cd /ibm/cpd-portworx/px-install-4.x
clean-px-node-disks.sh
```

4. Create the route for the internal registry & login
```
oc project openshift-image-registry
oc patch configs.imageregistry.operator.openshift.io/cluster --type merge -p '{"spec":{"defaultRoute":true}}'
export PRIVATE_REGISTRY=$(oc registry info)
export PODMAN_LOGIN_ARGS="--tls-verify=false"
export PODMAN_PUSH_ARGS="--tls-verify=false"
podman login -u kubeadmin -p $(oc whoami -t) $(oc registry info) --tls-verify=false
```

5.  Download, tag and push the images to the OCP in-cluster registry
```
oc project kube-system
cd /ibm/cpd-portworx/px-images
./process-px-images.sh -r $(oc registry info) -u kubeadmin -p $(oc whoami -t) -s kube-system -c podman -t ./px_2.5.5.0-dist.tgz
```

6.  Verify images
```
oc get imagestreams -n kube-system
```

7.  Install Portworx
```
cd /ibm/cpd-portworx/px-install-4.x
./px-install.sh install-operator
./px-sc.sh 
```

Wait for the Portworx Operator Pod to start successfully before proceeding 
```
oc get pods -n kube-system -w
```

8.  Create Portworx cluster using separate devices for application and metadata storage (Recommended)
```
./px-install.sh install-storage /dev/vdb /dev/vdc
```

Watch pods come up
```
oc get po -n kube-system -w
```

9.  Check Portworx status
```
PX_POD=$(kubectl get pods -l name=portworx -n kube-system -o jsonpath='{.items[0].metadata.name}')
kubectl exec $PX_POD -n kube-system -- /opt/pwx/bin/pxctl status
```

-----------------------

### Install CPD 3.5.2

1.  Download and set up the CPD CLI to use for install
https://github.com/IBM/cpd-cli/releases/
   
```
cd/ibm
wget https://github.com/IBM/cpd-cli/releases/download/v3.5.2/cpd-cli-linux-EE-3.5.2.tgz
chmod +x cpd-cli-linux-EE-3.5.2.tgz
tar xvf cpd-cli-linux-EE-3.5.2.tgz
```

3.  Add your api key to the repo.yaml file.
```
vi /ibm/repo.yaml
```   

4. Export env vars used for install
```
export NAMESPACE=zen
export OPENSHIFT_USERNAME=kubeadmin
export OPENSHIFT_REGISTRY_PULL=image-registry.openshift-image-registry.svc:5000
```

5.  Setup cluster for the control plane (creates zen namespace) 
```
./cpd-cli adm --repo ./repo.yaml --assembly lite --arch x86_64 --namespace $NAMESPACE --apply
```

6.  Install cp4d control plane (about 20 mins). https://www.ibm.com/support/knowledgecenter/SSQNUZ_3.5.0/cpd/install/rhos-install.html

```
./cpd-cli install  --repo repo.yaml --assembly lite --namespace $NAMESPACE --storageclass portworx-shared-gp3 --transfer-image-to $(oc registry info)/$NAMESPACE --cluster-pull-prefix $OPENSHIFT_REGISTRY_PULL/$NAMESPACE --target-registry-username $OPENSHIFT_USERNAME --target-registry-password=$(oc whoami -t) --latest-dependency  --insecure-skip-tls-verify  --accept-all-licenses --override-config portworx
```

3.5.2 Compute:
Producing CPU and Memory request and limit summary for:
Namespace: zen
File: /tmp/describe-zen.txt

CPU REQ: 2680m
CPU LIM: 14300m
MEM REQ: 5536Mi
MEM LIM: 18664Mi



7.  Verify
```
./cpd-cli status \
--assembly lite \
--namespace $NAMESPACE
```



-----------------------

### How to uninstall 3.5  #need to verify

```
oc delete project zen

for i in `oc get pv | grep portworx-shared-gp3 | awk '{ print $1}'`; do oc delete pv $i; done
	
rm -fr cpd-linux-workspace
```

-----------------------


