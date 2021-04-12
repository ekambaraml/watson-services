## Problem Solving & Troubleshooting Watson on Cloud Pak for Data

## Debugging with oc / kubectl the basics

### oc get 
Prints a table of the most important information about the specified resources in human readable plain text.   https://kubernetes.io/docs/reference/kubectl/overview/#resource-types

Commands to try

`oc get nodes`
`oc get pv`
`oc get storageclass`

### Flags useful for filtering responses or changing the detail of the output.
-n {namespace or project}
`oc get pods -n kube-system`

-o wide # format includes what worker node and IP
`oc get pods -o wide`

-l release={release name} # useful when you have multiple deployments in the same project or namespace
`oc get pod -l release=wd21`
`oc get pod -l release=wa14`

### To check the overall health of your cluster - start by making sure all nodes are ready and checking mem and cpu usage
`oc get nodes`
`oc adm top node`

### Start troubleshooting using the oc get pod and oc status commands to verify whether your pods and containers are running
`oc get pods`
`oc get status`
`oc get events`

### To limit your search to a particular service - use the label commands
Watson Assistant
`oc get job,pod --namespace cp4d-namespace -l release=watson-assistant`

Watson Discovery
`"oc get pods -l 'release in(admin,crust,mantle,core)'"`

Watson Speech Services
`oc get job,pod --namespace cp4d-namespace -l release=watson-speech-base`

Watson Knowledge Studio
`oc get pods -l release=wks`

### To check for pods not Running or not Ready:
`oc get pods| grep -Ev '1/1|2/2|3/3|4/4|5/5|6/6|7/7|8/8' | grep -v 'Completed'`

### To check for pods not Running or not Ready - Cluster wide - all Namespaces:
`oc get pods --all-namespaces | grep -Ev '1/1|2/2|3/3|4/4|5/5|6/6|7/7|8/8' | grep -v 'Completed'`

### To check details - do a `describe`
oc describe {object} {objectname}
`oc describe pod zen-metastoredb-0`
`oc describe job wa14-recommends-load-mongo`
`oc describe node {nodename}`

### To check logs 
oc logs {podname}
`oc log zen-metastoredb-0`


## Helm
Helm is a tool for managing Charts.  https://github.com/helm/helm

It is not installed by default, but you can grab it from the tiller pod
`cd /usr/local/bin`
`tiller_pod=$(oc get po | grep icpd-till | awk '{print $1}')`
`oc cp ${tiller_pod}:helm helm`
`chmod +x helm`
`./helm init --client-only`


### Error: could not find tiller
If you see this error, you have to re-establish the cerificate and key for Helm Tiller

`export TILLER_NAMESPACE=zen`
`oc get secret helm-secret -n $TILLER_NAMESPACE -o yaml|grep -A3 '^data:'|tail -3 | awk -F: '{system("echo "$2" |base64 --decode > "$1)}'`
`export HELM_TLS_CA_CERT=$PWD/ca.cert.pem`
`export HELM_TLS_CERT=$PWD/helm.cert.pem`
`export HELM_TLS_KEY=$PWD/helm.key.pem`

### Error: transport is closing
If you see `Error: transport is closing` with `helm` command, you need to add the parameter `--tls`.

### List all of the releases
helm ls --tls

### Check the status of your deployment
`helm status --tls wa14`
`helm status --tls wd21`

### How to see what values were specified with a deployment
`helm get values wa14 --tls`
`helm get values wd21 --tls`

### Run a test chart
helm test {release-name} --tls
`helm test wa14 --tls`
`helm test wd21 --tls`


## Testing Disk Speed

https://www.ibm.com/support/knowledgecenter/SSQNUZ_2.5.0/cpd/plan/rhos-reqs.html

### Test with FIO
Most important value is the 99th percentile sync time – should be under 10000 (Smaller is better)
Recommended write IOPS for production environments is 500 IOPS (for etcd) (Larger is better)

`fio --rw=write --ioengine=sync --fdatasync=1 --directory=$PWD --size=22m --bs=2300 --name=mytest`


### Test with dd

Disk latency test - the value must be better or comparable to: 512000 bytes (512 KB) copied, 1.7917 s, 286 KB/s 
`dd if=/dev/zero of=/testfile bs=512 count=1000 oflag=dsync`


