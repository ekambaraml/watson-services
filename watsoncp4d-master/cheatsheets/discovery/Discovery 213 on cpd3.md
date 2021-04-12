
# Discovery 2.1.3 on CP4D 3.0 (OpenShift 4.3) Draft 1


## Reference 

* Source: https://github.ibm.com/Watson-Discovery/do/wiki/Installing-Discovery-(Entitled-Registry)#Manual
* Documentation:  https://www.ibm.com/support/knowledgecenter/SSQNUZ_3.0.1/cpd/svc/watson/discovery-install-overview.html
* Readme:  https://github.com/ibm-cloud-docs/data-readmes/blob/master/discovery-README.md
* Requirements:  https://apps.na.collabserv.com/wikis/home?lang=en-us#!/wiki/Wd855b33ea663_4b57_a7c7_f5e8e37c2716/page/Watson%20Install%20Prereqs%20(Q4%202019%20Release)
* * Release info here: https://apps.na.collabserv.com/wikis/home?lang=en-us#!/wiki/Wd855b33ea663_4b57_a7c7_f5e8e37c2716/page/Watson%20on%20Cloud%20Pak%20Releases

URLs
* OpenShift Admin URL:  https://console-openshift-console.apps.cp4d-clustername
* Cloud Pak Admin URL:  https://zen-cpd-zen.apps.cp4d-clustername
  

CLI Login 
```
oc login -u kubeadmin -p `cat ~/auth/kubeadmin-password` 
oc login --token=$(oc whoami -t ) --server=https://api.cp4d-clustername:6443
```

_________________________________________________________

##  START HERE
This cheatsheet can be used to do a vanilla installation of Watson Discovery 2.1.3 on CP4D 3.0 on Openshift 4.3 with portworx Storage.  


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

#Verify vm.max_map_count = 262144
for node in $(oc get node -o=jsonpath={.items[*].metadata.name}); do echo -n "${node} " ; ssh core@${node} sysctl -a | grep vm.max_map_count ; done

#Verify Selinux set to Enforcing
for node in $(oc get node -o=jsonpath={.items[*].metadata.name}); do echo -n "${node} " ; ssh core@${node} getenforce; done

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

