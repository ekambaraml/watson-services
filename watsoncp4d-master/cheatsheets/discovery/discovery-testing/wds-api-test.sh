#!/bin/bash   

getcreds() {
	echo "**********************************************************"
	echo 'What is your TOKEN? '
	echo "**********************************************************"
	read TOKEN
	#TOKEN=eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VybmFtZSI6ImFkbWluIiwic3ViIjoiYWRtaW4iLCJpc3MiOiJLTk9YU1NPIiwiYXVkIjoiRFNYIiwicm9sZSI6IkFkbWluIiwicGVybWlzc2lvbnMiOltdLCJ1aWQiOiIxMDAwMzMwOTk5IiwiaWF0IjoxNTc1MjAzNjYzfQ.Egq2h4q2ZTuB2bfGcXb5SjK9DBcLJyO9Zq1NSd2KOjOHjCKbc1o9QBvMEniB31utjbJyXdB78hpMK13f803RAf6KMcwRIGkWXVUp5OCSlUkWQgMHob7MStZ6oBYKDdYHOKTUmwjuTlyvUxrpDre8JPHElrkbi1H1K3TQRPiIxqEjkse7VBEJl-E0HgGGQOlFlsydCxJZyom0ltp11bg5CM10jn32D46tYFaKgsIFIu9514ThGkYmXzNr_Ak7Gk0ML1iS9j-CqQN5spH1S9NHbU8csab3pos8QXHnYyqwMNsk0zWIkZvn4Tlb_cO6oBsEv9hib6YslQ04etxxQODPbw

	echo $TOKEN
	echo -e "\n"
	echo "**********************************************************"
	echo 'What is your API_URL? '
	echo "**********************************************************"
	read API_URL
	#API_URL=https://zen-cpd-zen.apps.wp-nov15-5-lb-1.fyre.ibm.com/text-to-speech/speech1/instances/1575039216517/api
	echo $API_URL
	echo -e "\n"
}

validatewds() {
	echo "**********************************************************"
	echo 'Starting Discovery-api-test Script'
	echo "**********************************************************"
	echo "**********************************************************"
	echo 'List Collections'
	echo "**********************************************************"
	curl $API_URL/v1/environments/default/collections?version=2019-06-10 -H "Authorization: Bearer $TOKEN" -k
	echo -e "\n"
	echo "**********************************************************"
	echo 'What is your collection_id'
	echo "**********************************************************"
	read collection_id
	echo -e "\n"
	echo Your collection_id is:
	echo $collection_id
	echo -e "\n"
	echo "**********************************************************"
	echo 'Ingest Document'
	echo "**********************************************************"
	echo -e "\n"
	curl -k -H "Authorization: Bearer $TOKEN" -X POST -F "file=@FAQ.docx" $API_URL/v1/environments/default/collections/$collection_id/documents?version=2019-06-10
	echo -e "\n"
	#echo Sleeping for 2 min
	sleep 120s
	read -p "Press enter to continue"
}

echo "**********************************************************"
echo 'Starting WDS API Test Script'
echo "**********************************************************"
echo -e "\n"
getcreds
validatewds
echo -e "\n"
echo "**********************************************************"
echo 'Completed WDS Test'
echo "**********************************************************"
echo -e "\n"

