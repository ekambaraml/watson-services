# Updating Speech Image Tags to Most Recent Version

This will download and install the most recent build for the following images:

- speech-utils-rhubi8
- gdpr-data-deletion
- stt-async
- stt-customization
- tts-customization


## Prior to installing the chart

**Important**: This should be done prior to step 7 of [installing Speech](https://www.ibm.com/support/knowledgecenter/SSQNUZ_3.0.1/cpd/svc/watson/speech-to-text-install.html)

1. Run the following command to download the watson-speech chart:

   `./cpd-linux -n {namespace-name} -a watson-speech --dry-run --repo repo.yaml`
   
   By default, the chart will be downloaded to the path `cpd-linux-workspace/modules/watson-speech-base/x86_64/1.1.4`
   
2. Navigate to the above path and untar the speech chart with the command:

   `tar zxf ibm-watson-speech-prod-1.1.4.tgz`

3. Modify image tags inside the chart to point to the most recent version. The files to be changed are listed below
   1. ibm-watson-speech-prod/ibm\_cloud\_pak/manifest.yaml
   
	   For each image listed at the top of the file, navigate to its definition in this file and update the image tag. An example for the tts-customization image is given below
   
	   Before:
   
		```
		   - image: tts-customization:master-463
		   references:
		    - repository: tts-customization:master-463
		      pull-repository: cp.icr.io/cp/watson-speech/tts-customization:master-463
		      pull-authorization:
		        username:
		          env: ENTITLED_USERNAME
		        password:
		          env: ENTITLED_PASSWORD
		```

		After:
		```
		   - image: tts-customization:master-498
		   references:
		    - repository: tts-customization:master-498
		      pull-repository: cp.icr.io/cp/watson-speech/tts-customization:master-498
		      pull-authorization:
		        username:
		          env: ENTITLED_USERNAME
		        password:
		          env: ENTITLED_PASSWORD
		```
	2.  ibm-watson-speech-prod/charts/ibm-watson-speech-gdpr-data-deletion/values.yaml
		- Update the image tag to `master-251`
	3. ibm-watson-speech-prod/charts/ibm-watson-speech-stt-async/values.yaml
		- Update the image tag to `MedalliaJuneWithFix-2`
	4. ibm-watson-speech-prod/charts/ibm-watson-speech-stt-customization/values.yaml
		- Update the image tag to `master-732`
	5. ibm-watson-speech-prod/charts/ibm-watson-speech-tts-customization/values.yaml
		- Update the image tag to `master-498`
	6.  ibm-watson-speech-prod/values.yaml
		- Update the value `global.images.utils.tag` to `master-37`
			It should look like this:
			```
			images:
			  utils:
			    image: speech-utils-rhubi8
			    tag: master-37
			```
	7. main.yaml
		- Update the image tags for each of the 5 charts:
			- gdpr-data-deletion: `master-251`
			- stt-async: `MedalliaJuneWithFix-2`
			- stt-customization: `master-732`
			- tts-customization: `master-498`
			- speech-utils-rhubi8: `master-37`
			
4. Delete the old packaged version of the chart (`ibm-watson-speech-prod-1.1.4.tgz`)
5. Repackage the chart. If you have helm installed, you can simply run `helm package ibm-watson-speech-prod`. Otherwise, manually tar the chart using `tar zcvf ibm-watson-speech-prod-1.1.4.tgz ibm-watson-speech-prod/`    
	- **Note**: If using MacOS, use the ``--exclude='._*'`` flag to avoid creation of extra backup files
6. Continue installing as usual
