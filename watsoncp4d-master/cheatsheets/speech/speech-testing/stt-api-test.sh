#!/bin/bash   
echo "**********************************************************"
echo 'Starting speech-api-test Script'
echo "**********************************************************"
echo -e "\n"
echo "**********************************************************"
echo 'What is your TOKEN? '
echo "**********************************************************"
read TOKEN
#TOKEN=eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VybmFtZSI6ImFkbWluIiwic3ViIjoiYWRtaW4iLCJpc3MiOiJLTk9YU1NPIiwiYXVkIjoiRFNYIiwicm9sZSI6IkFkbWluIiwicGVybWlzc2lvbnMiOltdLCJ1aWQiOiIxMDAwMzMwOTk5IiwiaWF0IjoxNTc1MDM5MTc1fQ.e0Ua2IoKXwrho6WqxTqBVo0iKpmFj27-XIFhwHyadyefTvDcJXT62q25a02fPHbJUHCn2VXvZvySN-4QGRdc8wQ03DrOVjo58tlV37gVgrEKMbceGnCBdEmTETsrOylS0V68AjzwyYR7aGqKjh1VDw_Zq804y0XiD5hcJdP3KmrYTzKGJnOZ_J7tsv1k0GRaHsnZdHeU9kdptvr3WluSYT4RdeTkjdgSSitbDGGQPR75fEtog6vDFfLQl0fVSNyphoX1XrXNuBGbtyEHhAylnmABGspDXQdEPK-WkYyro1f3TFD2eSOaRX1-gygD9R4HzdwTjn8hEEifUDtPXiRa7g
echo Your TOKEN is:
echo $TOKEN
echo -e "\n"
echo "**********************************************************"
echo 'What is your API_URL? '
echo "**********************************************************"
read API_URL
#API_URL=https://zen-cpd-zen.apps.wp-nov15-5-lb-1.fyre.ibm.com/speech-to-text/speech1/instances/1575039175222/api
echo Your API_URL is:
echo $API_URL
echo -e "\n"
echo "**********************************************************"
echo '1 View Models'
echo "**********************************************************"
curl -H "Authorization: Bearer $TOKEN" -k $API_URL/v1/models
echo -e "\n"
echo "**********************************************************"
echo '2 Transcribe'
echo "**********************************************************"
echo -e "\n"
curl -H "Authorization: Bearer $TOKEN" -k -X POST  --header "Content-Type: audio/wav" --data-binary @JSON.wav "$API_URL/v1/recognize?timestamps=true&word_alternatives_threshold=0.9"
echo -e "\n"
echo "**********************************************************"
echo '3 Create a custom language model'
echo "**********************************************************"
echo -e "\n"
curl -H "Authorization: Bearer $TOKEN" -k -X POST --header "Content-Type: application/json" --insecure --data "{\"name\": \"CustomLanguageModelVP_v1\", \"base_model_name\": \"en-US_BroadbandModel\", \"description\": \"Custom Language Model by Victor Povar v1\"}" "$API_URL/v1/customizations"
echo -e "\n"
echo "**********************************************************"
echo 'What is your language_customization_id'
echo "**********************************************************"
read language_customization_id
echo -e "\n"
echo Your language_customization_id is:
echo $language_customization_id
echo -e "\n"
echo "**********************************************************"
echo '4 View Customizations'
echo "**********************************************************"
echo -e "\n"
curl -H "Authorization: Bearer $TOKEN" -k "$API_URL/v1/customizations"
echo -e "\n"
echo "**********************************************************"
echo '5 Add a Corpus to the language model'
echo "**********************************************************"
echo -e "\n"
curl -H "Authorization: Bearer $TOKEN" -k -X POST  --data-binary @IT-corpora.txt "$API_URL/v1/customizations/${language_customization_id}/corpora/corpus1"
echo -e "\n"
echo 'Waiting...'
sleep 10s
echo "**********************************************************"
echo '6 View the corpora'
echo "**********************************************************"
echo -e "\n"
curl -H "Authorization: Bearer $TOKEN" -k -X GET "$API_URL/v1/customizations/${language_customization_id}/corpora/corpus1"
echo -e "\n"
echo 'Waiting...'
sleep 10s
echo "**********************************************************"
echo '7 Add OOV words dictionary'
echo "**********************************************************"
echo -e "\n"
curl -H "Authorization: Bearer $TOKEN" -k -X POST --header "Content-Type: application/json" --data @words_list.json "$API_URL/v1/customizations/${language_customization_id}/words"
echo -e "\n"
echo "**********************************************************"
echo '8 Verify the words dictionary was added'
echo "**********************************************************"
echo -e "\n"
curl -H "Authorization: Bearer $TOKEN" -k -X GET "$API_URL/v1/customizations/${language_customization_id}/words"
echo -e "\n"

sleep 10s