Disk throughput test - the value must be better or comparable to: 1073741824 bytes (1.1 GB) copied, 5.14444 s, 209 MB/s
`dd if=/dev/zero of=/testfile bs=1G count=1 oflag=dsync`


## 1.  Problem loading the images

### Checking disk space 
`df -h`

### Verifying you are logged in and can see the images in the Docker Registry
`docker images`

### Search for a particular image
docker images | grep {imagename}
`docker images | grep opencontent-etcd-3`


## 2.  Problem during Helm Install

## How to tell if deployment is successful
Use the watch command in a second window to see the service deploy.   
Jobs will spin up pods
Watch pod status for trouble
Look for Jobs taking too long to complete (over a few minutes)
Stateful sets should go running first - Minio, Mongo, Postgres (keeper), etcd

### Specify release name to filter results to just one deployment
`watch oc get job,pod --namespace zen -l release=wd21`
`watch oc get job,pod --namespace zen -l release=wa14`

The deploy is successful when all job have completed successfully and when all pods are in `Running` or `Completed` status.    Note, Pods may take time to spin up after helm deployment completes.

### To check pod status
`oc get pod -l release=wd21`
`oc get pod -l release=wa14`

### To dig deeper 
oc describe object {objectname}
oc describe job {jobname}
oc describe pod {podname}

### To delete a problem resource 
oc delete pod {podname}


## 3.  Problem during Runtime

### Check for pods not Running or not Ready - Cluster wide - all Namespaces:
`oc get pods --all-namespaces | grep -Ev '1/1|2/2|3/3|4/4' | grep -v 'Completed'`

### Dig deeper 
oc describe object {objectname}
oc describe job {jobname}
oc describe pod {podname}

### Check logs 
oc logs {podname}

### Gather logs and configuration settings with openshiftCollector.sh
https://github.ibm.com/jennifer-wales/watsoncp4d/blob/master/scripts/openshiftCollector.sh
cd /ibm
./openshiftCollector.sh -c nfsserver.ibm.demo -u ocadmin -p ocadmin -n zen -t

### Reloading nginx useful for issues related to accessing instance
`oc -n zen get po | grep zen-core`
On any of the zen-core-xxxxxx (xxxxxxx is just the format of the pod name) pods run:

`oc -n zen exec -it zen-core-xxxxxxx -- /bin/bash`

Once inside the pod, reload the nginx configuration: 
`/user-home/.scripts/system/utils/nginx-reload`

## Watson Assistant

### For Errors accessing Tooling - Try Incognito Mode

### Way to restore postgres pods liveliness probe continues to fail

1.  Backup stateful set
```
oc get sts/{releasename}-store-postgres-keeper -o yaml >postgres.yaml
```

2.  Edit the stateful set
```
oc get sts/{releasename}-store-postgres-keeper
```
modify like below, save and exit
`- exec pg_isready -h localhost -p 5432` in 2 locations
to
`- exec true`

3.  Delete any problem postgres keeper pods and wait for them to recreate

4.  Once running, restore stateful set configuration back to original config
`- exec pg_isready -h localhost -p 5432`

### How to Restart Watson Assistant - Useful for a variety of problems
1.  Capture the current State

Run Test chart

```
export TILLER_NAMESPACE=zen
oc get secret helm-secret -n $TILLER_NAMESPACE -o yaml|grep -A3 '^data:'|tail -3 | awk -F: '{system("echo "$2" |base64 --decode > "$1)}'
export HELM_TLS_CA_CERT=$PWD/ca.cert.pem
export HELM_TLS_CERT=$PWD/helm.cert.pem
export HELM_TLS_KEY=$PWD/helm.key.pem
helm test watson-assistant --tls --timeout=18000 --cleanup
```


Note the desired number of replicas for your deployments and statefulsets

```
oc get deployments -l release=watson-assistant
oc get sts -l release=watson-assistant
```

 

2.  Scale them down, when down, control-C to exit watch
```
for i in `oc get deployments -l release=watson-assistant | awk '{print $1}'`; do oc scale deployments/$i --replicas=0; done
```

```
for i in `oc get sts -l release=watson-assistant | awk '{print $1}'`; do oc scale sts/$i --replicas=0; done
```

`watch oc get deployments,sts -l release=watson-assistant`

