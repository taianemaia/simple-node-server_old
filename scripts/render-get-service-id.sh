#!/bin/bash
# render-get-service-id.sh
#
# Finds an existing Render web service by name, or creates one if it doesn't exist yet.
# The service is configured to use a prebuilt Docker image from Docker Hub.
#
# Usage:    ./render-get-service-id.sh <app-name> <image-path>
# Example:  ./render-get-service-id.sh simple-node-server docker.io/myuser/simple-node-server:latest
#
# Requires: RENDER_API_KEY environment variable
# Output:   Prints the service ID to stdout (status messages go to stderr)

APP_NAME=$1     # The name of the Render service (used to look it up or create it)
IMAGE_PATH=$2   # The full Docker Hub image path, e.g. docker.io/myuser/myapp:latest


# --- Step 1: Check if the service already exists ---

# Send a GET request to Render's API searching for a service by name.
# -s means "silent" (hides curl's progress bar)
SERVICE_RESPONSE=$(curl -s \
  "https://api.render.com/v1/services?name=$APP_NAME" \
  --header "Authorization: Bearer $RENDER_API_KEY")

# Parse the JSON response to extract the service ID.
# jq navigates the JSON: .[0] = first result, .service.id = the ID field.
# '// empty' means "return nothing (not null) if the field is missing"
SERVICE_ID=$(echo "$SERVICE_RESPONSE" | jq -r '.[0].service.id // empty')

# If we found a service ID, it already exists — just return it
if [ -n "$SERVICE_ID" ]; then
  echo "Service '$APP_NAME' already exists." >&2
  echo "$SERVICE_ID"
  exit 0
fi


# --- Step 2: Service not found — create it ---

echo "Service '$APP_NAME' not found. Creating it now..." >&2

# Step 2.1: Fetch the owner ID (Render requires it when creating a service)
OWNERS_RESPONSE=$(curl -s \
  "https://api.render.com/v1/owners" \
  --header "Authorization: Bearer $RENDER_API_KEY")

OWNER_ID=$(echo "$OWNERS_RESPONSE" | jq -r '.[0].owner.id')

# Step 2.2: Create the web service, pointing it at our Docker Hub image
# - "runtime": "image" tells Render this is an image-backed service (not a build-from-source)
# - "imagePath": the full Docker Hub image URL (e.g. docker.io/myuser/myapp:latest)
# - "plan": "free" keeps this on the free tier
CREATE_RESPONSE=$(curl -s \
  "https://api.render.com/v1/services" \
  --header "Authorization: Bearer $RENDER_API_KEY" \
  --header "Content-Type: application/json" \
  --data '{
    "type": "web_service",
    "name": "'"$APP_NAME"'",
    "ownerId": "'"$OWNER_ID"'",
    "image": {
      "imagePath": "'"$IMAGE_PATH"'"
    },
    "serviceDetails": {
      "runtime": "image",
      "plan": "free",
      "region": "oregon",
      "envSpecificDetails": {
        "imagePath": "'"$IMAGE_PATH"'"
      }
    }
  }')

SERVICE_ID=$(echo "$CREATE_RESPONSE" | jq -r '.service.id')

# Validate that we actually got an ID back
if [ -z "$SERVICE_ID" ] || [ "$SERVICE_ID" = "null" ]; then
  echo "Error: failed to create service. API response:" >&2
  echo "$CREATE_RESPONSE" >&2
  exit 1
fi

echo "Service '$APP_NAME' created successfully." >&2
echo "$SERVICE_ID"
