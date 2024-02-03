# Query ES & Push Telegram

**Bước 1: Login vào server cài ES, tạo folder `/es_monitor`, script thực hiện query ES và một file `.txt` chứa output của script đó**

```sh
mkdir /es_monitor

touch /es_monitor/es1.sh
touch /es_monitor/out.txt
```

**Bước 2: Thêm nội dung sau vào đoạn script `/es_monitor/es1.sh`**

```sh
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
```

**Bước 3: Tạo cronjob chạy script trên mỗi phút 1 lần**

```sh
crontab -e 
```

Thêm đoạn sau vào dòng cuối cùng của file

```sh
* * * * * /usr/bin/bash /es_monitor/es1.sh >> /es_monitor/out.txt
```

> NOTE: Đoạn Script trên sau khi chạy sẽ tạo một file tại vị trí `/es_monitor/start_value.txt`. Và lưu lại giá trị `timestamp` là lần cuối cùng chạy script để chẳng may có sự cố khiến script không hoạt động trong một thời gian thì khi script hoạt động trở lại giá trị Timestamp khi query sẽ được lấy từ **khoảng thời gian cuối cùng mà script đã chạy trước khi bị lỗi** cho đến khi hoạt động trở lại

```sh
root@elasticsearch01:/es_monitor# cat out.txt 
start: 2024-01-23T20:40:40.046Z
end: 2024-01-24T03:26:01.334624786Z
{"ok":true,"result":{"message_id":101,"from":{"id":6738049191,"is_bot":true,"first_name":"es bot","username":"es16_bot"},"chat":{"id":-4189540777,"title":"monitor_es","type":"group","all_members_are_administrators":true},"date":1706066762,"text":"[ERROR] Failed transaction rate threshold | tms_bi_web l\u00e0 6.4% v\u01b0\u1ee3t ng\u01b0\u1ee1ng c\u1ea3nh b\u00e1o 1% @luannt32. https://kibana.viettelpost.vn/app/apm/services/tms_bi_web/overview?rangeFrom=2024-01-23T22:00:54.031Z||-5m&rangeTo=2024-01-23T22:00:54.031Z&transactionType=request&comparisonEnabled=true&comparisonType=day\n[Warning] tms_bi_web - Latency l\u00e0 6,826 ms v\u01b0\u1ee3t ng\u01b0\u1ee1ng \u0111\u00e3 \u0111\u1eb7t c\u1ea3nh b\u00e1o 5000 ms @luannt32.  https://kibana.viettelpost.vn/app/apm/services/tms_bi_web/overview?rangeFrom=2024-01-23T22:04:03.659Z||-5m&rangeTo=2024-01-23T22:04:03.659Z&transactionType=request&comparisonEnabled=true&comparisonType=day\n[OK] Failed transaction rate threshold | tms_bi_web \u0111\u00e3 tr\u1edf l\u1ea1i b\u00ecnh th\u01b0\u1eddng\n[Resolved] Latency threshold | tms_bi_web - Latency \u0111\u00e3 tr\u1edf l\u1ea1i b\u00ecnh th\u01b0\u1eddng \n[Warning] tms_bi_web - Latency l\u00e0 7,277 ms v\u01b0\u1ee3t ng\u01b0\u1ee1ng \u0111\u00e3 \u0111\u1eb7t c\u1ea3nh b\u00e1o 5000 ms @luannt32.  https://kibana.viettelpost.vn/app/apm/services/tms_bi_web/overview?rangeFrom=2024-01-23T22:40:58.001Z||-5m&rangeTo=2024-01-23T22:40:58.001Z&transactionType=request&comparisonEnabled=true&comparisonType=day\n[Resolved] Latency threshold | tms_bi_web - Latency \u0111\u00e3 tr\u1edf l\u1ea1i b\u00ecnh th\u01b0\u1eddng \n[Warning] vtp_appweb_excel - Latency l\u00e0 1,086 ms v\u01b0\u1ee3t ng\u01b0\u1ee1ng \u0111\u00e3 \u0111\u1eb7t c\u1ea3nh b\u00e1o 1000 ms @tuyendn87, @nndinh.  https://kibana.viettelpost.vn/app/apm/services/vtp_appweb_excel/overview?rangeFrom=2024-01-23T22:47:39.537Z||-5m&rangeTo=2024-01-23T22:47:39.537Z&transactionType=request&comparisonEnabled=true&comparisonType=day\n[Warning] tms_bi_web - Latency l\u00e0 5,700 ms v\u01b0\u1ee3t ng\u01b0\u1ee1ng \u0111\u00e3 \u0111\u1eb7t c\u1ea3nh b\u00e1o 5000 ms @luannt32.  https://kibana.viettelpost.vn/app/apm/services/tms_bi_web/overview?rangeFrom=2024-01-23T22:53:16.133Z||-5m&rangeTo=2024-01-23T22:53:16.133Z&transactionType=request&comparisonEnabled=true&comparisonType=day\n[Resolved] Latency threshold | tms_bi_web - Latency \u0111\u00e3 tr\u1edf l\u1ea1i b\u00ecnh th\u01b0\u1eddng \n[Resolved] Latency threshold | vtp_appweb_excel - Latency \u0111\u00e3 tr\u1edf l\u1ea1i b\u00ecnh th\u01b0\u1eddng","entities":[{"offset":87,"length":9,"type":"mention"},{"offset":98,"length":205,"type":"url"},{"offset":383,"length":9,"type":"mention"},{"offset":395,"length":205,"type":"url"},{"offset":831,"length":9,"type":"mention"},{"offset":843,"length":205,"type":"url"},{"offset":1210,"length":10,"type":"mention"},{"offset":1222,"length":7,"type":"mention"},{"offset":1232,"length":211,"type":"url"},{"offset":1523,"length":9,"type":"mention"},{"offset":1535,"length":205,"type":"url"}],"link_preview_options":{"url":"https://kibana.viettelpost.vn/app/apm/services/tms_bi_web/overview?rangeFrom=2024-01-23T22:00:54.031Z||-5m&rangeTo=2024-01-23T22:00:54.031Z&transactionType=request&comparisonEnabled=true&comparisonType=day"}}}start: 2024-01-24T03:26:01.334624786Z
end: 2024-01-24T03:27:01.358687222Z
start: 2024-01-24T03:27:01.358687222Z
end: 2024-01-24T03:28:01.467524923Z
start: 2024-01-24T03:28:01.467524923Z
end: 2024-01-24T03:29:01.586326408Z
start: 2024-01-24T03:29:01.586326408Z
end: 2024-01-24T03:30:01.711838838Z
start: 2024-01-24T03:30:01.711838838Z
end: 2024-01-24T03:47:01.855360861Z
{"ok":true,"result":{"message_id":102,"from":{"id":6738049191,"is_bot":true,"first_name":"es bot","username":"es16_bot"},"chat":{"id":-4189540777,"title":"monitor_es","type":"group","all_members_are_administrators":true},"date":1706068022,"text":"[Warning] vtp_okd_mailconnector - Latency l\u00e0 84 s v\u01b0\u1ee3t ng\u01b0\u1ee1ng \u0111\u00e3 \u0111\u1eb7t c\u1ea3nh b\u00e1o 30000 ms @tuyendn87, @nndinh.  https://kibana.viettelpost.vn/app/apm/services/vtp_okd_mailconnector/overview?rangeFrom=2024-01-24T03:44:18.200Z||-5m&rangeTo=2024-01-24T03:44:18.200Z&transactionType=request&comparisonEnabled=true&comparisonType=day\n[Warning] vtp_okd_order - Latency l\u00e0 58 s v\u01b0\u1ee3t ng\u01b0\u1ee1ng \u0111\u00e3 \u0111\u1eb7t c\u1ea3nh b\u00e1o 3000 ms @tuyendn87, @nndinh.  https://kibana.viettelpost.vn/app/apm/services/vtp_okd_order/overview?rangeFrom=2024-01-24T03:44:19.437Z||-5m&rangeTo=2024-01-24T03:44:19.437Z&transactionType=request&comparisonEnabled=true&comparisonType=day\n[Warning] tms_bi_web - Latency l\u00e0 179 ms v\u01b0\u1ee3t ng\u01b0\u1ee1ng \u0111\u00e3 \u0111\u1eb7t c\u1ea3nh b\u00e1o 50 ms @luannt32.  https://kibana.viettelpost.vn/app/apm/services/tms_bi_web/overview?rangeFrom=2024-01-24T03:45:27.120Z||-5m&rangeTo=2024-01-24T03:45:27.120Z&transactionType=request&comparisonEnabled=true&comparisonType=day\n[Resolved] Latency threshold | tms_bi_web - Latency \u0111\u00e3 tr\u1edf l\u1ea1i b\u00ecnh th\u01b0\u1eddng","entities":[{"offset":87,"length":10,"type":"mention"},{"offset":99,"length":7,"type":"mention"},{"offset":109,"length":216,"type":"url"},{"offset":404,"length":10,"type":"mention"},{"offset":416,"length":7,"type":"mention"},{"offset":426,"length":208,"type":"url"},{"offset":710,"length":9,"type":"mention"},{"offset":722,"length":205,"type":"url"}],"link_preview_options":{"url":"https://kibana.viettelpost.vn/app/apm/services/vtp_okd_mailconnector/overview?rangeFrom=2024-01-24T03:44:18.200Z||-5m&rangeTo=2024-01-24T03:44:18.200Z&transactionType=request&comparisonEnabled=true&comparisonType=day"}}}root@elasticsearch01:/es_monitor# 
```

> Như đoạn OUTPUT trên ta có thể thấy được script đã KHÔNG hoạt động trong khoảng thời gian từ `2024-01-24T03:30:01.711838838Z` đến `2024-01-24T03:47:01.855360861Z`. Khi script hoạt động trở lại, nó lấy giá trị `start` được lưu lần cuối cùng trong file `/es_monitor/start_value.txt` trước khi script lỗi và `end` là thời gian hiện tại để query ES trong khoảng thời gian này. Như vậy sẽ không bị miss thông tin khi script bị lỗi.