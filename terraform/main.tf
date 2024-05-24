terraform {
  required_providers {
    kubiya = {
      source  = "kubiya-terraform/kubiya"
    }
  }
}

provider "kubiya" {
  // Your Kubiya API Key will be taken from the
  // environment variable KUBIYA_API_KEY
  // To set the key, please use export KUBIYA_API_KEY="YOUR_API_KEY"
}

resource "kubiya_agent" "agent" {
  // Mandatory Fields
  name            = "Incident Closer"                   // String
  runner          = "dev-eks-sandbox"           // String
  description     = "Close FreshService SEV 1 incidents for pagerduty"            // String
  instructions    = "You are an intelligent agent targeted for incident response management - you have access to multiple tools: python (if you need advanced and fast parsing etc), jq (JSON parsing), bash, and a script you can run called incident-response. Carefully follow the provided instructions and try to be fast and performant as possible."       // String
  
  // Optional fields, String
  model           = "azure/gpt-4"  // If not provided, Defaults to "azure/gpt-4"
  // If not provided, Defaults to "ghcr.io/kubiyabot/kubiya-agent:stable"
  image           = "michaelkubiya/pd-incident-response:latest"
  
  // Optional Fields:
  // Arrays
  secrets         = ["PD_API_KEY","FSAPI_SANDBOX"]
  integrations    = ["slack"]
  users           = ["john.dispirito@aenetworks.com"]
  groups          = ["Admin"]
  // links = []
  // starters = []
  tasks = [
    {
      name        = "Create FS tickets from Pagerduty incidents"
      prompt      = <<EOF
      """
      1. Read the event data from the file and store it in a variable.
      event_data=$(<path_to_event_file)
      2. Send a message to the private Slack channel with the event details and the Freshservice ticket URL. Use the following format:
      ************** SEV 1 ****************
      *Incident Commander:*  $(jq -r '.event.slackincidentcommander' <<< "$event_data")
      *Detection Method:*  $(jq -r '.event.slackdetectionmethod' <<< "$event_data")
      *Business Impact:*  $(jq -r '.event.slackbusinessimpact' <<< "$event_data")
      *Bridge Link:*  <$(jq -r '.event.bridge_url' <<< "$event_data")|Bridge>
      *Pagerduty Incident URL:*  <$(jq -r '.event.incident_url' <<< "$event_data")|Pagerduty>
      *FS Ticket URL:* <https://aenetworks-fs-sandbox.freshservice.com/a/tickets/$TICKET_ID%7CFreshservice Ticket>
      We will keep everyone posted on this channel as we assess the issue further.
      """
      EOF
      description = "Creates FS tickets based on data received from Pagerduty."
    }
  ]
  
  environment_variables = {
    DEBUG = "1"
  }
}

output "agent" {
  value = kubiya_agent.agent
}

resource "kubiya_webhook" "webhook" {
  name        = "Creates FS tickets from Pagerduty Workflows"
  filter      = ""
  prompt      = <<EOF
  """
  New webhook from PagerDuty! 
  1. Echo the contents of the event {{.event}} to a file.
    echo "{{.event}}" > "$event_file"

  2. Run the incident-response script by using the command: 
    incident-response "$event_file"
  """
  EOF
  source      = "Pagerduty"
  agent       = kubiya_agent.agent.name
  destination = "@john.dispirito@aenetworks.com"
}

output "webhook" {
  value = kubiya_webhook.webhook
}
