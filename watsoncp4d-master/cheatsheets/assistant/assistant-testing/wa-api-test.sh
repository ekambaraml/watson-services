#!/bin/bash
echo "**********************************************************"
echo 'Startng wa-api-test Script'
echo "**********************************************************"
echo -e "\n"
echo "**********************************************************"
echo 'What is your TOKEN? '
echo "**********************************************************"
read TOKEN
echo Your TOKEN is:
echo $TOKEN
echo -e "\n"
echo "**********************************************************"
echo 'What is your API_URL? '
echo "**********************************************************"
read API_URL
echo Your API_URL is:
echo $API_URL
echo -e "\n"
echo "**********************************************************"
echo 'List Workspaces'
echo "**********************************************************"
curl $API_URL/v1/workspaces?version=2018-09-20 -H "Authorization: Bearer $TOKEN" -k
echo -e "\n"
echo "**********************************************************"
echo 'What is your workspace id'
echo "**********************************************************"
read workspace_id
echo -e "\n"
echo Your Workspace id is:
echo $workspace_id
echo -e "\n"
echo "**********************************************************"
echo 'list intents'
echo "**********************************************************"
echo -e "\n"
curl $API_URL/v1/workspaces/${workspace_id}/intents?version=2018-09-20 -H "Authorization: Bearer $TOKEN" -k
echo -e "\n"
echo "**********************************************************"
echo 'list entities'
echo "**********************************************************"
echo -e "\n"
curl $API_URL/v1/workspaces/${workspace_id}/entities?version=2018-09-20 -H "Authorization: Bearer $TOKEN" -k
echo -e "\n"
echo "**********************************************************"
echo 'list dialog nodes'
echo "**********************************************************"
echo -e "\n"
curl $API_URL/v1/workspaces/${workspace_id}/dialog_nodes?version=2018-09-20 -H "Authorization: Bearer $TOKEN" -k
echo -e "\n"
echo "**********************************************************"
echo 'get message - send a hello to the test skill'
echo "**********************************************************"
echo -e "\n"
curl $API_URL/v1/workspaces/${workspace_id}/message?version=2018-09-20 -H "Authorization: Bearer $TOKEN" -k --header "Content-Type:application/json" --data "{\"input\": {\"text\": \"Hello\"}}"
echo -e "\n"
echo "**********************************************************"
echo 'locating assistant id'
echo "**********************************************************"
echo -e "\n"
curl -k -H "Authorization: Bearer $TOKEN" -X GET "$API_URL/v1/agents/definitions?version=2018-12-20"
echo -e "\n"
echo "**********************************************************"
echo 'What is your assistant id?'
echo "**********************************************************"
read assistant_id
echo -e "\n"
echo Your Assistant id is:
echo $assistant_id
echo -e "\n"
echo "**********************************************************"
echo 'Creating a v2 session using assistant id'
echo "**********************************************************"
echo -e "\n"
curl -k -H "Authorization: Bearer $TOKEN"  -X POST "$API_URL/v2/assistants/${assistant_id}/sessions?version=2019-02-28"
echo -e "\n"
echo "**********************************************************"
echo 'What is your session id'
echo "**********************************************************"
read session_id
echo -e "\n"
echo Your session id is:
echo $session_id
echo -e "\n"
echo "**********************************************************"
echo 'Send a hello message to test workspace using V2 API'
echo "**********************************************************"
echo -e "\n"
curl -k -H "Authorization: Bearer $TOKEN" -H "Content-Type:application/json" -X POST -d "{\"input\": {\"text\": \"Hello\"}}" "$API_URL/v2/assistants/${assistant_id}/sessions/${session_id}/message?version=2019-02-28"
echo -e "\n"
echo "**********************************************************"
echo 'Pulling the logs from the assistant using V2 API'
echo "**********************************************************"
echo -e "\n"
curl -k -H "Authorization: Bearer $TOKEN" -H "Content-Type:application/json" -X GET "$API_URL/v2/assistants/${assistant_id}/logs?version=2019-02-28"
echo -e "\n"
