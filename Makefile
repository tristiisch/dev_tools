scripts:
	@./main.sh add
	@./main.sh set_permissions

traefik:
	@docker network create traefik-local || true
	@openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout ./traefik/certs/selfsigned.key -out ./traefik/certs/selfsigned.cert -subj "/C=FR/ST=AURA/L=Annecy/O=SGS/OU=Genilink/CN=*.local"
	@docker compose -f ./traefik/docker-compose.yml up -d --force-recreate

.PHONY: scripts traefik
