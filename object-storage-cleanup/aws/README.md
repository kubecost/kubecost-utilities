# AWS S3 specific cleaner

To build the Dockerfile and push arm+amd images, you could use:

```bash
docker buildx build \                                                                                                      
  --platform linux/amd64,linux/arm64 \
  -t YOUR_REGISTRY/awscli-util:0.0.1 \  
  -f ./object-storage-cleanup/aws/Dockerfile --push .
```
