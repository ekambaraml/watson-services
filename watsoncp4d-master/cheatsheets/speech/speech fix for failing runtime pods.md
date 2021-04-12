# Failing TTS and STT runtime pods due to issue with model download

## Patching pods

Replace string `tar.gz` with `tar.pzstd` in following deployments:

```
   <release-name>-speech-to-text-stt-runtime
   <release-name>-speech-to-text-stt-am-patcher
   <release-name>-text-to-speech-tts-runtime
```

Run following command for each deployment:

```
   kubectl edit deployment <deployment-name>
```

That opens editor and you can find `tar.gz` string and replace it with `tar.pzstd`.



## Re-runing upload voice/model job

In case PODs for deployments mentioned above are stuck in `Init` state it can mean that not all requested models/voices were not properly uploaded.

Models/voices can be re-uploaded as follows:

### 1. Save upload job definition:

If you have only STT pods stuck in `Init` state you don't need to re-create `<release-name>upload-voices-1` job and vice versa.

Number in the job name is used for versioning of jobs in case you do `helm upgrade`. In that case re-create only upload jobs with the highest number.

```
   kubect get job <release-name>-upload-models-1 -o json > upload_models_job.json
   kubect get job <release-name>-upload-voices-1 -o json > upload_voices_job.json
```

### 2. Open the files `upload_models_job.json` and `upload_voices_job.json` in the text editor:

Remove sections:

- `metadata/creationTimestamp`
- `metadata/labels`
- `metadata/resourceVersion`
- `metadata/selfLink`
- `metadata/uid`
- `spec/selector`
- `spec/template/metadata`

Note: `metadata/name` and `metadata/namespace` should be untouched.

Here is a example of how the file should look like after editing.

Change beginning of the file from:

```
{
    "apiVersion": "batch/v1",
    "kind": "Job",
    "metadata": {
        "creationTimestamp": "2019-11-27T14:31:57Z",
        "labels": {
            "controller-uid": "aac43eca-1122-11ea-8602-00163e01c9ab",
            "job-name": "impressive-parrot-upload-voices-1"
        },
        "name": "impressive-parrot-upload-voices-1",
        "namespace": "zen",
        "resourceVersion": "4805684",
        "selfLink": "/apis/batch/v1/namespaces/zen/jobs/impressive-parrot-upload-voices-1",
        "uid": "aac43eca-1122-11ea-8602-00163e01c9ab"
    },
    "spec": {
        "backoffLimit": 6,
        "completions": 1,
        "parallelism": 1,
        "selector": {
            "matchLabels": {
                "controller-uid": "aac43eca-1122-11ea-8602-00163e01c9ab"
            }
        },
        "template": {
            "metadata": {
                "creationTimestamp": null,
                "labels": {
                    "controller-uid": "aac43eca-1122-11ea-8602-00163e01c9ab",
                    "job-name": "impressive-parrot-upload-voices-1"
                }
            },
            "spec": {
                "affinity": {
                    "nodeAffinity": {
                        "preferredDuringSchedulingIgnoredDuringExecution": [
```

so it looks like this:

```
{
    "apiVersion": "batch/v1",
    "kind": "Job",
    "metadata": {
        "name": "<release-name>-upload-voices-1",
        "namespace": "zen"
    },
    "spec": {
        "backoffLimit": 6,
        "completions": 1,
        "parallelism": 1,
        "template": {
            "spec": {
                "affinity": {
                    "nodeAffinity": {
                        "preferredDuringSchedulingIgnoredDuringExecution": [
```

Remove `status` section from the end of the file. It looks like this:

```
    "status": {
        "completionTime": "2019-11-27T14:33:20Z",
        "conditions": [
            {
                "lastProbeTime": "2019-11-27T14:33:20Z",
                "lastTransitionTime": "2019-11-27T14:33:20Z",
                "status": "True",
                "type": "Complete"
            }
        ],
        "startTime": "2019-11-27T14:31:58Z",
        "succeeded": 1
    }
```

Don't forget to remove "comma" character on the line above "status" section start.



### 3. Delete old upload job: 

```
   kubectl delete job <release-name>-upload-models-1
   kubectl delete job <release-name>-upload-voices-1
```

### 4. Create new upload job: 

```
   kubectl create -f upload_models_job.json
   kubectl create -f upload_voices_job.json
```


