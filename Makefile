#The Compose file and environment file are kept in srcs as required by the subject.
COMPOSE_FILE := srcs/docker-compose.yml
ENV_FILE := srcs/.env
COMPOSE := docker compose --env-file $(ENV_FILE) -f $(COMPOSE_FILE)

#The first target is the default: prepare, validate, build, and start the whole stack.
.NOTPARALLEL:

.PHONY: all setup check config build up down stop start restart logs ps clean fclean re verify purge english-comments help

all: setup check build up

#Creates .env, local secrets, host data directories, and the local hosts entry.
setup:
	@sh srcs/requirements/tools/setup.sh

#Performs static checks and validates Compose when Docker is available.
check:
	@sh srcs/requirements/tools/static-check.sh

#Renders the fully resolved Compose configuration without starting containers.
config: setup
	@$(COMPOSE) config

#--pull refreshes the pinned Debian 12.14 base image without using a latest tag.
build: setup
	@$(COMPOSE) build --pull

#Starts containers in detached mode and removes obsolete containers from old configurations.
up: setup
	@$(COMPOSE) up -d --remove-orphans
	@$(COMPOSE) ps

#Removes containers and the project network but preserves named volumes and data.
down:
	@$(COMPOSE) down --remove-orphans

#Stops containers without removing them.
stop:
	@$(COMPOSE) stop

#Starts already-created containers.
start:
	@$(COMPOSE) start

#Restarts all services using Compose.
restart:
	@$(COMPOSE) restart

#Follows logs from all services. Exit with Ctrl+C.
logs:
	@$(COMPOSE) logs --follow --tail=100

#Shows the current state of the stack.
ps:
	@$(COMPOSE) ps

#Safe cleanup: containers and network only; persistent data remains.
clean: down

#Removes containers, locally built images, and Docker volume objects.
#Host data under /home/<login>/data is intentionally not deleted here.
fclean: setup
	@$(COMPOSE) down --remove-orphans --volumes --rmi local

#Rebuilds the stack while preserving host data.
re: fclean all

#Runs live checks for ports, TLS, health, volumes, networking, and WordPress users.
verify: setup
	@sh srcs/requirements/tools/verify-runtime.sh

#Destructive reset. It requires an explicit typed confirmation.
purge: setup
	@sh srcs/requirements/tools/purge-data.sh

help:
	@printf '%s\n' \
		'make                 prepare, check, build, and start' \
		'make setup           create .env, secrets, data directories, hosts entry' \
		'make check           run static validation' \
		'make config          render Compose configuration' \
		'make build           build all three images' \
		'make up/down         start or remove the stack' \
		'make logs/ps         inspect the stack' \
		'make verify          run live validation tests' \
		'make fclean          remove containers, images, and Docker volume objects' \
		'make purge           also delete persistent host data after confirmation'