#/
# Copyright 2018 IBM Corp. All Rights Reserved
# IBM Confidential Source Code Materials
#
# IBM grants recipient of the source code (“you”) a non-exclusive, non-transferable, revocable (in the case of breach of this license or termination of your subscription to
# the applicable IBM Cloud services or their replacement services) license to reproduce, create and transmit, in each case, internally only, derivative works of the source
# code for the sole purpose of maintaining and expanding the usage of applicable IBM Cloud services. You must reproduce the notices and this license grant in any derivative
# work of the source code. Any external distribution of the derivative works will be in object code or executable form only.
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an “AS IS” BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#/
#
# Script to do daily backups of Watson Assistant Workspaces for Watson on ICP engagements
# Created by Brandon Warech
# Version 1.0 / March 2, 2019
#
# Script writes to local directory 'workspace-backups' with the day of the week
# Script will only keep one weeks worth of backup by default
#
# Script will prompt for URL, IAM_API_key, and Version or can be specified on the command line


import json
import watson_developer_cloud
import os
from datetime import datetime
import sys

now = datetime.now()
today_int = datetime.today().weekday()

# Set arguments from cmd line
if len(sys.argv) == 1:
	url_arg = input('What is the URL to the instance? (i.e. https://gateway.watsonplatform.net/assistant/api) ')
	apikey_arg = input('What is the API Key? ')
	version_arg = input('What API version? (i.e. 2018-09-20) ')
elif len(sys.argv) == 4:
	url_arg = sys.argv[1]
	apikey_arg = sys.argv[2]
	version_arg = sys.argv[3]
else:
	raise Exception('Not enough arguments included. Please run with either 0 arguments, or 3 arguments (URL, API key, and Version respectively) ')

assistant = watson_developer_cloud.AssistantV1(
    iam_apikey=apikey_arg,
    url=url_arg,
    version=version_arg
)

# Disable SSL Verification for ICP
assistant.disable_SSL_verification()

response = assistant.list_workspaces().get_result()

# Make Directory for Backups
try:
    os.makedirs("workspace-backups")
except:
    pass

# Create Day of Week Directory and Navigate to them
try:
    os.chdir("workspace-backups")
    if today_int == 0:
        os.makedirs("Monday")
        os.chdir("Monday")
    if today_int == 1:
        os.makedirs("Tuesday")
        os.chdir("Tuesday")
    if today_int == 2:
        os.makedirs("Wednesday")
        os.chdir("Wednesday")
    if today_int == 3:
        os.makedirs("Thursday")
        os.chdir("Thursday")
    if today_int == 4:
        os.makedirs("Friday")
        os.chdir("Friday")
    if today_int == 5:
        os.makedirs("Saturday")
        os.chdir("Saturday")
    if today_int == 6:
        os.makedirs("Sunday")
        os.chdir("Sunday")
except FileExistsError:
    if today_int == 0:
        os.chdir("Monday")
    if today_int == 1:
        os.chdir("Tuesday")
    if today_int == 2:
        os.chdir("Wednesday")
    if today_int == 3:
        os.chdir("Thursday")
    if today_int == 4:
        os.chdir("Friday")
    if today_int == 5:
        os.chdir("Saturday")
    if today_int == 6:
        os.chdir("Sunday")

# parse results into individual workspace details
workspace_list = response["workspaces"]

#Fetch each workspace JSON and write to directory
for workspace in workspace_list:
    workspace_id = workspace["workspace_id"]
    workspace_json = assistant.get_workspace(
        workspace_id=workspace_id,
		export=True
    ).get_result()
    #print(json.dumps(workspace_json, indent=2))
    print('Successfully written Workspace ID ' + str(workspace_id))
    with open(str(workspace_id) + ".json", "w") as outfile:
        json.dump(workspace_json, outfile)

