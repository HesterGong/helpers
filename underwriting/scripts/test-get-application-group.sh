#!/bin/bash

# Test getApplicationGroup query against local backend
# Usage: ./scripts/test-get-application-group.sh <applicationGroupId>
#
# Example:
#   ./scripts/test-get-application-group.sh 507f1f77bcf86cd799439011

ENDPOINT="http://localhost:4002/local/2022-06-30/graphql"
APPLICATION_GROUP_ID="${1:-}"

if [ -z "$APPLICATION_GROUP_ID" ]; then
  echo "Usage: $0 <applicationGroupId>"
  exit 1
fi

VARIABLES=$(jq -n \
  --arg applicationGroupId "$APPLICATION_GROUP_ID" \
  '{ applicationGroupId: $applicationGroupId }')

QUERY='query getApplicationGroup($applicationGroupId: ObjectID!) {
  getApplicationGroup(applicationGroupId: $applicationGroupId) {
    applicationGroupId
    correlationId
    applicationIds
  }
}'

BODY=$(jq -n \
  --arg query "$QUERY" \
  --argjson variables "$VARIABLES" \
  '{operationName: "getApplicationGroup", query: $query, variables: $variables}')

echo "Querying applicationGroupId=$APPLICATION_GROUP_ID"
echo "Endpoint: $ENDPOINT"
echo "---"

curl -s -X POST "$ENDPOINT" \
  -H "content-type: application/json" \
  -H "accept: */*" \
  --data "$BODY" | jq .
