Fyre 4.5 end to end

Draft #1 - not tested

-----------------------

## Provision VM / Prepare Nodes / OpenShift 4.5 Install


### Create Fyre Cluster using curl command below or optionally use Quickburn if no quota
```
https://fyre.ibm.com/quick
```

```
export fyre_user=
export fyre_api_key=
```

Modify below for your cluster

```
curl -k -u ${fyre_user}:${fyre_api_key} -d '{
    "name": "jwales-dec5",
    "description": "Shared cluster for installation testing",
    "platform": "x",
    "quota_type": "product_group",
    "product_group_id": "150",
    "ocp_version": "4.5.20",
    "haproxy": {
        "timeout": {
            "http-request": "10s",
            "queue": "1m",
            "connect": "10s",
            "client": "1m",
            "server": "1m",
            "http-keep-alive": "10s",
            "check": "10s"
        }
    },
    "fips": "no",
    "worker":  [
        {
            "count": "4",
            "cpu": "16",
            "memory": "64",
            "additional_disk":  [
                "100",
                "500"
             ]
        }
     ]
}' -X POST https://ocpapi.svl.ibm.com/v1/ocp/
```


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
2.  Paste below to create ocadmin with pw of ocadmin
```
export OCADMIN=
export OCADMINPASS

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

### Setup CPD Operator - not needed for Watson
https://www.ibm.com/support/knowledgecenter/SSQNUZ_3.5.0/cpd/install/cpd-operator-connected.html


-----------------------

### Storage Setup - Portworx 2.5.5 

Detailed instructions here - snippets below
https://github.ibm.com/jennifer-wales/watsoncp4d/blob/master/cheatsheets/portworx/portworx%202.5.5%20on%20Openshift%204.5.md


```
oc delete project rook-ceph 
oc -n rook-ceph patch cephclusters.ceph.rook.io rook-ceph -p '{"metadata":{"finalizers": []}}' --type=merge
for worker in $(oc get node -o name -l node-role.kubernetes.io/worker | sed 's/node\///')
do 
echo $worker
ssh core@$worker sudo lsblk -l
done
```
Clean ceph (only if it exists from the /dev/vdc device)

```
yum install podman
```

### Portworx Install

```
oc project openshift-image-registry
oc patch configs.imageregistry.operator.openshift.io/cluster --type merge -p '{"spec":{"defaultRoute":true}}'
oc registry info
export PRIVATE_REGISTRY=$(oc registry info)
export PODMAN_LOGIN_ARGS="--tls-verify=false"
export PODMAN_PUSH_ARGS="--tls-verify=false"
podman login -u kubeadmin -p $(oc whoami -t) $(oc registry info) --tls-verify=false
```
2.  Download Portworx from infra node and push the images to the OCP in-cluster registry

```
mkdir /ibm
cd /ibm
wget http://icpfs1.svl.ibm.com/zen/cp4d-builds/3.0.1/misc/portworx/cpd3-portworx-v2.5.5.0-fp01.tgz
tar xzvf cpd3-portworx-v2.5.5.0-fp01.tgz
cd ./cpd-portworx/px-images
./process-px-images.sh -r $(oc registry info) -u kubeadmin -p $(oc whoami -t) -s kube-system -c podman -t ./px_2.5.5.0-dist.tgz
oc get imagestreams -n kube-system
```

```
cd /ibm/cpd-portworx/px-install-4.x
./px-install.sh install-operator
./px-sc.sh 
```

Wait for the Portworx Operator Pod to start successfully before proceeding 
```
oc get pods -n kube-system -w
```

5.  Create Portworx cluster using separate devices for application and metadata storage (Recommended)
```
./px-install.sh install-storage /dev/vdb /dev/vdc
```

Watch pods come up
```
oc get po -n kube-system -w
```

Check Portworx status
```
PX_POD=$(kubectl get pods -l name=portworx -n kube-system -o jsonpath='{.items[0].metadata.name}')
kubectl exec $PX_POD -n kube-system -- /opt/pwx/bin/pxctl status
```

-----------------------


### Install CPD 3.5

1.  Download and set up the CPD CLI to use for install https://github.com/IBM/cpd-cli/releases/download/v3.5.0/cpd-cli-linux-EE-3.5.1.tgz
   
```
cd/ibm
wget https://github.com/IBM/cpd-cli/releases/download/v3.5.0/cpd-cli-linux-EE-3.5.1.tgz
chmod +x cpd-cli-linux-EE-3.5.1.tgz
tar xvf cpd-cli-linux-EE-3.5.1.tgz
```

3.  Add your api key to the repo.yaml file.
```
vi /ibm/repo.yaml
```   

4.Export env vars used for install
```
export NAMESPACE=zen
export OPENSHIFT_USERNAME=kubeadmin
export OPENSHIFT_REGISTRY_PULL=image-registry.openshift-image-registry.svc:5000
```

5.  Setup cluster for the control plane (creates zen namespace) 

```
./cpd-cli adm --repo ./repo.yaml --assembly lite --arch x86_64 --namespace $NAMESPACE --apply
```

6.  Install cp4d control plane. https://www.ibm.com/support/knowledgecenter/SSQNUZ_3.5.0/cpd/install/rhos-install.html

```
./cpd-cli install  --repo repo.yaml --assembly lite --namespace $NAMESPACE --storageclass portworx-shared-gp3 --transfer-image-to $(oc registry info)/$NAMESPACE --cluster-pull-prefix $OPENSHIFT_REGISTRY_PULL/$NAMESPACE --target-registry-username $OPENSHIFT_USERNAME --target-registry-password=$(oc whoami -t) --latest-dependency  --insecure-skip-tls-verify  --accept-all-licenses --override-config portworx
```


Results: 
```
[INFO] [2020-12-04 12:31:16-0771] Access the web console at https://zen-cpd-zen.apps.cabana.cp.fyre.ibm.com

*** Initializing version configmap for assembly lite ***

[INFO] [2020-12-04 12:31:19-0513] Assembly version history update complete

[INFO] [2020-12-04 12:31:19-0516] *** Install/Upgrade for assembly lite completed successfully ***


3.5 Compute (zen)

CPU REQ: 2680m
CPU LIM: 14300m
MEM REQ: 5536Mi
MEM LIM: 18664Mi

```

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


