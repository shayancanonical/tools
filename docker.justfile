# Start local docker registry
start-local-registry:
	docker start registry || docker run -d -p 5000:5000 --name registry registry:2

# Stop local docker registry
stop-local-registry:
	docker stop registry && docker rm registry

# Push rock to local docker registry
push-rock-to-local-registry rock_path image tag:
	#!/usr/bin/env bash
	set -euxo pipefail

	rockcraft.skopeo --insecure-policy copy --dest-tls-verify=false \
	  "oci-archive:${rock_path}" \
	  "docker://localhost:5000/${image}:${tag}"