### Paste Below to fix elastic settings and CRIO
```
cat << EOF | oc create -f -
apiVersion: machineconfiguration.openshift.io/v1
kind: MachineConfig
metadata:
  labels:
    machineconfiguration.openshift.io/role: worker
  name: 99-crio
spec:
  config:
    ignition:
      version: 2.2.0
    storage:
      files:
      - contents:
          source: data:text/plain;charset=utf-8;base64,IyBUaGUgQ1JJLU8gY29uZmlndXJhdGlvbiBmaWxlIHNwZWNpZmllcyBhbGwgb2YgdGhlIGF2YWlsYWJsZSBjb25maWd1cmF0aW9uCiMgb3B0aW9ucyBhbmQgY29tbWFuZC1saW5lIGZsYWdzIGZvciB0aGUgY3Jpbyg4KSBPQ0kgS3ViZXJuZXRlcyBDb250YWluZXIgUnVudGltZQojIGRhZW1vbiwgYnV0IGluIGEgVE9NTCBmb3JtYXQgdGhhdCBjYW4gYmUgbW9yZSBlYXNpbHkgbW9kaWZpZWQgYW5kIHZlcnNpb25lZC4KIwojIFBsZWFzZSByZWZlciB0byBjcmlvLmNvbmYoNSkgZm9yIGRldGFpbHMgb2YgYWxsIGNvbmZpZ3VyYXRpb24gb3B0aW9ucy4KCiMgQ1JJLU8gc3VwcG9ydHMgcGFydGlhbCBjb25maWd1cmF0aW9uIHJlbG9hZCBkdXJpbmcgcnVudGltZSwgd2hpY2ggY2FuIGJlCiMgZG9uZSBieSBzZW5kaW5nIFNJR0hVUCB0byB0aGUgcnVubmluZyBwcm9jZXNzLiBDdXJyZW50bHkgc3VwcG9ydGVkIG9wdGlvbnMKIyBhcmUgZXhwbGljaXRseSBtZW50aW9uZWQgd2l0aDogJ1RoaXMgb3B0aW9uIHN1cHBvcnRzIGxpdmUgY29uZmlndXJhdGlvbgojIHJlbG9hZCcuCgojIENSSS1PIHJlYWRzIGl0cyBzdG9yYWdlIGRlZmF1bHRzIGZyb20gdGhlIGNvbnRhaW5lcnMtc3RvcmFnZS5jb25mKDUpIGZpbGUKIyBsb2NhdGVkIGF0IC9ldGMvY29udGFpbmVycy9zdG9yYWdlLmNvbmYuIE1vZGlmeSB0aGlzIHN0b3JhZ2UgY29uZmlndXJhdGlvbiBpZgojIHlvdSB3YW50IHRvIGNoYW5nZSB0aGUgc3lzdGVtJ3MgZGVmYXVsdHMuIElmIHlvdSB3YW50IHRvIG1vZGlmeSBzdG9yYWdlIGp1c3QKIyBmb3IgQ1JJLU8sIHlvdSBjYW4gY2hhbmdlIHRoZSBzdG9yYWdlIGNvbmZpZ3VyYXRpb24gb3B0aW9ucyBoZXJlLgpbY3Jpb10KCiMgUGF0aCB0byB0aGUgInJvb3QgZGlyZWN0b3J5Ii4gQ1JJLU8gc3RvcmVzIGFsbCBvZiBpdHMgZGF0YSwgaW5jbHVkaW5nCiMgY29udGFpbmVycyBpbWFnZXMsIGluIHRoaXMgZGlyZWN0b3J5Lgojcm9vdCA9ICIvdmFyL2xpYi9jb250YWluZXJzL3N0b3JhZ2UiCgojIFBhdGggdG8gdGhlICJydW4gZGlyZWN0b3J5Ii4gQ1JJLU8gc3RvcmVzIGFsbCBvZiBpdHMgc3RhdGUgaW4gdGhpcyBkaXJlY3RvcnkuCiNydW5yb290ID0gIi9ydW4vdXNlci8xMDAwIgoKIyBTdG9yYWdlIGRyaXZlciB1c2VkIHRvIG1hbmFnZSB0aGUgc3RvcmFnZSBvZiBpbWFnZXMgYW5kIGNvbnRhaW5lcnMuIFBsZWFzZQojIHJlZmVyIHRvIGNvbnRhaW5lcnMtc3RvcmFnZS5jb25mKDUpIHRvIHNlZSBhbGwgYXZhaWxhYmxlIHN0b3JhZ2UgZHJpdmVycy4KI3N0b3JhZ2VfZHJpdmVyID0gIm92ZXJsYXkiCgojIExpc3QgdG8gcGFzcyBvcHRpb25zIHRvIHRoZSBzdG9yYWdlIGRyaXZlci4gUGxlYXNlIHJlZmVyIHRvCiMgY29udGFpbmVycy1zdG9yYWdlLmNvbmYoNSkgdG8gc2VlIGFsbCBhdmFpbGFibGUgc3RvcmFnZSBvcHRpb25zLgojc3RvcmFnZV9vcHRpb24gPSBbCiNdCgojIFRoZSBkZWZhdWx0IGxvZyBkaXJlY3Rvcnkgd2hlcmUgYWxsIGxvZ3Mgd2lsbCBnbyB1bmxlc3MgZGlyZWN0bHkgc3BlY2lmaWVkIGJ5CiMgdGhlIGt1YmVsZXQuIFRoZSBsb2cgZGlyZWN0b3J5IHNwZWNpZmllZCBtdXN0IGJlIGFuIGFic29sdXRlIGRpcmVjdG9yeS4KIyBsb2dfZGlyID0gIi92YXIvbG9nL2NyaW8vcG9kcyIKCiMgTG9jYXRpb24gZm9yIENSSS1PIHRvIGxheSBkb3duIHRoZSB2ZXJzaW9uIGZpbGUKIyB2ZXJzaW9uX2ZpbGUgPSAiL3Zhci9saWIvY3Jpby92ZXJzaW9uIgoKIyBUaGUgY3Jpby5hcGkgdGFibGUgY29udGFpbnMgc2V0dGluZ3MgZm9yIHRoZSBrdWJlbGV0L2dSUEMgaW50ZXJmYWNlLgpbY3Jpby5hcGldCgojIFBhdGggdG8gQUZfTE9DQUwgc29ja2V0IG9uIHdoaWNoIENSSS1PIHdpbGwgbGlzdGVuLgojIGxpc3RlbiA9ICIvdmFyL3J1bi9jcmlvL2NyaW8uc29jayIKCiMgSG9zdCBJUCBjb25zaWRlcmVkIGFzIHRoZSBwcmltYXJ5IElQIHRvIHVzZSBieSBDUkktTyBmb3IgdGhpbmdzIHN1Y2ggYXMgaG9zdCBuZXR3b3JrIElQLgojIGhvc3RfaXAgPSAiIgoKIyBJUCBhZGRyZXNzIG9uIHdoaWNoIHRoZSBzdHJlYW0gc2VydmVyIHdpbGwgbGlzdGVuLgpzdHJlYW1fYWRkcmVzcyA9ICIiCgojIFRoZSBwb3J0IG9uIHdoaWNoIHRoZSBzdHJlYW0gc2VydmVyIHdpbGwgbGlzdGVuLgpzdHJlYW1fcG9ydCA9ICIxMDAxMCIKCiMgRW5hYmxlIGVuY3J5cHRlZCBUTFMgdHJhbnNwb3J0IG9mIHRoZSBzdHJlYW0gc2VydmVyLgojIHN0cmVhbV9lbmFibGVfdGxzID0gZmFsc2UKCiMgUGF0aCB0byB0aGUgeDUwOSBjZXJ0aWZpY2F0ZSBmaWxlIHVzZWQgdG8gc2VydmUgdGhlIGVuY3J5cHRlZCBzdHJlYW0uIFRoaXMKIyBmaWxlIGNhbiBjaGFuZ2UsIGFuZCBDUkktTyB3aWxsIGF1dG9tYXRpY2FsbHkgcGljayB1cCB0aGUgY2hhbmdlcyB3aXRoaW4gNQojIG1pbnV0ZXMuCiMgc3RyZWFtX3Rsc19jZXJ0ID0gIiIKCiMgUGF0aCB0byB0aGUga2V5IGZpbGUgdXNlZCB0byBzZXJ2ZSB0aGUgZW5jcnlwdGVkIHN0cmVhbS4gVGhpcyBmaWxlIGNhbgojIGNoYW5nZSBhbmQgQ1JJLU8gd2lsbCBhdXRvbWF0aWNhbGx5IHBpY2sgdXAgdGhlIGNoYW5nZXMgd2l0aGluIDUgbWludXRlcy4KIyBzdHJlYW1fdGxzX2tleSA9ICIiCgojIFBhdGggdG8gdGhlIHg1MDkgQ0EocykgZmlsZSB1c2VkIHRvIHZlcmlmeSBhbmQgYXV0aGVudGljYXRlIGNsaWVudAojIGNvbW11bmljYXRpb24gd2l0aCB0aGUgZW5jcnlwdGVkIHN0cmVhbS4gVGhpcyBmaWxlIGNhbiBjaGFuZ2UgYW5kIENSSS1PIHdpbGwKIyBhdXRvbWF0aWNhbGx5IHBpY2sgdXAgdGhlIGNoYW5nZXMgd2l0aGluIDUgbWludXRlcy4KIyBzdHJlYW1fdGxzX2NhID0gIiIKCiMgTWF4aW11bSBncnBjIHNlbmQgbWVzc2FnZSBzaXplIGluIGJ5dGVzLiBJZiBub3Qgc2V0IG9yIDw9MCwgdGhlbiBDUkktTyB3aWxsIGRlZmF1bHQgdG8gMTYgKiAxMDI0ICogMTAyNC4KIyBncnBjX21heF9zZW5kX21zZ19zaXplID0gMTY3NzcyMTYKCiMgTWF4aW11bSBncnBjIHJlY2VpdmUgbWVzc2FnZSBzaXplLiBJZiBub3Qgc2V0IG9yIDw9IDAsIHRoZW4gQ1JJLU8gd2lsbCBkZWZhdWx0IHRvIDE2ICogMTAyNCAqIDEwMjQuCiMgZ3JwY19tYXhfcmVjdl9tc2dfc2l6ZSA9IDE2Nzc3MjE2CgojIFRoZSBjcmlvLnJ1bnRpbWUgdGFibGUgY29udGFpbnMgc2V0dGluZ3MgcGVydGFpbmluZyB0byB0aGUgT0NJIHJ1bnRpbWUgdXNlZAojIGFuZCBvcHRpb25zIGZvciBob3cgdG8gc2V0IHVwIGFuZCBtYW5hZ2UgdGhlIE9DSSBydW50aW1lLgpbY3Jpby5ydW50aW1lXQoKIyBBIGxpc3Qgb2YgdWxpbWl0cyB0byBiZSBzZXQgaW4gY29udGFpbmVycyBieSBkZWZhdWx0LCBzcGVjaWZpZWQgYXMKIyAiPHVsaW1pdCBuYW1lPj08c29mdCBsaW1pdD46PGhhcmQgbGltaXQ+IiwgZm9yIGV4YW1wbGU6CiMgIm5vZmlsZT0xMDI0OjIwNDgiCiMgSWYgbm90aGluZyBpcyBzZXQgaGVyZSwgc2V0dGluZ3Mgd2lsbCBiZSBpbmhlcml0ZWQgZnJvbSB0aGUgQ1JJLU8gZGFlbW9uCiNkZWZhdWx0X3VsaW1pdHMgPSBbCiNdCgojIGRlZmF1bHRfcnVudGltZSBpcyB0aGUgX25hbWVfIG9mIHRoZSBPQ0kgcnVudGltZSB0byBiZSB1c2VkIGFzIHRoZSBkZWZhdWx0LgojIFRoZSBuYW1lIGlzIG1hdGNoZWQgYWdhaW5zdCB0aGUgcnVudGltZXMgbWFwIGJlbG93LgojIGRlZmF1bHRfcnVudGltZSA9ICJydW5jIgoKIyBJZiB0cnVlLCB0aGUgcnVudGltZSB3aWxsIG5vdCB1c2UgcGl2b3Rfcm9vdCwgYnV0IGluc3RlYWQgdXNlIE1TX01PVkUuCiMgbm9fcGl2b3QgPSBmYWxzZQoKIyBQYXRoIHRvIHRoZSBjb25tb24gYmluYXJ5LCB1c2VkIGZvciBtb25pdG9yaW5nIHRoZSBPQ0kgcnVudGltZS4KIyBXaWxsIGJlIHNlYXJjaGVkIGZvciB1c2luZyAvVXNlcnMvYmRhdmlkc29uL2JpbjovdXNyL2xvY2FsL29wdC9weXRob24vbGliZXhlYy9iaW46L3Vzci9sb2NhbC9vcHQvdGVycmFmb3JtQDAuMTEvYmluOi91c3IvbG9jYWwvb3B0L25vZGVAOC9iaW46L3Vzci9sb2NhbC9vcHQvY3VybC9iaW46L1VzZXJzL2JkYXZpZHNvbi9wZXJsNS9iaW46L3Vzci9sb2NhbC9iaW46L3Vzci9iaW46L2JpbjovdXNyL3NiaW46L3NiaW46L0xpYnJhcnkvQXBwbGUvdXNyL2JpbjovVXNlcnMvYmRhdmlkc29uL2JpbjovdXNyL2xvY2FsL29wdC9weXRob24vbGliZXhlYy9iaW46L3Vzci9sb2NhbC9vcHQvdGVycmFmb3JtQDAuMTEvYmluOi91c3IvbG9jYWwvb3B0L25vZGVAOC9iaW46L3Vzci9sb2NhbC9vcHQvY3VybC9iaW46L1VzZXJzL2JkYXZpZHNvbi9wZXJsNS9iaW46L3Vzci9sb2NhbC9nby9iaW46L1VzZXJzL2JkYXZpZHNvbi9nby9iaW46L29wdC9ncm9vdnkvYmluOi9vcHQvbWF2ZW4vYmluOi9BcHBsaWNhdGlvbnMvVk13YXJlIE9WRiBUb29sOi9Vc2Vycy9iZGF2aWRzb24vLmZhYnJpYzgvYmluOi9Vc2Vycy9iZGF2aWRzb24vaXN0aW8tMC4xLjYvYmluOi91c3IvbG9jYWwvZ28vYmluOi9Vc2Vycy9iZGF2aWRzb24vZ28vYmluOi9vcHQvZ3Jvb3Z5L2Jpbjovb3B0L21hdmVuL2JpbjovQXBwbGljYXRpb25zL1ZNd2FyZSBPVkYgVG9vbDovVXNlcnMvYmRhdmlkc29uLy5mYWJyaWM4L2JpbjovVXNlcnMvYmRhdmlkc29uL2lzdGlvLTAuMS42L2JpbiBpZiBlbXB0eS4KY29ubW9uID0gIi91c3IvbGliZXhlYy9jcmlvL2Nvbm1vbiIKCiMgQ2dyb3VwIHNldHRpbmcgZm9yIGNvbm1vbgpjb25tb25fY2dyb3VwID0gInBvZCIKCiMgRW52aXJvbm1lbnQgdmFyaWFibGUgbGlzdCBmb3IgdGhlIGNvbm1vbiBwcm9jZXNzLCB1c2VkIGZvciBwYXNzaW5nIG5lY2Vzc2FyeQojIGVudmlyb25tZW50IHZhcmlhYmxlcyB0byBjb25tb24gb3IgdGhlIHJ1bnRpbWUuCiMgY29ubW9uX2VudiA9IFsKIyAJIlBBVEg9L3Vzci9sb2NhbC9zYmluOi91c3IvbG9jYWwvYmluOi91c3Ivc2JpbjovdXNyL2Jpbjovc2JpbjovYmluIiwKIyBdCgojIElmIHRydWUsIFNFTGludXggd2lsbCBiZSB1c2VkIGZvciBwb2Qgc2VwYXJhdGlvbiBvbiB0aGUgaG9zdC4KIyBzZWxpbnV4ID0gdHJ1ZQoKIyBQYXRoIHRvIHRoZSBzZWNjb21wLmpzb24gcHJvZmlsZSB3aGljaCBpcyB1c2VkIGFzIHRoZSBkZWZhdWx0IHNlY2NvbXAgcHJvZmlsZQojIGZvciB0aGUgcnVudGltZS4gSWYgbm90IHNwZWNpZmllZCwgdGhlbiB0aGUgaW50ZXJuYWwgZGVmYXVsdCBzZWNjb21wIHByb2ZpbGUKIyB3aWxsIGJlIHVzZWQuCiMgc2VjY29tcF9wcm9maWxlID0gIi9ldGMvY3Jpby9zZWNjb21wLmpzb24iCgojIFVzZWQgdG8gY2hhbmdlIHRoZSBuYW1lIG9mIHRoZSBkZWZhdWx0IEFwcEFybW9yIHByb2ZpbGUgb2YgQ1JJLU8uIFRoZSBkZWZhdWx0CiMgcHJvZmlsZSBuYW1lIGlzICJjcmlvLWRlZmF1bHQtIiBmb2xsb3dlZCBieSB0aGUgdmVyc2lvbiBzdHJpbmcgb2YgQ1JJLU8uCmFwcGFybW9yX3Byb2ZpbGUgPSAiY3Jpby1kZWZhdWx0IgoKIyBDZ3JvdXAgbWFuYWdlbWVudCBpbXBsZW1lbnRhdGlvbiB1c2VkIGZvciB0aGUgcnVudGltZS4KY2dyb3VwX21hbmFnZXIgPSAic3lzdGVtZCIKCiMgTGlzdCBvZiBkZWZhdWx0IGNhcGFiaWxpdGllcyBmb3IgY29udGFpbmVycy4gSWYgaXQgaXMgZW1wdHkgb3IgY29tbWVudGVkIG91dCwKIyBvbmx5IHRoZSBjYXBhYmlsaXRpZXMgZGVmaW5lZCBpbiB0aGUgY29udGFpbmVycyBqc29uIGZpbGUgYnkgdGhlIHVzZXIva3ViZQojIHdpbGwgYmUgYWRkZWQuCiMgZGVmYXVsdF9jYXBhYmlsaXRpZXMgPSBbCiMgCSJDSE9XTiIsCiMgCSJEQUNfT1ZFUlJJREUiLAojIAkiRlNFVElEIiwKIyAJIkZPV05FUiIsCiMgCSJORVRfUkFXIiwKIyAJIlNFVEdJRCIsCiMgCSJTRVRVSUQiLAojIAkiU0VUUENBUCIsCiMgCSJORVRfQklORF9TRVJWSUNFIiwKIyAJIlNZU19DSFJPT1QiLAojIAkiS0lMTCIsCiMgXQoKIyBMaXN0IG9mIGRlZmF1bHQgc3lzY3Rscy4gSWYgaXQgaXMgZW1wdHkgb3IgY29tbWVudGVkIG91dCwgb25seSB0aGUgc3lzY3RscwojIGRlZmluZWQgaW4gdGhlIGNvbnRhaW5lciBqc29uIGZpbGUgYnkgdGhlIHVzZXIva3ViZSB3aWxsIGJlIGFkZGVkLgojIGRlZmF1bHRfc3lzY3RscyA9IFsKIyBdCgojIExpc3Qgb2YgYWRkaXRpb25hbCBkZXZpY2VzLiBzcGVjaWZpZWQgYXMKIyAiPGRldmljZS1vbi1ob3N0Pjo8ZGV2aWNlLW9uLWNvbnRhaW5lcj46PHBlcm1pc3Npb25zPiIsIGZvciBleGFtcGxlOiAiLS1kZXZpY2U9L2Rldi9zZGM6L2Rldi94dmRjOnJ3bSIuCiNJZiBpdCBpcyBlbXB0eSBvciBjb21tZW50ZWQgb3V0LCBvbmx5IHRoZSBkZXZpY2VzCiMgZGVmaW5lZCBpbiB0aGUgY29udGFpbmVyIGpzb24gZmlsZSBieSB0aGUgdXNlci9rdWJlIHdpbGwgYmUgYWRkZWQuCiMgYWRkaXRpb25hbF9kZXZpY2VzID0gWwojIF0KCiMgUGF0aCB0byBPQ0kgaG9va3MgZGlyZWN0b3JpZXMgZm9yIGF1dG9tYXRpY2FsbHkgZXhlY3V0ZWQgaG9va3MuCiMgTm90ZTogdGhlIGRlZmF1bHQgaXMganVzdCAvdXNyL3NoYXJlL2NvbnRhaW5lcnMvb2NpL2hvb2tzLmQsIGJ1dCAvdXNyIGlzIGltbXV0YWJsZSBpbiBSSENPUwojIHNvIHdlIGFkZCAvZXRjL2NvbnRhaW5lcnMvb2NpL2hvb2tzLmQgYXMgd2VsbApob29rc19kaXIgPSBbCiAgICAiL2V0Yy9jb250YWluZXJzL29jaS9ob29rcy5kIiwKXQoKIyBMaXN0IG9mIGRlZmF1bHQgbW91bnRzIGZvciBlYWNoIGNvbnRhaW5lci4gKipEZXByZWNhdGVkOioqIHRoaXMgb3B0aW9uIHdpbGwKIyBiZSByZW1vdmVkIGluIGZ1dHVyZSB2ZXJzaW9ucyBpbiBmYXZvciBvZiBkZWZhdWx0X21vdW50c19maWxlLgojIGRlZmF1bHRfbW91bnRzID0gWwojIAkiL3Vzci9zaGFyZS9yaGVsL3NlY3JldHM6L3J1bi9zZWNyZXRzIiwKIyBdCgojIFBhdGggdG8gdGhlIGZpbGUgc3BlY2lmeWluZyB0aGUgZGVmYXVsdHMgbW91bnRzIGZvciBlYWNoIGNvbnRhaW5lci4gVGhlCiMgZm9ybWF0IG9mIHRoZSBjb25maWcgaXMgL1NSQzovRFNULCBvbmUgbW91bnQgcGVyIGxpbmUuIE5vdGljZSB0aGF0IENSSS1PIHJlYWRzCiMgaXRzIGRlZmF1bHQgbW91bnRzIGZyb20gdGhlIGZvbGxvd2luZyB0d28gZmlsZXM6CiMKIyAgIDEpIC9ldGMvY29udGFpbmVycy9tb3VudHMuY29uZiAoaS5lLiwgZGVmYXVsdF9tb3VudHNfZmlsZSk6IFRoaXMgaXMgdGhlCiMgICAgICBvdmVycmlkZSBmaWxlLCB3aGVyZSB1c2VycyBjYW4gZWl0aGVyIGFkZCBpbiB0aGVpciBvd24gZGVmYXVsdCBtb3VudHMsIG9yCiMgICAgICBvdmVycmlkZSB0aGUgZGVmYXVsdCBtb3VudHMgc2hpcHBlZCB3aXRoIHRoZSBwYWNrYWdlLgojCiMgICAyKSAvdXNyL3NoYXJlL2NvbnRhaW5lcnMvbW91bnRzLmNvbmY6IFRoaXMgaXMgdGhlIGRlZmF1bHQgZmlsZSByZWFkIGZvcgojICAgICAgbW91bnRzLiBJZiB5b3Ugd2FudCBDUkktTyB0byByZWFkIGZyb20gYSBkaWZmZXJlbnQsIHNwZWNpZmljIG1vdW50cyBmaWxlLAojICAgICAgeW91IGNhbiBjaGFuZ2UgdGhlIGRlZmF1bHRfbW91bnRzX2ZpbGUuIE5vdGUsIGlmIHRoaXMgaXMgZG9uZSwgQ1JJLU8gd2lsbAojICAgICAgb25seSBhZGQgbW91bnRzIGl0IGZpbmRzIGluIHRoaXMgZmlsZS4KIwojZGVmYXVsdF9tb3VudHNfZmlsZSA9ICIiCgojIE1heGltdW0gbnVtYmVyIG9mIHByb2Nlc3NlcyBhbGxvd2VkIGluIGEgY29udGFpbmVyLgpwaWRzX2xpbWl0ID0gODE5MgoKIyBNYXhpbXVtIHNpemVkIGFsbG93ZWQgZm9yIHRoZSBjb250YWluZXIgbG9nIGZpbGUuIE5lZ2F0aXZlIG51bWJlcnMgaW5kaWNhdGUKIyB0aGF0IG5vIHNpemUgbGltaXQgaXMgaW1wb3NlZC4gSWYgaXQgaXMgcG9zaXRpdmUsIGl0IG11c3QgYmUgPj0gODE5MiB0bwojIG1hdGNoL2V4Y2VlZCBjb25tb24ncyByZWFkIGJ1ZmZlci4gVGhlIGZpbGUgaXMgdHJ1bmNhdGVkIGFuZCByZS1vcGVuZWQgc28gdGhlCiMgbGltaXQgaXMgbmV2ZXIgZXhjZWVkZWQuCiMgbG9nX3NpemVfbWF4ID0gLTEKCiMgV2hldGhlciBjb250YWluZXIgb3V0cHV0IHNob3VsZCBiZSBsb2dnZWQgdG8gam91cm5hbGQgaW4gYWRkaXRpb24gdG8gdGhlIGt1YmVyZW50ZXMgbG9nIGZpbGUKIyBsb2dfdG9fam91cm5hbGQgPSBmYWxzZQoKIyBQYXRoIHRvIGRpcmVjdG9yeSBpbiB3aGljaCBjb250YWluZXIgZXhpdCBmaWxlcyBhcmUgd3JpdHRlbiB0byBieSBjb25tb24uCiMgY29udGFpbmVyX2V4aXRzX2RpciA9ICIvdmFyL3J1bi9jcmlvL2V4aXRzIgoKIyBQYXRoIHRvIGRpcmVjdG9yeSBmb3IgY29udGFpbmVyIGF0dGFjaCBzb2NrZXRzLgojIGNvbnRhaW5lcl9hdHRhY2hfc29ja2V0X2RpciA9ICIvdmFyL3J1bi9jcmlvIgoKIyBUaGUgcHJlZml4IHRvIHVzZSBmb3IgdGhlIHNvdXJjZSBvZiB0aGUgYmluZCBtb3VudHMuCiMgYmluZF9tb3VudF9wcmVmaXggPSAiIgoKIyBJZiBzZXQgdG8gdHJ1ZSwgYWxsIGNvbnRhaW5lcnMgd2lsbCBydW4gaW4gcmVhZC1vbmx5IG1vZGUuCiMgcmVhZF9vbmx5ID0gZmFsc2UKCiMgQ2hhbmdlcyB0aGUgdmVyYm9zaXR5IG9mIHRoZSBsb2dzIGJhc2VkIG9uIHRoZSBsZXZlbCBpdCBpcyBzZXQgdG8uIE9wdGlvbnMKIyBhcmUgZmF0YWwsIHBhbmljLCBlcnJvciwgd2FybiwgaW5mbywgYW5kIGRlYnVnLiBUaGlzIG9wdGlvbiBzdXBwb3J0cyBsaXZlCiMgY29uZmlndXJhdGlvbiByZWxvYWQuCiMgbG9nX2xldmVsID0gImVycm9yIgoKIyBUaGUgVUlEIG1hcHBpbmdzIGZvciB0aGUgdXNlciBuYW1lc3BhY2Ugb2YgZWFjaCBjb250YWluZXIuIEEgcmFuZ2UgaXMKIyBzcGVjaWZpZWQgaW4gdGhlIGZvcm0gY29udGFpbmVyVUlEOkhvc3RVSUQ6U2l6ZS4gTXVsdGlwbGUgcmFuZ2VzIG11c3QgYmUKIyBzZXBhcmF0ZWQgYnkgY29tbWEuCiMgdWlkX21hcHBpbmdzID0gIiIKCiMgVGhlIEdJRCBtYXBwaW5ncyBmb3IgdGhlIHVzZXIgbmFtZXNwYWNlIG9mIGVhY2ggY29udGFpbmVyLiBBIHJhbmdlIGlzCiMgc3BlY2lmaWVkIGluIHRoZSBmb3JtIGNvbnRhaW5lckdJRDpIb3N0R0lEOlNpemUuIE11bHRpcGxlIHJhbmdlcyBtdXN0IGJlCiMgc2VwYXJhdGVkIGJ5IGNvbW1hLgojIGdpZF9tYXBwaW5ncyA9ICIiCgojIFRoZSBtaW5pbWFsIGFtb3VudCBvZiB0aW1lIGluIHNlY29uZHMgdG8gd2FpdCBiZWZvcmUgaXNzdWluZyBhIHRpbWVvdXQKIyByZWdhcmRpbmcgdGhlIHByb3BlciB0ZXJtaW5hdGlvbiBvZiB0aGUgY29udGFpbmVyLgojIGN0cl9zdG9wX3RpbWVvdXQgPSAwCgojIE1hbmFnZU5ldHdvcmtOU0xpZmVjeWNsZSBkZXRlcm1pbmVzIHdoZXRoZXIgd2UgcGluIGFuZCByZW1vdmUgbmV0d29yayBuYW1lc3BhY2UKIyBhbmQgbWFuYWdlIGl0cyBsaWZlY3ljbGUuCiMgbWFuYWdlX25ldHdvcmtfbnNfbGlmZWN5Y2xlID0gZmFsc2UKCiMgVGhlICJjcmlvLnJ1bnRpbWUucnVudGltZXMiIHRhYmxlIGRlZmluZXMgYSBsaXN0IG9mIE9DSSBjb21wYXRpYmxlIHJ1bnRpbWVzLgojIFRoZSBydW50aW1lIHRvIHVzZSBpcyBwaWNrZWQgYmFzZWQgb24gdGhlIHJ1bnRpbWVfaGFuZGxlciBwcm92aWRlZCBieSB0aGUgQ1JJLgojIElmIG5vIHJ1bnRpbWVfaGFuZGxlciBpcyBwcm92aWRlZCwgdGhlIHJ1bnRpbWUgd2lsbCBiZSBwaWNrZWQgYmFzZWQgb24gdGhlIGxldmVsCiMgb2YgdHJ1c3Qgb2YgdGhlIHdvcmtsb2FkLiBFYWNoIGVudHJ5IGluIHRoZSB0YWJsZSBzaG91bGQgZm9sbG93IHRoZSBmb3JtYXQ6CiMKI1tjcmlvLnJ1bnRpbWUucnVudGltZXMucnVudGltZS1oYW5kbGVyXQojICBydW50aW1lX3BhdGggPSAiL3BhdGgvdG8vdGhlL2V4ZWN1dGFibGUiCiMgIHJ1bnRpbWVfdHlwZSA9ICJvY2kiCiMgIHJ1bnRpbWVfcm9vdCA9ICIvcGF0aC90by90aGUvcm9vdCIKIwojIFdoZXJlOgojIC0gcnVudGltZS1oYW5kbGVyOiBuYW1lIHVzZWQgdG8gaWRlbnRpZnkgdGhlIHJ1bnRpbWUKIyAtIHJ1bnRpbWVfcGF0aCAob3B0aW9uYWwsIHN0cmluZyk6IGFic29sdXRlIHBhdGggdG8gdGhlIHJ1bnRpbWUgZXhlY3V0YWJsZSBpbgojICAgdGhlIGhvc3QgZmlsZXN5c3RlbS4gSWYgb21pdHRlZCwgdGhlIHJ1bnRpbWUtaGFuZGxlciBpZGVudGlmaWVyIHNob3VsZCBtYXRjaAojICAgdGhlIHJ1bnRpbWUgZXhlY3V0YWJsZSBuYW1lLCBhbmQgdGhlIHJ1bnRpbWUgZXhlY3V0YWJsZSBzaG91bGQgYmUgcGxhY2VkCiMgICBpbiAvVXNlcnMvYmRhdmlkc29uL2JpbjovdXNyL2xvY2FsL29wdC9weXRob24vbGliZXhlYy9iaW46L3Vzci9sb2NhbC9vcHQvdGVycmFmb3JtQDAuMTEvYmluOi91c3IvbG9jYWwvb3B0L25vZGVAOC9iaW46L3Vzci9sb2NhbC9vcHQvY3VybC9iaW46L1VzZXJzL2JkYXZpZHNvbi9wZXJsNS9iaW46L3Vzci9sb2NhbC9iaW46L3Vzci9iaW46L2JpbjovdXNyL3NiaW46L3NiaW46L0xpYnJhcnkvQXBwbGUvdXNyL2JpbjovVXNlcnMvYmRhdmlkc29uL2JpbjovdXNyL2xvY2FsL29wdC9weXRob24vbGliZXhlYy9iaW46L3Vzci9sb2NhbC9vcHQvdGVycmFmb3JtQDAuMTEvYmluOi91c3IvbG9jYWwvb3B0L25vZGVAOC9iaW46L3Vzci9sb2NhbC9vcHQvY3VybC9iaW46L1VzZXJzL2JkYXZpZHNvbi9wZXJsNS9iaW46L3Vzci9sb2NhbC9nby9iaW46L1VzZXJzL2JkYXZpZHNvbi9nby9iaW46L29wdC9ncm9vdnkvYmluOi9vcHQvbWF2ZW4vYmluOi9BcHBsaWNhdGlvbnMvVk13YXJlIE9WRiBUb29sOi9Vc2Vycy9iZGF2aWRzb24vLmZhYnJpYzgvYmluOi9Vc2Vycy9iZGF2aWRzb24vaXN0aW8tMC4xLjYvYmluOi91c3IvbG9jYWwvZ28vYmluOi9Vc2Vycy9iZGF2aWRzb24vZ28vYmluOi9vcHQvZ3Jvb3Z5L2Jpbjovb3B0L21hdmVuL2JpbjovQXBwbGljYXRpb25zL1ZNd2FyZSBPVkYgVG9vbDovVXNlcnMvYmRhdmlkc29uLy5mYWJyaWM4L2JpbjovVXNlcnMvYmRhdmlkc29uL2lzdGlvLTAuMS42L2Jpbi4KIyAtIHJ1bnRpbWVfdHlwZSAob3B0aW9uYWwsIHN0cmluZyk6IHR5cGUgb2YgcnVudGltZSwgb25lIG9mOiAib2NpIiwgInZtIi4gSWYKIyAgIG9taXR0ZWQsIGFuICJvY2kiIHJ1bnRpbWUgaXMgYXNzdW1lZC4KIyAtIHJ1bnRpbWVfcm9vdCAob3B0aW9uYWwsIHN0cmluZyk6IHJvb3QgZGlyZWN0b3J5IGZvciBzdG9yYWdlIG9mIGNvbnRhaW5lcnMKIyAgIHN0YXRlLgoKCiMgW2NyaW8ucnVudGltZS5ydW50aW1lcy5ydW5jXQojIHJ1bnRpbWVfcGF0aCA9ICIiCiMgcnVudGltZV90eXBlID0gIm9jaSIKIyBydW50aW1lX3Jvb3QgPSAiL3J1bi9ydW5jIgoKCiMgS2F0YSBDb250YWluZXJzIGlzIGFuIE9DSSBydW50aW1lLCB3aGVyZSBjb250YWluZXJzIGFyZSBydW4gaW5zaWRlIGxpZ2h0d2VpZ2h0CiMgVk1zLiBLYXRhIHByb3ZpZGVzIGFkZGl0aW9uYWwgaXNvbGF0aW9uIHRvd2FyZHMgdGhlIGhvc3QsIG1pbmltaXppbmcgdGhlIGhvc3QgYXR0YWNrCiMgc3VyZmFjZSBhbmQgbWl0aWdhdGluZyB0aGUgY29uc2VxdWVuY2VzIG9mIGNvbnRhaW5lcnMgYnJlYWtvdXQuCgojIEthdGEgQ29udGFpbmVycyB3aXRoIHRoZSBkZWZhdWx0IGNvbmZpZ3VyZWQgVk1NCiNbY3Jpby5ydW50aW1lLnJ1bnRpbWVzLmthdGEtcnVudGltZV0KCiMgS2F0YSBDb250YWluZXJzIHdpdGggdGhlIFFFTVUgVk1NCiNbY3Jpby5ydW50aW1lLnJ1bnRpbWVzLmthdGEtcWVtdV0KCiMgS2F0YSBDb250YWluZXJzIHdpdGggdGhlIEZpcmVjcmFja2VyIFZNTQojW2NyaW8ucnVudGltZS5ydW50aW1lcy5rYXRhLWZjXQoKIyBUaGUgY3Jpby5pbWFnZSB0YWJsZSBjb250YWlucyBzZXR0aW5ncyBwZXJ0YWluaW5nIHRvIHRoZSBtYW5hZ2VtZW50IG9mIE9DSSBpbWFnZXMuCiMKIyBDUkktTyByZWFkcyBpdHMgY29uZmlndXJlZCByZWdpc3RyaWVzIGRlZmF1bHRzIGZyb20gdGhlIHN5c3RlbSB3aWRlCiMgY29udGFpbmVycy1yZWdpc3RyaWVzLmNvbmYoNSkgbG9jYXRlZCBpbiAvZXRjL2NvbnRhaW5lcnMvcmVnaXN0cmllcy5jb25mLiBJZgojIHlvdSB3YW50IHRvIG1vZGlmeSBqdXN0IENSSS1PLCB5b3UgY2FuIGNoYW5nZSB0aGUgcmVnaXN0cmllcyBjb25maWd1cmF0aW9uIGluCiMgdGhpcyBmaWxlLiBPdGhlcndpc2UsIGxlYXZlIGluc2VjdXJlX3JlZ2lzdHJpZXMgYW5kIHJlZ2lzdHJpZXMgY29tbWVudGVkIG91dCB0bwojIHVzZSB0aGUgc3lzdGVtJ3MgZGVmYXVsdHMgZnJvbSAvZXRjL2NvbnRhaW5lcnMvcmVnaXN0cmllcy5jb25mLgpbY3Jpby5pbWFnZV0KCiMgRGVmYXVsdCB0cmFuc3BvcnQgZm9yIHB1bGxpbmcgaW1hZ2VzIGZyb20gYSByZW1vdGUgY29udGFpbmVyIHN0b3JhZ2UuCiMgZGVmYXVsdF90cmFuc3BvcnQgPSAiZG9ja2VyOi8vIgoKIyBUaGUgcGF0aCB0byBhIGZpbGUgY29udGFpbmluZyBjcmVkZW50aWFscyBuZWNlc3NhcnkgZm9yIHB1bGxpbmcgaW1hZ2VzIGZyb20KIyBzZWN1cmUgcmVnaXN0cmllcy4gVGhlIGZpbGUgaXMgc2ltaWxhciB0byB0aGF0IG9mIC92YXIvbGliL2t1YmVsZXQvY29uZmlnLmpzb24KZ2xvYmFsX2F1dGhfZmlsZSA9ICIvdmFyL2xpYi9rdWJlbGV0L2NvbmZpZy5qc29uIgoKIyBUaGUgaW1hZ2UgdXNlZCB0byBpbnN0YW50aWF0ZSBpbmZyYSBjb250YWluZXJzLgojIFRoaXMgb3B0aW9uIHN1cHBvcnRzIGxpdmUgY29uZmlndXJhdGlvbiByZWxvYWQuCnBhdXNlX2ltYWdlID0gInF1YXkuaW8vb3BlbnNoaWZ0LXJlbGVhc2UtZGV2L29jcC12NC4wLWFydC1kZXZAc2hhMjU2OjJkYzNiZGNiMmIwYmYxZDZjNmFlNzQ5YmUwMTYzZTZkN2NhODEzZWNmYmE1ZTVmNWQ4ODk3MGM3M2E5ZDEyYTkiCgojIFRoZSBwYXRoIHRvIGEgZmlsZSBjb250YWluaW5nIGNyZWRlbnRpYWxzIHNwZWNpZmljIGZvciBwdWxsaW5nIHRoZSBwYXVzZV9pbWFnZSBmcm9tCiMgYWJvdmUuIFRoZSBmaWxlIGlzIHNpbWlsYXIgdG8gdGhhdCBvZiAvdmFyL2xpYi9rdWJlbGV0L2NvbmZpZy5qc29uCiMgVGhpcyBvcHRpb24gc3VwcG9ydHMgbGl2ZSBjb25maWd1cmF0aW9uIHJlbG9hZC4KcGF1c2VfaW1hZ2VfYXV0aF9maWxlID0gIi92YXIvbGliL2t1YmVsZXQvY29uZmlnLmpzb24iCgojIFRoZSBjb21tYW5kIHRvIHJ1biB0byBoYXZlIGEgY29udGFpbmVyIHN0YXkgaW4gdGhlIHBhdXNlZCBzdGF0ZS4KIyBUaGlzIG9wdGlvbiBzdXBwb3J0cyBsaXZlIGNvbmZpZ3VyYXRpb24gcmVsb2FkLgpwYXVzZV9jb21tYW5kID0gIi91c3IvYmluL3BvZCIKCiMgUGF0aCB0byB0aGUgZmlsZSB3aGljaCBkZWNpZGVzIHdoYXQgc29ydCBvZiBwb2xpY3kgd2UgdXNlIHdoZW4gZGVjaWRpbmcKIyB3aGV0aGVyIG9yIG5vdCB0byB0cnVzdCBhbiBpbWFnZSB0aGF0IHdlJ3ZlIHB1bGxlZC4gSXQgaXMgbm90IHJlY29tbWVuZGVkIHRoYXQKIyB0aGlzIG9wdGlvbiBiZSB1c2VkLCBhcyB0aGUgZGVmYXVsdCBiZWhhdmlvciBvZiB1c2luZyB0aGUgc3lzdGVtLXdpZGUgZGVmYXVsdAojIHBvbGljeSAoaS5lLiwgL2V0Yy9jb250YWluZXJzL3BvbGljeS5qc29uKSBpcyBtb3N0IG9mdGVuIHByZWZlcnJlZC4gUGxlYXNlCiMgcmVmZXIgdG8gY29udGFpbmVycy1wb2xpY3kuanNvbig1KSBmb3IgbW9yZSBkZXRhaWxzLgojIHNpZ25hdHVyZV9wb2xpY3kgPSAiIgoKIyBMaXN0IG9mIHJlZ2lzdHJpZXMgdG8gc2tpcCBUTFMgdmVyaWZpY2F0aW9uIGZvciBwdWxsaW5nIGltYWdlcy4gUGxlYXNlCiMgY29uc2lkZXIgY29uZmlndXJpbmcgdGhlIHJlZ2lzdHJpZXMgdmlhIC9ldGMvY29udGFpbmVycy9yZWdpc3RyaWVzLmNvbmYgYmVmb3JlCiMgY2hhbmdpbmcgdGhlbSBoZXJlLgojaW5zZWN1cmVfcmVnaXN0cmllcyA9ICJbXSIKCiMgQ29udHJvbHMgaG93IGltYWdlIHZvbHVtZXMgYXJlIGhhbmRsZWQuIFRoZSB2YWxpZCB2YWx1ZXMgYXJlIG1rZGlyLCBiaW5kIGFuZAojIGlnbm9yZTsgdGhlIGxhdHRlciB3aWxsIGlnbm9yZSB2b2x1bWVzIGVudGlyZWx5LgojIGltYWdlX3ZvbHVtZXMgPSAibWtkaXIiCgojIExpc3Qgb2YgcmVnaXN0cmllcyB0byBiZSB1c2VkIHdoZW4gcHVsbGluZyBhbiB1bnF1YWxpZmllZCBpbWFnZSAoZS5nLiwKIyAiYWxwaW5lOmxhdGVzdCIpLiBCeSBkZWZhdWx0LCByZWdpc3RyaWVzIGlzIHNldCB0byAiZG9ja2VyLmlvIiBmb3IKIyBjb21wYXRpYmlsaXR5IHJlYXNvbnMuIERlcGVuZGluZyBvbiB5b3VyIHdvcmtsb2FkIGFuZCB1c2VjYXNlIHlvdSBtYXkgYWRkIG1vcmUKIyByZWdpc3RyaWVzIChlLmcuLCAicXVheS5pbyIsICJyZWdpc3RyeS5mZWRvcmFwcm9qZWN0Lm9yZyIsCiMgInJlZ2lzdHJ5Lm9wZW5zdXNlLm9yZyIsIGV0Yy4pLgojcmVnaXN0cmllcyA9IFsKIyBdCgoKIyBUaGUgY3Jpby5uZXR3b3JrIHRhYmxlIGNvbnRhaW5lcnMgc2V0dGluZ3MgcGVydGFpbmluZyB0byB0aGUgbWFuYWdlbWVudCBvZgojIENOSSBwbHVnaW5zLgpbY3Jpby5uZXR3b3JrXQoKIyBQYXRoIHRvIHRoZSBkaXJlY3Rvcnkgd2hlcmUgQ05JIGNvbmZpZ3VyYXRpb24gZmlsZXMgYXJlIGxvY2F0ZWQuCiMgTm90ZSB0aGlzIGRlZmF1bHQgaXMgY2hhbmdlZCBmcm9tIHRoZSBSUE0uCm5ldHdvcmtfZGlyID0gIi9ldGMva3ViZXJuZXRlcy9jbmkvbmV0LmQvIgoKIyBQYXRocyB0byBkaXJlY3RvcmllcyB3aGVyZSBDTkkgcGx1Z2luIGJpbmFyaWVzIGFyZSBsb2NhdGVkLgojIE5vdGUgdGhpcyBkZWZhdWx0IGlzIGNoYW5nZWQgZnJvbSB0aGUgUlBNLgpwbHVnaW5fZGlycyA9IFsKICAgICIvdmFyL2xpYi9jbmkvYmluIiwKXQoKIyBBIG5lY2Vzc2FyeSBjb25maWd1cmF0aW9uIGZvciBQcm9tZXRoZXVzIGJhc2VkIG1ldHJpY3MgcmV0cmlldmFsCltjcmlvLm1ldHJpY3NdCgojIEdsb2JhbGx5IGVuYWJsZSBvciBkaXNhYmxlIG1ldHJpY3Mgc3VwcG9ydC4KZW5hYmxlX21ldHJpY3MgPSB0cnVlCgojIFRoZSBwb3J0IG9uIHdoaWNoIHRoZSBtZXRyaWNzIHNlcnZlciB3aWxsIGxpc3Rlbi4KbWV0cmljc19wb3J0ID0gOTUzNwo=
        filesystem: root
        mode: 0644
        path: /etc/crio/crio.conf
EOF


cat << EOF | oc create -f -
apiVersion: machineconfiguration.openshift.io/v1
kind: MachineConfig
metadata:
  labels:
    machineconfiguration.openshift.io/role: worker
  name: 99-sysctl-elastic
spec:
  config:
    ignition:
      version: 2.2.0
    storage:
      files:
      - contents:
          # vm.max_map_count=262144
          source: data:text/plain;charset=utf-8;base64,dm0ubWF4X21hcF9jb3VudD0yNjIxNDQ=
        filesystem: root
        mode: 0644
        path: /etc/sysctl.d/99-elasticsearch.conf
EOF

sleep 10
oc wait mcp/worker --for condition=updated --timeout=25m
```


