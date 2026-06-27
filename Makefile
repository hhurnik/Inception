# [EN] The Compose file and environment file are kept in srcs as required by the subject.
# [PL] Plik Compose i plik środowiskowy są przechowywane w srcs zgodnie z wymaganiami subjectu.
COMPOSE_FILE := srcs/docker-compose.yml
ENV_FILE := srcs/.env
COMPOSE := docker compose --env-file $(ENV_FILE) -f $(COMPOSE_FILE)

# [EN] The first target is the default: prepare, validate, build, and start the whole stack.
# [PL] Pierwszy target jest domyślny: przygotowuje, sprawdza, buduje i uruchamia cały stack.
.NOTPARALLEL:

.PHONY: all setup check config build up down stop start restart logs ps clean fclean re verify purge english-comments help

all: setup check build up

# [EN] Creates .env, local secrets, host data directories, and the local hosts entry.
# [PL] Tworzy .env, lokalne sekrety, katalogi danych hosta oraz lokalny wpis hosts.
setup:
	@sh srcs/requirements/tools/setup.sh

# [EN] Performs static checks and validates Compose when Docker is available.
# [PL] Wykonuje kontrole statyczne i sprawdza Compose, kiedy Docker jest dostępny.
check:
	@sh srcs/requirements/tools/static-check.sh

# [EN] Renders the fully resolved Compose configuration without starting containers.
# [PL] Wyświetla w pełni rozwiniętą konfigurację Compose bez uruchamiania kontenerów.
config: setup
	@$(COMPOSE) config

# [EN] --pull refreshes the pinned Debian 12.14 base image without using a latest tag.
# [PL] --pull odświeża przypięty obraz bazowy Debian 12.14 bez używania tagu latest.
build: setup
	@$(COMPOSE) build --pull

# [EN] Starts containers in detached mode and removes obsolete containers from old configurations.
# [PL] Uruchamia kontenery w tle i usuwa przestarzałe kontenery ze starych konfiguracji.
up: setup
	@$(COMPOSE) up -d --remove-orphans
	@$(COMPOSE) ps

# [EN] Removes containers and the project network but preserves named volumes and data.
# [PL] Usuwa kontenery i sieć projektu, ale zachowuje nazwane wolumeny oraz dane.
down:
	@$(COMPOSE) down --remove-orphans

# [EN] Stops containers without removing them.
# [PL] Zatrzymuje kontenery bez ich usuwania.
stop:
	@$(COMPOSE) stop

# [EN] Starts already-created containers.
# [PL] Uruchamia wcześniej utworzone kontenery.
start:
	@$(COMPOSE) start

# [EN] Restarts all services using Compose.
# [PL] Restartuje wszystkie usługi za pomocą Compose.
restart:
	@$(COMPOSE) restart

# [EN] Follows logs from all services. Exit with Ctrl+C.
# [PL] Śledzi logi wszystkich usług. Wyjście przez Ctrl+C.
logs:
	@$(COMPOSE) logs --follow --tail=100

# [EN] Shows the current state of the stack.
# [PL] Pokazuje bieżący stan stacku.
ps:
	@$(COMPOSE) ps

# [EN] Safe cleanup: containers and network only; persistent data remains.
# [PL] Bezpieczne czyszczenie: tylko kontenery i sieć; trwałe dane pozostają.
clean: down

# [EN] Removes containers, locally built images, and Docker volume objects.
# [PL] Usuwa kontenery, lokalnie zbudowane obrazy i obiekty wolumenów Dockera.
# [EN] Host data under /home/<login>/data is intentionally not deleted here.
# [PL] Dane hosta w /home/<login>/data celowo nie są tutaj usuwane.
fclean: setup
	@$(COMPOSE) down --remove-orphans --volumes --rmi local

# [EN] Rebuilds the stack while preserving host data.
# [PL] Przebudowuje stack, zachowując dane hosta.
re: fclean all

# [EN] Runs live checks for ports, TLS, health, volumes, networking, and WordPress users.
# [PL] Uruchamia testy portów, TLS, healthchecków, wolumenów, sieci i użytkowników WordPressa.
verify: setup
	@sh srcs/requirements/tools/verify-runtime.sh

# [EN] Destructive reset. It requires an explicit typed confirmation.
# [PL] Destrukcyjny reset. Wymaga jawnego wpisania potwierdzenia.
purge: setup
	@sh srcs/requirements/tools/purge-data.sh

# [EN] Removes only educational Polish comment lines marked with [PL].
# [PL] Usuwa wyłącznie edukacyjne polskie linie komentarzy oznaczone [PL].
english-comments:
	@sh srcs/requirements/tools/remove-polish-comments.sh

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
		'make purge           also delete persistent host data after confirmation' \
		'make english-comments remove [PL] educational comments'
