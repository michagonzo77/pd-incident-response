#!/bin/bash

# Define necessary URLs and tokens
FRESHSERVICE_URL="https://aenetworks-fs-sandbox.freshservice.com/api/v2/tickets"
FRESHSERVICE_API_KEY=$FSAPI_SANDBOX
PAGERDUTY_API_URL="https://api.pagerduty.com/incidents"
PAGERDUTY_API_KEY=$PD_API_KEY

# Function to get Freshservice ticket details
get_freshservice_ticket() {
    ticket_number=$1
    curl -u $FRESHSERVICE_API_KEY:X -X GET "$FRESHSERVICE_URL/$ticket_number" | jq .
}

# Function to close Freshservice ticket
close_freshservice_ticket() {
    ticket_number=$1
    curl -u $FRESHSERVICE_API_KEY:X -X PUT "$FRESHSERVICE_URL/$ticket_number" -H "Content-Type: application/json" -d '{"status": 5}'
}

# Function to get PagerDuty incident details
get_pagerduty_incident() {
    incident_id=$1
    curl -X GET "$PAGERDUTY_API_URL/$incident_id" -H "Authorization: Token token=$PAGERDUTY_API_KEY" -H "Accept: application/vnd.pagerduty+json;version=2" | jq .
}

# Main function
main() {
    ticket_number=$1
    responders=$2
    cause=$3
    impact=$4

    # Step 1: Get Freshservice ticket details
    ticket=$(get_freshservice_ticket $ticket_number)
    
    # Extract necessary details from Freshservice ticket
    slack_description=$(echo $ticket | jq -r '.description')
    ticket_creation_time=$(echo $ticket | jq -r '.created_at')
    tags=$(echo $ticket | jq -r '.tags[]')
    incident_id=$(echo $tags | grep 'pdid_')

    # Step 2: Get PagerDuty incident details
    incident=$(get_pagerduty_incident $incident_id)

    # Step 3: Close Freshservice ticket
    close_freshservice_ticket $ticket_number
    
    # Extract necessary details from PagerDuty incident
    slack_incident_commander=$(echo $incident | jq -r '.incident.incident_key')  # Replace with actual field
    slack_detection_method=$(echo $incident | jq -r '.incident.title')  # Replace with actual field
    slack_business_impact=$(echo $incident | jq -r '.incident.summary')  # Replace with actual field
    
    # Step 4: Format the message
    current_time=$(date -Iseconds)
    incident_duration=$(date -d @$(( $(date -d "$current_time" +%s) - $(date -d "$ticket_creation_time" +%s) )) -u +%H:%M:%S)
    sev1_message="SEV 1 INCIDENT SUMMARY
$slack_description
Incident start time: $ticket_creation_time
Incident close time: $current_time
Incident duration: $incident_duration
Incident Commander: $slack_incident_commander
Detect method: $slack_detection_method
Impacted product and platform: $impact
Responders: $responders
Business impact: $slack_business_impact
Cause: $cause"

    # Save the message to an env var
    export SEV1_MESSAGE="$sev1_message"

    # Step 5: Send the message to Slack
    slack send-message '#kubiya_testing' "$SEV1_MESSAGE"
}