_________________________________________________________

## STEP #4 Install Procedures  


This cheat pulls Watson images from the entitled registry and loads to local registry.  


1.  Switch to cp4d-namespace namespace
```
oc project cp4d-namespace
```

2.  Grab the default-dockercfg secret needed for wa-override.yaml 
```
oc get secrets | grep default-dockercfg
```

3.  Create wd-override.yaml

Modify wd-override.yaml below 

* Set global.deploymentType to Development or Production
* Set image.pullSecrets  to secret name from above, ex:  pullSecret: "default-dockercfg-rgmsl"
* Set kubernetesHost to "api.cp4d-clustername"
* Set kubernetesIP to IP of above (ping 'api.cp4d-clustername')
* Set storageClassName(s) to 'portworx-db-gp3'
* Paste contents below to create file


### wd-override.yaml
```
cat <<EOF > "${PWD}/wd-override.yaml"
global:
  deploymentType: "Production or Development"
  image:
    # minio/postgresql/rabbitmq
    pullSecret: "your-default-dockercfg-secret"
  # etcd
  imagePullSecret: "your-default-dockercfg-secret"
core:
  ingestion:
    mount:
      storageClassName: "portworx-db-gp3"
wire:
  kubernetesHost: "api.yourclustername"
  kubernetesIP: "yourip"
elastic:
  persistence:
    storageClassName: "portworx-db-gp3"
EOF
```

