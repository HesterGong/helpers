#!/bin/bash

# Test createApplication mutation against local backend
# Usage: ./scripts/test-create-application.sh [applicationGroupId|--double]
#
# Situation 1 (no args): creates new group + assigns applicationId
# Situation 2 (with applicationGroupId): assigns applicationId to existing group
#   ./scripts/test-create-application.sh 507f1f77bcf86cd799439011
# Situation 3 (--double): creates new group + assigns two applicationIds to it
#   ./scripts/test-create-application.sh --double

ENDPOINT="http://localhost:4002/local/2022-06-30/graphql"

if [ "${1:-}" = "--double" ]; then
  DOUBLE=true
  APPLICATION_GROUP_ID=""
else
  DOUBLE=false
  APPLICATION_GROUP_ID="${1:-}"
fi

make_variables() {
  local group_id="$1"
  jq -n \
    --argjson appGroupId "$([ -n "$group_id" ] && echo "\"$group_id\"" || echo "null")" \
    '{
      answersInfo: {
        BusinessInformation_100_Country_WORLD_EN: "BusinessInformation_100_Country_01_WORLD_EN",
        BusinessInformation_100_Province_WORLD_EN: "BusinessInformation_100_Province_01_WORLD_EN",
        BusinessInformation_100_EffectiveDate_WORLD_EN: "2026-03-03",
        BusinessInformation_100_PrimaryProfession_WORLD_EN: "BusinessInformation_100_Profession_9219_1820001_WORLD_EN",
        BusinessInformation_100_CustomerInfo_WORLD_EN: {
          firstName: "Hester",
          lastName: "Gong",
          email: "hestergong@foxquilt.com",
          phoneNumber: "15555555555"
        },
        primaryProfessionLabel: "Yoga Instructors"
      },
      hubspotTracker: "4e39484cdbc4a9d75a4731ebbfd6d099",
      pageName: "BusinessInformationCountry_100",
      effectiveDateUTC: "Tue Mar 03 2026 00:00:00 GMT-0500 (Eastern Standard Time)",
      transactionType: "New Business",
      transactionDateUTC: "Tue Mar 03 2026 08:52:03 GMT-0500 (Eastern Standard Time)",
      country: "Canada",
      provinceOrState: "Ontario",
      applicationGroupId: $appGroupId
    }'
}

QUERY='mutation createApplication(
  $answersInfo: createApplicationAnswersInput!
  $pageName: String!
  $groupName: String
  $hubspotTracker: String
  $policyFoxdenId: String
  $cancellationReason: String
  $cancellationTrigger: String
  $effectiveDateUTC: String
  $transactionDateUTC: String
  $transactionType: String!
  $country: String!
  $provinceOrState: String!
  $applicationGroupId: ObjectID
) {
  createApplication(
    answersInfo: $answersInfo
    pageName: $pageName
    groupName: $groupName
    hubspotTracker: $hubspotTracker
    policyFoxdenId: $policyFoxdenId
    cancellationReason: $cancellationReason
    cancellationTrigger: $cancellationTrigger
    effectiveDateUTC: $effectiveDateUTC
    transactionDateUTC: $transactionDateUTC
    transactionType: $transactionType
    country: $country
    provinceOrState: $provinceOrState
    applicationGroupId: $applicationGroupId
  ) {
    ... on ApplicationSuccess {
      applicationId
      __typename
    }
    ... on ApplicationFailure {
      error
      __typename
    }
    __typename
  }
}'

if $DOUBLE; then
  echo "Situation 3: creating new group and adding two applicationIds to it"
elif [ -n "$APPLICATION_GROUP_ID" ]; then
  echo "Situation 2: assigning to existing applicationGroupId=$APPLICATION_GROUP_ID"
else
  echo "Situation 1: creating new applicationGroup"
fi
echo "Endpoint: $ENDPOINT"
echo "---"

make_body() {
  local group_id="$1"
  jq -n \
    --arg query "$QUERY" \
    --argjson variables "$(make_variables "$group_id")" \
    '{operationName: "createApplication", query: $query, variables: $variables}'
}

echo "Request 1:"
RESPONSE1=$(curl -s -X POST "$ENDPOINT" \
  -H "content-type: application/json" \
  -H "accept: */*" \
  --data "$(make_body "$APPLICATION_GROUP_ID")")
echo "$RESPONSE1" | jq .

if $DOUBLE; then
  APP_ID=$(echo "$RESPONSE1" | jq -r '.data.createApplication.applicationId // empty')
  if [ -z "$APP_ID" ]; then
    echo "Error: could not extract applicationId from first response"
    exit 1
  fi
  RETURNED_GROUP_ID=$(mongosh "mongodb://127.0.0.1:27017/foxcom" --quiet --eval \
    "var doc = db.ApplicationGroup.findOne({'data.applicationIds': ObjectId('$APP_ID')}); if (doc) { print(doc._id.toHexString()); }")
  if [ -z "$RETURNED_GROUP_ID" ] || [ "$RETURNED_GROUP_ID" = "null" ]; then
    echo "Error: could not find applicationGroupId in DB for applicationId=$APP_ID"
    exit 1
  fi
  echo "---"
  echo "Request 2 (applicationGroupId=$RETURNED_GROUP_ID):"
  curl -s -X POST "$ENDPOINT" \
    -H "content-type: application/json" \
    -H "accept: */*" \
    --data "$(make_body "$RETURNED_GROUP_ID")" | jq .
fi
