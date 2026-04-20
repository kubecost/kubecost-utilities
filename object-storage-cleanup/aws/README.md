# AWS S3 Object Storage Cleanup

This directory contains the AWS S3-specific implementation of the Kubecost object storage cleanup script.

## Contents

- **kubecost-object-store-cleaner.sh** - Bash script for cleaning up old Kubecost data files from S3
- **Dockerfile** - Container image with AWS CLI and dependencies for running the script in Kubernetes
- **policy-iam-s3-cleanup.json** - IAM policy template with required S3 permissions

## Container Image

The Dockerfile creates a lightweight image based on `amazon/aws-cli` with `jq` pre-installed for JSON processing.

### Building and Pushing

To build multi-architecture images (amd64 and arm64) and push to your registry:

```bash
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  -t YOUR_REGISTRY/awscli-util:0.0.1 \
  -f ./object-storage-cleanup/aws/Dockerfile --push .
```

### Public Image

A pre-built image is available at:
```
public.ecr.aws/kubecost/awscli-util:0.0.1
```

## IAM Permissions

The script requires the following S3 permissions:
- `s3:ListBucket` - List objects in the bucket
- `s3:GetObject` - Read object metadata
- `s3:DeleteObject` - Delete old objects

### IAM Policy Template

Use `policy-iam-s3-cleanup.json` as a template. Replace `YOUR_KUBECOST_BUCKET` with your actual bucket name, then run:

```bash
# Create the policy (replace YOUR_KUBECOST_BUCKET)
aws iam create-policy \
  --policy-name KubecostS3CleanupPolicy \
  --policy-document file://object-storage-cleanup/aws/policy-iam-s3-cleanup.json
```

The above will output the name of the policy Arn, which you can use to create a pod identity association.

# Create pod identity association
```bash
eksctl create podidentityassociation \
  --cluster YOUR_CLUSTER \
  --region CLUSTER_REGION \
  --namespace kubecost \
  --service-account-name kubecost-sa \
  --permission-policy-arns Arn:from:above:command
```

## Usage

See the parent directory's [README.md](../README.md) for script usage and [README-cronjob.md](../README-cronjob.md) for Kubernetes CronJob deployment instructions.

## Future Provider Support

Support for additional cloud providers (GCP Cloud Storage, Azure Blob Storage) will be added in future releases with similar directory structures.