4.  Create wd-repo.yaml

* Add apikey from passport advantage & paste contents below to create file

### wd-repo.yaml
	
```
cat <<EOF > "${PWD}/wd-repo.yaml"
registry:
  - url: cp.icr.io/cp/cpd
    username: "cp"
    apikey: <entitlement-key>
    namespace: ""
    name: base-registry
  - url: cp.icr.io/cp/watson-discovery
    username: "cp"
    apikey: <entitlement-key>
    name: watson-discovery-registry
fileservers:
  - url: https://raw.github.com/IBM/cloud-pak/master/repo/cpd3
EOF

```

5. Install WD 2.1.3

Run cpd-linux adm command first by pasting contents below

```
NAMESPACE=cp4d-namespace
OPENSHIFT_USERNAME=kubeadmin 
OPENSHIFT_REGISTRY_PULL=image-registry.openshift-image-registry.svc:5000
	
echo $NAMESPACE
echo $OPENSHIFT_USERNAME
echo $OPENSHIFT_REGISTRY_PULL

./cpd-linux adm \
  --repo "wd-repo.yaml" \
  --assembly "watson-discovery" \
  --namespace "$NAMESPACE" \
  --apply
```

Run cpd-linux command to install WD by pasting contents below

```
./cpd-linux --repo wd-repo.yaml --assembly watson-discovery --namespace $NAMESPACE --transfer-image-to $(oc registry info)/$NAMESPACE --target-registry-username $OPENSHIFT_USERNAME --target-registry-password=$(oc whoami -t) --insecure-skip-tls-verify --cluster-pull-prefix $OPENSHIFT_REGISTRY_PULL/$NAMESPACE -o wd-override.yaml --silent-install --storageclass "portworx-db-gp3" --accept-all-licenses
```