echo "**********************************************************"
echo '9 Train the language model'
echo "**********************************************************"
echo -e "\n"
curl -H "Authorization: Bearer $TOKEN" -k -X POST "$API_URL/v1/customizations/${language_customization_id}/train"
echo -e "\n"
echo "**********************************************************"
echo 'Waiting...'
sleep 60s
echo "**********************************************************"
echo '10 View Customizations and make sure language model is in available state before continuing'
echo "**********************************************************"
echo -e "\n"
curl -H "Authorization: Bearer $TOKEN" -k -X GET "$API_URL/v1/customizations"
echo -e "\n"
echo "**********************************************************"
echo '11 Transcribe - should return with JSON not J. son'
echo "**********************************************************"
echo -e "\n"
curl -H "Authorization: Bearer $TOKEN" -k -X POST --header "Content-Type: audio/wav" --data-binary @JSON.wav "$API_URL/v1/recognize?timestamps=true&word_alternatives_threshold=0.9&language_customization_id=${language_customization_id}&customization_weight=0.8"
echo -e "\n"
sleep 10s
echo "**********************************************************"
echo '12 Create a custom acoustic model'
echo "**********************************************************"
echo -e "\n"
curl -H "Authorization: Bearer $TOKEN" -k -X POST --header "Content-Type: application/json" --data "{\"name\": \"Custom Acoustic Model by Victor Povar v1\", \"base_model_name\": \"en-US_BroadbandModel\", \"description\": \"Custom Acoustic Model by Victor Povar v1\"}" "$API_URL/v1/acoustic_customizations"
echo -e "\n"
sleep 10s
echo "**********************************************************"
echo 'What is your acoustic_customization_id'
echo "**********************************************************"
read acoustic_customization_id
echo -e "\n"
echo Your acoustic_customization_id= is:
echo $acoustic_customization_id
echo -e "\n"
sleep 10s

echo "**********************************************************"
echo '13 Verify acoustic model was created'
echo "**********************************************************"
echo -e "\n"
curl -H "Authorization: Bearer $TOKEN" -k -X GET "$API_URL/v1/acoustic_customizations?language=en-US"
echo -e "\n"
sleep 10s
echo "**********************************************************"
echo '14 Add audio files to the acoustic model'
echo "**********************************************************"
echo -e "\n"
curl -H "Authorization: Bearer $TOKEN" -k -X POST --header "Content-Type: application/zip" --data-binary @sample.zip "$API_URL/v1/acoustic_customizations/${acoustic_customization_id}/audio/audio1"
echo -e "\n"
sleep 10s
echo "**********************************************************"
echo '15 List audio resources'
echo "**********************************************************"
echo -e "\n"
curl -H "Authorization: Bearer $TOKEN" -k -X GET "$API_URL/v1/acoustic_customizations/${acoustic_customization_id}/audio"
echo -e "\n"
sleep 10s
echo "**********************************************************"
echo '16 Train an acoustic model with a language model'
echo "**********************************************************"
echo -e "\n"
curl -H "Authorization: Bearer $TOKEN" -k -X POST "$API_URL/v1/acoustic_customizations/${acoustic_customization_id}/train?custom_language_model_id=${language_customization_id}"
echo -e "\n"
echo "**********************************************************"
echo 'Waiting 2 mins for model to train'
sleep 240s
echo "**********************************************************"
echo '17 View Acoustic Model Status'
echo "**********************************************************"
echo -e "\n"
curl -H "Authorization: Bearer $TOKEN" -k -X GET "$API_URL/v1/acoustic_customizations?language=en-US"
echo -e "\n"
sleep 10s
echo "**********************************************************"
echo '18 Transcribe the audio file with the acoustic and language model, ensure that a valid transcription is returned'
echo "**********************************************************"
echo -e "\n"
curl -H "Authorization: Bearer $TOKEN" -k -X POST --header "Content-Type: audio/wav" --data-binary @JSON.wav "$API_URL/v1/recognize?timestamps=true&word_alternatives_threshold=0.9&language_customization_id=${language_customization_id}&customization_weight=0.8&acoustic_customization_id=${acoustic_customization_id}"
echo -e "\n"
sleep 10s
echo "**********************************************************"
echo '19 Add a grammar to a language model'
echo "**********************************************************"
echo -e "\n"
curl -H "Authorization: Bearer $TOKEN" -k -X POST --header "Content-Type: application/srgs" --data-binary @YesNo.abnf "$API_URL/v1/customizations/${language_customization_id}/grammars/{grammar_name}"
echo -e "\n"
sleep 10s
echo "**********************************************************"
echo '20 Monitor grammars - Verify that the grammar was created.  Status will go from being_processed to analyzed.'
echo "**********************************************************"
echo -e "\n"
curl -H "Authorization: Bearer $TOKEN" -k -X GET "$API_URL/v1/customizations/${language_customization_id}/grammars/{grammar_name}"
echo -e "\n"
sleep 10s
echo "**********************************************************"
echo '21 Retrain the custom language model now with grammar'
echo "**********************************************************"
echo -e "\n"
curl -H "Authorization: Bearer $TOKEN" -k -X POST "$API_URL/v1/customizations/${language_customization_id}/train"
echo -e "\n"
echo "**********************************************************"

echo 'Waiting 3 mins for model to train'
sleep 180s
echo "**********************************************************"
echo '22 Monitor custom language model training with grammar'
echo "**********************************************************"
echo -e "\n"
curl -H "Authorization: Bearer $TOKEN" -k -X GET "$API_URL/v1/customizations"
echo -e "\n"
sleep 10s
echo "**********************************************************"
echo '23 Transcribe with a grammar'
echo "**********************************************************"
echo -e "\n"
curl -H "Authorization: Bearer $TOKEN" -k -X POST --header "Content-Type: audio/wav" --data-binary @JSON.wav "$API_URL/v1/recognize?customization_id=${language_customization_id}&language_customization_enabled={grammar_name}&language_customization_weights=0.7"
echo -e "\n"
sleep 10s
echo "**********************************************************"
echo '24 Delete language model'
echo "**********************************************************"
echo -e "\n"
curl -H "Authorization: Bearer $TOKEN" -k -X DELETE "$API_URL/v1/customizations/${language_customization_id}"
echo -e "\n"
sleep 10s
echo "**********************************************************"
echo '25 Delete acoustic model'
echo "**********************************************************"
echo -e "\n"
curl -H "Authorization: Bearer $TOKEN" -k -X DELETE "$API_URL/v1/acoustic_customizations/${acoustic_customization_id}"
echo -e "\n"
echo "**********************************************************"


