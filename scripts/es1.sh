#!/bin/bash

# Variables
ELASTICSEARCH_URL="http://localhost:9200"
TELEGRAM_BOT_TOKEN="384439323:AAEZOEFXbtsR2hMI67jEx7QnvMnEMIXnpf4"
TELEGRAM_CHAT_ID="-1002085207725"
INDEX=".alert"
VALUE_FILE="/es_monitor/start_value.txt" # Save start_value to file

# Read start_value from file if exist
if [ -f "$VALUE_FILE" ]; then
  start_value=$(cat "$VALUE_FILE")
else
  start_value="2024-01-23T20:40:40.046Z"
  echo "$start_value" > "$VALUE_FILE"
fi


# Get now date UTC
now_value=$(date -u +"%Y-%m-%dT%H:%M:%S.%NZ")

echo "start: $start_value"
echo "end: $now_value"

# Query ES
response=$(curl -s -XGET "$ELASTICSEARCH_URL/$INDEX/_search" -H 'Content-Type: application/json' -d '{
  "query": {
     "range": {
      "timestamp": {
         "gte": "'"$start_value"'",
         "lt": "'"$now_value"'"
      }
    }
  },
  "sort": [
    {
      "timestamp": {
        "order": "asc"
      }
    }
  ]
}')

# Get status & context_message from ES
status=$(echo "$response" | jq -r '.hits.hits[]._source.status')
context_message=$(echo "$response" | jq -r '.hits.hits[]._source.context_message')

# if [[ "$status" == "false" ]]; then
#   message_error="$context_message"
#   message_resolve=""
# else
#   message_error=""
#   message_resolve="$context_message"
# fi

# # Send to Telegram
# if [[ -n "$message_error" ]]; then
#   curl -s -XPOST "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage" -d "chat_id=$TELEGRAM_CHAT_ID" -d "text=$message_error"
# fi

# if [[ -n "$message_resolve" ]]; then
#   curl -s -XPOST "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage" -d "chat_id=$TELEGRAM_CHAT_ID" -d "text=$message_resolve"
# fi

context_message_error=$(echo "$response" | jq -r '.hits.hits[] | select (._source.rule_type == "apm.transaction_error_rate" and ._source.status == false) | ._source.context_message')

context_message_latency=$(echo "$response" | jq -r '.hits.hits[] | select (._source.rule_type == "apm.transaction_duration" and ._source.status == false) | ._source.context_message')

context_message_error_resolve=$(echo "$response" | jq -r '.hits.hits[] | select (._source.rule_type == "apm.transaction_error_rate" and ._source.status == true) | ._source.context_message')

context_message_latency_resolve=$(echo "$response" | jq -r '.hits.hits[] | select (._source.rule_type == "apm.transaction_duration" and ._source.status == true) | ._source.context_message')

# Send to Telegram

if [[ -n "$context_message_error" ]]; then
  curl -s -XPOST "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage" -d "chat_id=$TELEGRAM_CHAT_ID" -d "text=$context_message_error"
fi

if [[ -n "$context_message_latency" ]]; then
  curl -s -XPOST "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage" -d "chat_id=$TELEGRAM_CHAT_ID" -d "text=$context_message_latency"
fi

if [[ -n "$context_message_error_resolve" ]]; then
  curl -s -XPOST "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage" -d "chat_id=$TELEGRAM_CHAT_ID" -d "text=$context_message_error_resolve"
fi

if [[ -n "$context_message_latency_resolve" ]]; then
  curl -s -XPOST "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage" -d "chat_id=$TELEGRAM_CHAT_ID" -d "text=$context_message_latency_resolve"
fi

# Update start_value
echo "$now_value" > "$VALUE_FILE"
start_value="$now_value"