Watson Service will now be installed.   First the images will be pulled from the entitled docker registry and pushed to the OpenShift registry.  Once loaded, the Watson install will begin.  The whole process should take about an hour and a half.   An hour to load the images then about 30 mins to install Watson Discovery.


After the images have been loaded, you can watch the deployment spin up.  

**To Watch install**

Open up a second terminal window and wait for all pods to become ready.  You are looking for all of the Jobs to be in `Successful=1`  Control C to exit watch

```
ssh root@IP_address
watch "oc get pods -l 'release in(admin,crust,mantle,core)'"
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
Status for assembly lite and relevant modules in project zen:

		
[INFO] [2020-06-18 07:48:43-0225] Arch override not found. Assuming default architecture x86_64
[INFO] [2020-06-18 07:48:43-0404] Displaying CR status for all assemblies and relevant modules
[INFO] [2020-06-18 07:48:50-0216] 
Displaying CR status for all assemblies and relevant modules

Status for assembly lite and relevant modules in project zen:

Assembly Name           Status           Version          Arch    
lite                    Ready            3.0.1            x86_64  

  Module Name                     Status           Version          Arch      Storage Class     
  0010-infra                      Ready            3.0.1            x86_64    portworx-shared-gp
  0015-setup                      Ready            3.0.1            x86_64    portworx-shared-gp
  0020-core                       Ready            3.0.1            x86_64    portworx-shared-gp

=========================================================================================

Status for assembly watson-discovery and relevant modules in project zen:

Assembly Name           Status           Version          Arch    
watson-discovery        Ready            2.1.3            x86_64  

  Module Name                     Status           Version          Arch      Storage Class     
  0010-infra                      Ready            3.0.1            x86_64    portworx-shared-gp
  0015-setup                      Ready            3.0.1            x86_64    portworx-shared-gp
  0020-core                       Ready            3.0.1            x86_64    portworx-shared-gp
  watson-discovery-admin          Ready            2.1.3            x86_64    portworx-db-gp3   
  watson-discovery-crust          Ready            2.1.3            x86_64    portworx-db-gp3   
  watson-discovery-mantle         Ready            2.1.3            x86_64    portworx-db-gp3   
  watson-discovery-core           Ready            2.1.3            x86_64    portworx-db-gp3   

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
helm test core --tls
```

