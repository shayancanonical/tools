# Start local docker registry
docker-start-local-registry:
	docker start registry || docker run -d -p 5000:5000 --name registry registry:2

# Stop local docker registry
docker-stop-local-registry:
	docker stop registry && docker rm registry

# Push rock to local docker registry
docker-push-rock-to-local-registry rock_path image tag:
	#!/usr/bin/env bash
	set -euxo pipefail

	rockcraft.skopeo --insecure-policy copy \
		--dest-tls-verify=false \
	  "oci-archive:${rock_path}" \
	  "docker://localhost:5000/${image}:${tag}"

# Delete image in local docker registry
docker-delete-from-local-registry image tag:
	#!/usr/bin/bash
	rockcraft.skopeo --insecure-policy delete \
		--tls-verify=false \
		"docker://localhost:5000/${image}:${tag}"

# List tags in local docker registry
docker-list-tags-in-local-registry image:
	#!/usr/bin/bash
	rockcraft.skopeo --insecure-policy list-tags \
		--tls-verify=false \
		"docker://localhost:5000/${image}"
