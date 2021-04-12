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


validatetts() {
	echo "**********************************************************"
	echo '1 View Voices'
	echo "**********************************************************"
	curl -H "Authorization: Bearer $TOKEN" -k $API_URL/v1/voices
	echo -e "\n"
	echo "**********************************************************"
	echo 'What voice do you want to try?'
	echo "**********************************************************"
	read voice
	echo -e "\n"
	echo Your voice is:
	echo $voice
	echo -e "\n"
	echo "**********************************************************"
	echo ' Transcribe - audio'
	echo "**********************************************************"
	echo -e "\n"
	curl -k -X POST --header "Authorization: Bearer $TOKEN" --header "Content-Type: application/json" --header "Accept: audio/wav" --data "{\"text\":\"Hello world\"}" --output $voice.wav "$API_URL/v1/synthesize?voice=$voice"
	echo -e "\n"
}

echo "**********************************************************"
echo 'Starting text to speech test Script'
echo "**********************************************************"
echo -e "\n"
getcreds
validatetts
read -p 'Do you want to test another voice? (y/n): '   runagain
echo -e "\n"
if [ $runagain == "y" ]; then 
 	validatetts
fi 
echo "**********************************************************"
echo 'Browse to wav file and double click to play and hear the voice'
echo "**********************************************************"
echo -e "\n"





