#!/bin/bash

# Test script to check if pagination is needed for CloudWatch logs export

# TO_TIME: Feb 13, 2026 1:44 AM IST (= Feb 12, 2026 20:14 UTC)
# FROM_TIME: Dec 13, 2025 1:44 AM IST (= Dec 12, 2025 20:14 UTC) - 2 months before
FROM_TIME=1765570440000
TO_TIME=1770927240000

echo "Fetching logs from: $(date -r $((FROM_TIME / 1000)))"
echo "Fetching logs to: $(date -r $((TO_TIME / 1000)))"
echo ""

RESPONSE=$(aws logs filter-log-events \
  --log-group-name "<log-group-name>" \
  --filter-pattern "<search-filter>" \
  --start-time $FROM_TIME \
  --end-time $TO_TIME \
  --output json)

EVENT_COUNT=$(echo "$RESPONSE" | jq '.events | length')
NEXT_TOKEN=$(echo "$RESPONSE" | jq -r '.nextToken // "none"')

echo "Events found: $EVENT_COUNT"
echo "Next token: $NEXT_TOKEN"

if [ "$NEXT_TOKEN" != "none" ]; then
  echo ""
  echo "⚠️  Pagination IS required - there are more events to fetch"
else
  echo ""
  echo "✓ No pagination needed - all events fetched in single request"
fi