**Note:**  To delete pods from prior test chart execution, run with  --cleanup flag then you can run again with or without flag.

```
helm test core --tls --cleanup
```

**Optional:  To see what values were set when installed**
```
helm get values {chart} --tls
```

_________________________________________________________

## STEP #6 Provision Instance   


1.  Login to Cloud Pak Cluster:  https://zen-cpd-zen.apps.cp4d-clustername/zen/#/addons
**credentials:  admin / pw: password**

* Select Watson Service
* Select Provision Instance
* Give it a name and click Create
* Launch tool 
* Click on Sample project and wait for it to setup
* Try a sample query

**Note: If you have trouble with the tooling, try incognito mode**


_________________________________________________________

## STEP #7 Test via API    


Find Token and API endpoint
* Login to Cloud Pak Cluster:  
https://zen-cpd-zen.apps.cp4d-clustername/zen/#/myInstances

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
./cpd-linux uninstall --assembly watson-discovery --namespace cp4d-namespace

#Remove artifacts that are labeled
oc delete all,configmaps,jobs,secrets,service,persistentvolumeclaims,poddisruptionbudgets,podsecuritypolicy,securitycontextconstraints,clusterrole,clusterrolebinding,role,rolebinding,serviceaccount,networkpolicy \
  -l 'release in (admin, crust, core, mantle)'

#Remove the configmap
oc delete configmap admin.v1 crust.v core.v1 mantle.v1 stolon-cluster-crust-postgresql

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
./cpd-linux uninstall --assembly watson-discovery --namespace cp4d-namespace

#Remove artifacts that are labeled
oc delete all,configmaps,jobs,secrets,service,persistentvolumeclaims,poddisruptionbudgets,podsecuritypolicy,securitycontextconstraints,clusterrole,clusterrolebinding,role,rolebinding,serviceaccount,networkpolicy \
  -l 'release in (admin, crust, core, mantle)'

#Remove the configmap
oc delete configmap stolon-cluster-crust-postgresql

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


