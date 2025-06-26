#!/bin/bash

# This script creates a service account with an account key to be used with a GCP Storage bucket

# Make the script exit if any command fails
set -e
# Also exit if any command in a pipeline fails
set -o pipefail
# Exit if trying to use an unset variable
set -u

# --- Configuration Variables ---
# Automatically gets your current GCP project ID
PROJECT_ID="guestbook-227502"
# Name for the new service account
SERVICE_ACCOUNT_NAME="kubecost-cloud-saas-sa"
# The specific GCS bucket this service account will access
BUCKET_NAME="KUBECOST_BUCKET_NAME"
# The role to grant to the service account (using built-in role)
ROLE_ID="roles/storage.objectAdmin"
# The full email address of the service account
SERVICE_ACCOUNT_EMAIL="${SERVICE_ACCOUNT_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"
# The local file path where the service account key will be saved
KEY_FILE_PATH="./${SERVICE_ACCOUNT_NAME}.json"

echo "--- Starting GCP Service Account Setup Script ---"
echo "Project ID: $PROJECT_ID"
echo "Service Account Name: $SERVICE_ACCOUNT_NAME"
echo "Target Bucket: gs://$BUCKET_NAME"
echo "Role ID: $ROLE_ID"
echo "Service Account Email: $SERVICE_ACCOUNT_EMAIL"
echo "Key File Output Path: $KEY_FILE_PATH"
echo "--------------------------------------------------"

read -r -p "Continue with creation? (y/n): " confirm
if [ "$confirm" != "y" ]; then
    echo "Aborting."
    exit 0
fi

# --- 0. Make sure bucket exists by running simple ls command ---
echo "Checking if bucket exists..."
if ! gcloud storage ls "gs://${BUCKET_NAME}" --project="${PROJECT_ID}" > /dev/null 2>&1; then
    echo "Bucket does not exist. Exiting."
    exit 1
fi

# --- 1. Create the Service Account ---
echo "Creating service account: $SERVICE_ACCOUNT_NAME..."
# Using || true to handle the case where the service account already exists
gcloud iam service-accounts create "$SERVICE_ACCOUNT_NAME" \
    --project="${PROJECT_ID}" \
    --display-name="Service Account for Kubecost SaaS Restricted Access to ${BUCKET_NAME}" || {
    echo "Error: Failed to create service account '$SERVICE_ACCOUNT_NAME'."
    echo "If it already exists and you want to continue, please delete it first:"
    echo "gcloud iam service-accounts delete --project=${PROJECT_ID} $SERVICE_ACCOUNT_EMAIL"
    exit 1
}
echo "Service account created successfully."

# --- 2. Use Built-in Storage Object Admin Role ---
# This predefined role grants permissions for objects within buckets:
# - storage.buckets.get: Allows getting metadata about buckets.
# - storage.objects.list: Allows listing objects inside buckets.
# - storage.objects.get: Allows reading (downloading) objects from buckets.
# - storage.objects.create: Allows writing (uploading) objects to buckets.
# - storage.objects.delete: Allows deleting objects from buckets.
echo "Using built-in role: $ROLE_ID"

# --- 3. Grant the Storage Object Admin Role to the Service Account on the Specific Bucket ---
echo "Granting role '$ROLE_ID' to service account '$SERVICE_ACCOUNT_EMAIL' on bucket 'gs://$BUCKET_NAME'..."
# Note: The bucket MUST exist for this command to succeed.
gcloud storage buckets add-iam-policy-binding "gs://${BUCKET_NAME}" \
    --member="serviceAccount:${SERVICE_ACCOUNT_EMAIL}" \
    --role="$ROLE_ID" \
    --project="${PROJECT_ID}" || {
    echo "Error: Failed to grant role to service account on bucket."
    exit 1
}

echo "Permissions granted successfully for service account on bucket."

# --- 4. Create and Output Service Account Key ---
echo "Creating service account key for '$SERVICE_ACCOUNT_EMAIL' and saving to '$KEY_FILE_PATH'..."
gcloud iam service-accounts keys create "$KEY_FILE_PATH" \
    --iam-account="$SERVICE_ACCOUNT_EMAIL" \
    --project="$PROJECT_ID" || {
    echo "Error: Failed to create service account key."
    exit 1
}
echo "Service account key saved successfully to '$KEY_FILE_PATH'."

# --- 5. Final message ---

echo "Script finished successfully!"
echo "IMPORTANT: The service account key is in '$KEY_FILE_PATH'. Treat this file with extreme care as it grants access to your bucket."
echo "Consider moving it to a secure location (e.g., ~/.gcp/) and restricting its file permissions."
echo "Example usage with this key (after setting GOOGLE_APPLICATION_CREDENTIALS environment variable):"
echo "export GOOGLE_APPLICATION_CREDENTIALS=\"$KEY_FILE_PATH\""
echo "gcloud storage ls gs://$BUCKET_NAME"

