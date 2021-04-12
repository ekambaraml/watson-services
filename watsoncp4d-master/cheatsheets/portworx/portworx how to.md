Where to find Portworx releases / formal install instructions:  https://github.ibm.com/PrivateCloud-analytics/portworx-util/releases


How to configure Portworx not to run on all workers on CPD 2.5:  https://github.ibm.com/PrivateCloud-analytics/Zen/issues/11710

Where to get help?  Slack:  #cp4d-storage

Check Portworx status:

```
PX_POD=$(kubectl get pods -l name=portworx -n kube-system -o jsonpath='{.items[0].metadata.name}')
kubectl exec $PX_POD -n kube-system -- /opt/pwx/bin/pxctl status 
```

Check Portworx version:

```
PX_POD=$(kubectl get pods -l name=portworx -n kube-system -o jsonpath='{.items[0].metadata.name}')
    kubectl exec $PX_POD -n kube-system -- /opt/pwx/bin/pxctl --version
```

To run other commands, you may want to remote into pod so you can run pxctl directly:

```
PX_POD=$(kubectl get pods -l name=portworx -n kube-system -o jsonpath='{.items[0].metadata.name}')
oc exec -it $PX_POD -n kube-system -- /bin/bash
cd /opt/pwx/bin
```

Review portworx license
`pxctl license list`

list of volumes
`pxctl volume list`


View details for a specific volume: 
`pxctl volume inspect {volume-id}`

View portworx logs:  
`journalctl -ifu portworx*`

View portworx config file:  
`cat /etc/pwx/config.json`

Remove volume if mount is missing
```
lsblk
mount | grep volumeID
pxctl host detach {volume-id}
```

Verify Portworx is running on all worker nodes
`oc get pods --all-namespaces -o wide | grep portworx-api`

Verify Portworx StorageClasses are available
`oc get storageclasses | grep portworx`
 

Verify if your workers are setup for CRI-O container runtime as required by Portworx
`oc get nodes -o wide`

Create a Test pv using one of the portworx storageclasses

1.  Create the yaml
```
cat > testpx.yaml << EOF
kind: PersistentVolumeClaim
apiVersion: v1
metadata:
  name: testpx-pvc
spec:
  storageClassName: portworx-shared-sc
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 1Gi
EOF
```

2.  Create the PV
```
oc create -f testpx.yaml
```

3.  Verify the test pv bound successfully
`oc get pv`
