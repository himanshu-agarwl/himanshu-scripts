#!/bin/bash

# Script to export historical CloudWatch logs to Firehose for processing
# Formats and gzips data to match CloudWatch subscription filter format

# TO_TIME: Feb 13, 2026 1:44 AM IST (= Feb 12, 2026 20:14 UTC)
# FROM_TIME: Dec 13, 2025 1:44 AM IST (= Dec 12, 2025 20:14 UTC) - 2 months before
FROM_TIME=1765570440000
TO_TIME=1770927240000

LOG_GROUP="<log-group-name>" # e.g. /aws/lambda/myfunction
FILTER_PATTERN="<search-filter>" # e.g. "ERROR" or "%Search Result:%"
FIREHOSE_STREAM="<firehose-stream-name>" # e.g. "my-firehose-stream"

# Get AWS Account ID
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

echo "Exporting logs to Firehose"
echo "Log group: $LOG_GROUP"
echo "Filter pattern: $FILTER_PATTERN"
echo "Firehose stream: $FIREHOSE_STREAM"
echo "AWS Account: $AWS_ACCOUNT_ID"
echo "From: $(date -r $((FROM_TIME / 1000)))"
echo "To: $(date -r $((TO_TIME / 1000)))"
echo ""

NEXT_TOKEN=""
TOTAL_EVENTS=0
TOTAL_SENT=0

while true; do
  echo "Fetching events..."

  if [ -z "$NEXT_TOKEN" ]; then
    RESPONSE=$(aws logs filter-log-events \
      --log-group-name "$LOG_GROUP" \
      --filter-pattern "$FILTER_PATTERN" \
      --start-time $FROM_TIME \
      --end-time $TO_TIME \
      --output json)
  else
    RESPONSE=$(aws logs filter-log-events \
      --log-group-name "$LOG_GROUP" \
      --filter-pattern "$FILTER_PATTERN" \
      --start-time $FROM_TIME \
      --end-time $TO_TIME \
      --next-token "$NEXT_TOKEN" \
      --output json)
  fi

  EVENT_COUNT=$(echo "$RESPONSE" | jq '.events | length')
  TOTAL_EVENTS=$((TOTAL_EVENTS + EVENT_COUNT))
  echo "Fetched $EVENT_COUNT events (total: $TOTAL_EVENTS)"

  # Group events by log stream and send to Firehose
  LOG_STREAMS=$(echo "$RESPONSE" | jq -r '.events[].logStreamName' | sort -u)

  for LOG_STREAM in $LOG_STREAMS; do
    # Get events for this log stream and format as CloudWatch Logs format
    CW_FORMAT=$(echo "$RESPONSE" | jq -c --arg owner "$AWS_ACCOUNT_ID" --arg logGroup "$LOG_GROUP" --arg logStream "$LOG_STREAM" '
    {
      messageType: "DATA_MESSAGE",
      owner: $owner,
      logGroup: $logGroup,
      logStream: $logStream,
      subscriptionFilters: ["manual-export"],
      logEvents: [.events[] | select(.logStreamName == $logStream) | {
        id: .eventId,
        timestamp: .timestamp,
        message: .message
      }]
    }')

    # Gzip and base64 encode, then send to Firehose
    B64_DATA=$(printf '%s' "$CW_FORMAT" | gzip | base64)

    aws firehose put-record \
      --delivery-stream-name "$FIREHOSE_STREAM" \
      --record "{\"Data\": \"$B64_DATA\"}" \
      --output text > /dev/null 2>&1

    RESULT=$?

    if [ $RESULT -eq 0 ]; then
      STREAM_COUNT=$(echo "$RESPONSE" | jq --arg logStream "$LOG_STREAM" '[.events[] | select(.logStreamName == $logStream)] | length')
      TOTAL_SENT=$((TOTAL_SENT + STREAM_COUNT))
      echo -n "."
    else
      echo -n "x"
      echo $RESULT
    fi
  done

  echo ""
  echo "Sent batch to Firehose"

  # Check for pagination
  NEXT_TOKEN=$(echo "$RESPONSE" | jq -r '.nextToken // empty')
  if [ -z "$NEXT_TOKEN" ]; then
    echo ""
    echo "✓ All events processed"
    break
  else
    echo "More events available, continuing..."
    echo ""
  fi
done

echo ""
echo "=== Summary ==="
echo "Total events fetched: $TOTAL_EVENTS"
echo "Total events sent: $TOTAL_SENT"
echo "Firehose stream: $FIREHOSE_STREAM"
