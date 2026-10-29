#!/usr/bin/env bash
# What a Google Cloud project needs once, so that the Deploy workflow can
# ship master to Cloud Run (docs/serving.md). Run it as a project owner, with
# gcloud signed in; run it again freely, it only makes what is missing.
#
#   PROJECT_ID=my-project deploy/gcp-setup.sh
#
# It makes:
# - the APIs: Cloud Run, Artifact Registry, and the two that Workload
#   Identity Federation needs
# - an Artifact Registry repository for the image, in the region
# - a runtime service account with no role at all: the app calls no Google
#   API, and the default compute account, which has Editor, must not serve it
# - a deployer service account that may deploy to Cloud Run, push the image
#   and act as the runtime account, and nothing else
# - a Workload Identity pool and a GitHub provider, so that the Deploy
#   workflow, from this repository only, becomes the deployer with its OpenID
#   token: no key is made, stored or rotated
# Then it prints the GitHub variables to set (Settings, Secrets and
# variables, Actions, Variables).
set -euo pipefail

PROJECT_ID="${PROJECT_ID:?set PROJECT_ID to the Google Cloud project}"
REGION="${REGION:-europe-west1}" # Belgium: tier 1 pricing, domain mappings; Paris (europe-west9) is tier 2
SERVICE="${SERVICE:-cistergraphia}"
GITHUB_REPOSITORY="${GITHUB_REPOSITORY:-chussenot/cistergraphia}"
POOL="${POOL:-github}"
PROVIDER="${PROVIDER:-github}"

gcloud config set project "$PROJECT_ID" >/dev/null
PROJECT_NUMBER="$(gcloud projects describe "$PROJECT_ID" --format='value(projectNumber)')"
RUNTIME_SA="${SERVICE}-run@${PROJECT_ID}.iam.gserviceaccount.com"
DEPLOYER_SA="${SERVICE}-deploy@${PROJECT_ID}.iam.gserviceaccount.com"

echo "== APIs"
gcloud services enable run.googleapis.com artifactregistry.googleapis.com \
  iamcredentials.googleapis.com sts.googleapis.com

echo "== Artifact Registry: $REGION-docker.pkg.dev/$PROJECT_ID/$SERVICE"
gcloud artifacts repositories describe "$SERVICE" --location="$REGION" >/dev/null 2>&1 \
  || gcloud artifacts repositories create "$SERVICE" --location="$REGION" --repository-format=docker \
       --description="Cistergraphia images, pushed by the Deploy workflow"

echo "== Runtime service account: $RUNTIME_SA (no role)"
gcloud iam service-accounts describe "$RUNTIME_SA" >/dev/null 2>&1 \
  || gcloud iam service-accounts create "${SERVICE}-run" --display-name="Cistergraphia runtime (no role)"

echo "== Deployer service account: $DEPLOYER_SA"
gcloud iam service-accounts describe "$DEPLOYER_SA" >/dev/null 2>&1 \
  || gcloud iam service-accounts create "${SERVICE}-deploy" --display-name="Cistergraphia deployer (GitHub Actions)"
gcloud projects add-iam-policy-binding "$PROJECT_ID" --member="serviceAccount:$DEPLOYER_SA" \
  --role=roles/run.admin --condition=None >/dev/null
gcloud artifacts repositories add-iam-policy-binding "$SERVICE" --location="$REGION" \
  --member="serviceAccount:$DEPLOYER_SA" --role=roles/artifactregistry.writer >/dev/null
gcloud iam service-accounts add-iam-policy-binding "$RUNTIME_SA" \
  --member="serviceAccount:$DEPLOYER_SA" --role=roles/iam.serviceAccountUser >/dev/null

echo "== Workload Identity Federation: pool $POOL, provider $PROVIDER, for $GITHUB_REPOSITORY"
gcloud iam workload-identity-pools describe "$POOL" --location=global >/dev/null 2>&1 \
  || gcloud iam workload-identity-pools create "$POOL" --location=global --display-name="GitHub Actions"
gcloud iam workload-identity-pools providers describe "$PROVIDER" --location=global \
  --workload-identity-pool="$POOL" >/dev/null 2>&1 \
  || gcloud iam workload-identity-pools providers create-oidc "$PROVIDER" --location=global \
       --workload-identity-pool="$POOL" --display-name="GitHub" \
       --issuer-uri="https://token.actions.githubusercontent.com" \
       --attribute-mapping="google.subject=assertion.sub,attribute.repository=assertion.repository" \
       --attribute-condition="assertion.repository == '$GITHUB_REPOSITORY'"
PRINCIPAL="principalSet://iam.googleapis.com/projects/$PROJECT_NUMBER/locations/global/workloadIdentityPools/$POOL/attribute.repository/$GITHUB_REPOSITORY"
gcloud iam service-accounts add-iam-policy-binding "$DEPLOYER_SA" \
  --member="$PRINCIPAL" --role=roles/iam.workloadIdentityUser >/dev/null

cat <<VARS

Set these repository variables on GitHub ($GITHUB_REPOSITORY: Settings, Secrets and variables, Actions, Variables):

  GCP_PROJECT_ID                  $PROJECT_ID
  GCP_REGION                      $REGION
  GCP_SERVICE_ACCOUNT             $DEPLOYER_SA
  GCP_RUNTIME_SERVICE_ACCOUNT     $RUNTIME_SA
  GCP_WORKLOAD_IDENTITY_PROVIDER  projects/$PROJECT_NUMBER/locations/global/workloadIdentityPools/$POOL/providers/$PROVIDER

Then run the Deploy workflow once by hand (Actions, Deploy, Run workflow), or merge to master.
VARS