Note:  If pods are not stopping, check logs and if needed use `kubectl delete {podname}  --grace-period=0 --force` to kill them

 

3.  Scale up Statefulsets

Modify the following lines to the desired number of containers in each deployment

```
kubectl scale sts/watson-ass-05ba-ib-336f-server --replicas=3
kubectl scale sts/watson-ass-05ba-st-a617-keeper --replicas=3
kubectl scale sts/watson-assistant-clu-minio --replicas=4
kubectl scale sts/watson-assistant-etcd3 --replicas=5
kubectl scale sts/watson-assistant-redis-sentinel --replicas=3
kubectl scale sts/watson-assistant-redis-server --replicas=3
```

Wait until all of the statefulsets are back to Running state

`watch oc get sts -l release=watson-assistant`

3.  Scale up Deployments

Modify the following lines to the desired number of containers in each deployment

```
kubectl scale deployments/watson-ass-05ba-st-a617-sentinel --replicas=3
kubectl scale deployments/watson-assistant-addon-assistant-gw-deployment --replicas=1
kubectl scale deployments/watson-assistant-clu-embedding-service --replicas=1
kubectl scale deployments/watson-assistant-dialog --replicas=1
kubectl scale deployments/watson-assistant-ed-mm --replicas=1
kubectl scale deployments/watson-assistant-master --replicas=1
kubectl scale deployments/watson-assistant-nlu --replicas=1
kubectl scale deployments/watson-assistant-recommends --replicas=1
kubectl scale deployments/watson-assistant-skill-search --replicas=1
kubectl scale deployments/watson-assistant-spellchecker-en --replicas=1
kubectl scale deployments/watson-assistant-spellchecker-fr --replicas=1
kubectl scale deployments/watson-assistant-store --replicas=1
kubectl scale deployments/watson-assistant-store-postgres-proxy --replicas=2
kubectl scale deployments/watson-assistant-tas --replicas=1
kubectl scale deployments/watson-assistant-ui --replicas=1
```

Wait until all of the deployments are back to Running state

`watch oc get deployments -l release=watson-assistant`

`oc get pods| grep -Ev '1/1|2/2|3/3|4/4|5/5|6/6|7/7|8/8' | grep -v 'Completed'`


Validate with test script - use cleanup option to remove prior logs

```
export TILLER_NAMESPACE=zen
oc get secret helm-secret -n $TILLER_NAMESPACE -o yaml|grep -A3 '^data:'|tail -3 | awk -F: '{system("echo "$2" |base64 --decode > "$1)}'
export HELM_TLS_CA_CERT=$PWD/ca.cert.pem
export HELM_TLS_CERT=$PWD/helm.cert.pem
export HELM_TLS_KEY=$PWD/helm.key.pem
helm test watson-assistant --tls --timeout=18000 --cleanup
```



### Training not kicked off after importing skill from Public Cloud

If exporting from public, go into the Options tab in WA, and turn off Autocorrection, the new Irrelevance detection, and the new System Entities, make sure Sys-person and Sys-location are not enabled. Then, Exort from public into Cp4d.

## Watson Discovery

Troubleshooting elastic pod health
#To get out from this situation, you need to change the liveness probe/readiness probe of every elasticsearch statefulset by following commands:
```
oc edit sts $(oc get sts -l app.kubernetes.io/component=elastic,role=client -o jsonpath='{.items[0].metadata.name}')
oc edit sts $(oc get sts -l app.kubernetes.io/component=elastic,role=data -o jsonpath='{.items[0].metadata.name}')
oc edit sts $(oc get sts -l app.kubernetes.io/component=elastic,role=master -o jsonpath='{.items[0].metadata.name}')
```

In the editor, find following statement:
`localhost:9100/_cluster/health?local=true&wait_for_status=yellow&timeout=15s`

and change it to following:
`localhost:9100/_cluster/health?local=true&timeout=15s`
The point is to remove wait_for_status=yellow. If this condition is set, elasticserch will not get available until all indices get yellow or green status.

https://github.ibm.com/Watson-Discovery/disco-support/issues/292#issuecomment-19499902


### WKS Debug Script
https://pages.github.ibm.com/watson-discovery-and-exploration/WKS-issue-manager/cp4d/cp4d-installation-troubleshooting.md


