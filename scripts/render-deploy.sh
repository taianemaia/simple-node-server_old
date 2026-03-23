#!/bin/bash
# ^^^ This tells the system to run this file using bash (the terminal language)

# $1 means "the first argument passed to this script"
# Example: ./render-deploy.sh my-app  →  APP_NAME="my-app"
APP_NAME=$1


# --- Step 1: Check if the service already exists ---

# Send a GET request to Render's API to search for a service by name.
# The result (a JSON response) is stored in SERVICE_RESPONSE.
# -s means "silent" - hides progress output
SERVICE_RESPONSE=$(curl -s \
  "https://api.render.com/v1/services?name=$APP_NAME" \
  --header "Authorization: Bearer $RENDER_API_KEY")

# Parse the response to extract the service ID.
# jq is a tool for reading JSON. '.[0].service.id' navigates the JSON structure.
# '// empty' means "return nothing if the value is null"
SERVICE_ID=$(echo $SERVICE_RESPONSE | jq -r '.[0].service.id // empty')

# If SERVICE_ID is not empty, the service already exists - no need to create it
if [ -n "$SERVICE_ID" ]; then
  echo "Service already exists. ID: $SERVICE_ID"
  exit 0  # Stop the script here
fi


# --- Step 2: Service not found - create it ---

# Step 2.1: Get the owner ID (required when creating a new service)
# Sends a GET request to fetch the account owners
OWNERS_RESPONSE=$(curl -s \
  "https://api.render.com/v1/owners" \
  --header "Authorization: Bearer $RENDER_API_KEY")

# Extract the first owner's ID from the response
OWNER_ID=$(echo $OWNERS_RESPONSE | jq -r '.[0].owner.id')

# Step 2.2: Create the service
# Sends a POST request with a JSON body describing the new service.
# --data is the request body (what we're sending to the API)
# The single quotes around $APP_NAME and $OWNER_ID are needed to inject
# bash variables inside a JSON string
CREATE_RESPONSE=$(curl -s \
  "https://api.render.com/v1/services" \
  --header "Authorization: Bearer $RENDER_API_KEY" \
  --header "Content-Type: application/json" \
  --data '{
    "type": "web_service",
    "name": "'"$APP_NAME"'",
    "ownerId": "'"$OWNER_ID"'",
    "image": {
      "imagePath": "docker.io/library/nginx:latest"
    },
    "serviceDetails": {
      "runtime": "image",
      "plan": "free",
      "region": "oregon"
    }
  }')

# Extract the new service ID from the response
SERVICE_ID=$(echo $CREATE_RESPONSE | jq -r '.service.id')

echo "Service created. ID: $SERVICE_ID"
