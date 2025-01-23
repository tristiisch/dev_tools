scripts:
	@./main.sh add
	@./main.sh set_permissions

traefik:
	@docker network create traefik-local || true
	@docker compose -f ./traefik/docker-compose.yml up -d --force-recreate

.PHONY: scripts traefik
