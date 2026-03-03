#!/bin/bash

# Test createApplication mutation against local backend
# Usage: ./scripts/test-create-application.sh [applicationGroupId]
#
# Situation 1 (no applicationGroupId): creates new group + assigns applicationId
# Situation 2 (with applicationGroupId): assigns applicationId to existing group
#   ./scripts/test-create-application.sh 507f1f77bcf86cd799439011

ENDPOINT="http://localhost:4002/local/2022-06-30/graphql"
APPLICATION_GROUP_ID="${1:-}"

VARIABLES=$(jq -n \
  --argjson appGroupId "$([ -n "$APPLICATION_GROUP_ID" ] && echo "\"$APPLICATION_GROUP_ID\"" || echo "null")" \
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
  }')

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

BODY=$(jq -n \
  --arg query "$QUERY" \
  --argjson variables "$VARIABLES" \
  '{operationName: "createApplication", query: $query, variables: $variables}')

if [ -n "$APPLICATION_GROUP_ID" ]; then
  echo "Situation 2: assigning to existing applicationGroupId=$APPLICATION_GROUP_ID"
else
  echo "Situation 1: creating new applicationGroup"
fi
echo "Endpoint: $ENDPOINT"
echo "---"

curl -s -X POST "$ENDPOINT" \
  -H "content-type: application/json" \
  -H "accept: */*" \
  --data "$BODY" | jq .
