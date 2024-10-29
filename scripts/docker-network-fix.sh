#!/bin/sh
set -eu

# Check if yq is installed
if ! command -v yq > /dev/null; then
	echo "yq is not installed. Please install it to proceed."
	exit 1
fi

COMPOSE_ARGS="${1:-}"

# Extract project name and service names
PROJECT_NAME=$(docker compose ${COMPOSE_ARGS} config | yq e '.name' -)
SERVICES_NAMES=$(docker compose ${COMPOSE_ARGS} config | yq e '.services | keys | .[]' -)

# Iterate over each service
for service in ${SERVICES_NAMES}; do

	# Extract debug information
	SERVICE_NAME=$(docker compose ${COMPOSE_ARGS} config | yq e ".services.${service}.container_name // \"${service}\"" -)
	SERVICE_NETWORKS=$(docker compose ${COMPOSE_ARGS} config | yq e ".services.${service}.networks | keys | .[]" -)

	container_name="${PROJECT_NAME}-${SERVICE_NAME}-1"

	# Iterate over each network for the service
	for network in ${SERVICE_NETWORKS}; do
		if [ "${network}" = "default" ]; then
			network="${PROJECT_NAME}_${network}"
		fi

		# Check if container is already connected to the network
		if ! docker network inspect "${network}" --format "{{json .Containers}}" | grep -q "${container_name}"; then
			echo "Connecting ${container_name} to ${network}..."
			docker network connect "${network}" "${container_name}"
		fi
	done
done
