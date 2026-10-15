# Ejecutar desde la carpeta del proyecto. Por defecto se utiliza desarrollo.
.DEFAULT_GOAL := help
ENV ?= dev

ifneq ($(ENV),dev)
ifneq ($(ENV),prod)
$(error ENV debe ser dev o prod)
endif
endif

COMPOSE = docker compose --env-file .env.$(ENV) -f docker-compose.$(ENV).yml
ENV_EXAMPLE = $(if $(filter prod,$(ENV)),.env.prod.example,.env.example)
CACHE_KEY = jugadores:v1
SERVICE ?=

.PHONY: help init check-env check-prod validate dev prod up build stop down ps logs \
        web-rebuild db players db-stop db-start db-remove db-recreate health \
        images networks volumes security redis redis-ping redis-stop redis-start \
        cache-show cache-ttl cache-clear coach-add coach-remove demo

help: ## Mostrar esta ayuda (también es la acción de make sin argumentos).
	@printf 'Uso: make <comando> ENV=dev|prod (por defecto: dev)\n\n'
	@awk 'BEGIN {FS = ":.*## "} /^[a-z][a-z-]*:.*## / {printf "  %-15s %s\n", $$1, $$2}' Makefile
	@printf '\nEjemplos: make prod | make db ENV=prod | make cache-ttl ENV=prod\n'

init: ## Copiar la plantilla de entorno si no existe; no sobrescribe credenciales.
	@if [ -e .env.$(ENV) ]; then \
		printf '.env.$(ENV) ya existe; se conserva.\n'; \
	else \
		(umask 077; cp $(ENV_EXAMPLE) .env.$(ENV)) && \
		printf 'Creado .env.$(ENV). Edita la contraseña antes del primer arranque.\n'; \
	fi

check-env:
	@test -f .env.$(ENV) || { printf 'Falta .env.$(ENV). Ejecuta make init ENV=$(ENV) y edítalo.\n'; exit 1; }

check-prod:
	@test '$(ENV)' = prod || { printf 'Redis solo está en producción. Añade ENV=prod.\n'; exit 1; }

validate: check-env ## Validar Compose sin mostrar las contraseñas.
	$(COMPOSE) config --quiet

dev: ## Construir y arrancar desarrollo, esperando a que esté preparado.
	$(MAKE) --no-print-directory up ENV=dev

prod: ## Construir y arrancar producción, esperando a que esté saludable.
	$(MAKE) --no-print-directory up ENV=prod

up: validate ## Construir y arrancar el entorno seleccionado en segundo plano.
	$(COMPOSE) up --build -d --wait --wait-timeout 120

build: validate ## Construir la imagen de la web sin arrancar contenedores.
	$(COMPOSE) build web

stop: check-env ## Detener los servicios, conservando contenedores, red y volumen.
	$(COMPOSE) stop

down: check-env ## Eliminar contenedores y red; conservar los datos de PostgreSQL.
	$(COMPOSE) down

ps: check-env ## Ver contenedores, incluidos los detenidos, y su estado.
	$(COMPOSE) ps -a

logs: check-env ## Seguir logs; SERVICE=web|db|redis filtra. Ctrl+C solo sale de los logs.
	$(COMPOSE) logs --tail=50 --follow $(SERVICE)

web-rebuild: validate ## Reconstruir y recrear solo la web; DB y Redis deben estar arrancados.
	$(COMPOSE) up --build -d --no-deps --force-recreate --wait --wait-timeout 120 web

db: check-env ## Abrir psql; pide la contraseña del usuario del entorno. Salir con \q.
	$(COMPOSE) exec db sh -c 'psql -h db -U "$$POSTGRES_USER" -d "$$POSTGRES_DB" -W'

players: check-env ## Mostrar los jugadores guardados en PostgreSQL (sin pasar por Redis).
	$(COMPOSE) exec -T db sh -c 'psql -U "$$POSTGRES_USER" -d "$$POSTGRES_DB" -v ON_ERROR_STOP=1 -c "SELECT id, nombre, posicion, imagen FROM jugadores ORDER BY id;"'

coach-add: check-env ## Añadir el entrenador de prueba; repetirlo no crea duplicados.
	$(COMPOSE) exec -T db sh -c 'psql -U "$$POSTGRES_USER" -d "$$POSTGRES_DB" -v ON_ERROR_STOP=1' < db/demo/coach-add.sql
	@printf 'En producción: make cache-clear ENV=prod y recarga la web para ver el cambio.\n'

coach-remove: check-env ## Borrar únicamente el entrenador de prueba de PostgreSQL.
	$(COMPOSE) exec -T db sh -c 'psql -U "$$POSTGRES_USER" -d "$$POSTGRES_DB" -v ON_ERROR_STOP=1' < db/demo/coach-remove.sql
	@printf 'En producción: make cache-clear ENV=prod y recarga la web para ver el cambio.\n'

db-stop: check-env ## Detener PostgreSQL para demostrar un fallo de conexión.
	$(COMPOSE) stop db

db-start: check-env ## Crear o arrancar PostgreSQL y esperar a que esté saludable.
	$(COMPOSE) up -d --wait --wait-timeout 120 db

db-remove: check-env ## Detener y eliminar solo el contenedor DB; conservar su volumen.
	$(COMPOSE) rm --stop --force db

db-recreate: check-env ## Sustituir el contenedor DB conservando el volumen y los datos.
	$(COMPOSE) up -d --force-recreate --wait --wait-timeout 120 db

health: check-env ## Consultar /health desde web; falla el comando si HTTP no es 200.
	$(COMPOSE) exec -T web python -c 'import http.client, sys; c = http.client.HTTPConnection("127.0.0.1", 5000, timeout=10); c.request("GET", "/health"); r = c.getresponse(); print("HTTP", r.status); print(r.read().decode()); c.close(); sys.exit(0 if r.status == 200 else 1)'

images: check-env ## Ver las imágenes utilizadas por los contenedores del entorno.
	$(COMPOSE) images

networks: check-env ## Ver redes e IP de los contenedores existentes del entorno.
	@task_container_ids=$$($(COMPOSE) ps -aq) || exit $$?; \
	if [ -n "$$task_container_ids" ]; then \
		docker inspect --format '{{.Name}}: {{json .NetworkSettings.Networks}}' $$task_container_ids; \
	else printf 'No hay contenedores en este entorno. Arranca con make up ENV=$(ENV).\n'; fi

volumes: check-env ## Ver montajes, rutas del host y permisos de los contenedores existentes.
	@task_container_ids=$$($(COMPOSE) ps -aq) || exit $$?; \
	if [ -n "$$task_container_ids" ]; then \
		docker inspect --format '{{.Name}}: {{json .Mounts}}' $$task_container_ids; \
	else printf 'No hay contenedores en este entorno. Arranca con make up ENV=$(ENV).\n'; fi

security: check-env ## Mostrar usuario de web y dirección publicada de su puerto.
	$(COMPOSE) exec -T web id
	$(COMPOSE) port web 5000

redis: check-prod check-env ## Abrir redis-cli (solo ENV=prod). Salir con exit.
	$(COMPOSE) exec redis redis-cli

redis-ping: check-prod check-env ## Comprobar Redis desde su contenedor: debe responder PONG.
	$(COMPOSE) exec -T redis redis-cli ping

redis-stop: check-prod check-env ## Detener Redis para probar la consulta directa a PostgreSQL.
	$(COMPOSE) stop redis

redis-start: check-prod check-env ## Arrancar Redis y esperar a que esté saludable.
	$(COMPOSE) up -d --wait --wait-timeout 120 redis

cache-show: check-prod check-env ## Mostrar el JSON de la copia de jugadores, si existe.
	$(COMPOSE) exec -T redis redis-cli GET $(CACHE_KEY)

cache-ttl: check-prod check-env ## Ver segundos restantes; -2 significa que no existe la copia.
	$(COMPOSE) exec -T redis redis-cli TTL $(CACHE_KEY)

cache-clear: check-prod check-env ## Borrar solo la copia temporal de jugadores; no toca PostgreSQL.
	$(COMPOSE) exec -T redis redis-cli DEL $(CACHE_KEY)

demo: ## Mostrar el orden de la demostración; no ejecuta cambios.
	@printf '%s\n' \
	  '1. make dev / make prod: arranque de cada entorno.' \
	  '2. make ps ENV=prod y make health ENV=prod: estado.' \
	  '3. make networks ENV=prod y make volumes ENV=prod: redes y persistencia.' \
	  '4. make security ENV=prod: usuario sin root y puerto local.' \
	  '5a. make coach-add ENV=prod; make cache-clear ENV=prod; recargar: aparece el entrenador.' \
	  '5b. make db-remove ENV=prod; make ps ENV=prod: ya no existe el contenedor DB.' \
	  '5c. make db-start ENV=prod; make players ENV=prod: el entrenador sigue guardado.' \
	  '5d. make cache-clear ENV=prod; recargar: el entrenador viene de PostgreSQL.' \
	  '5e. make coach-remove ENV=prod; make players ENV=prod; make cache-clear ENV=prod; recargar: desaparece.' \
	  '6. Caché: make cache-clear ENV=prod; recargar la web: PostgreSQL.' \
	  '7. Recargar antes de 30 s: Redis. make cache-ttl ENV=prod.' \
	  '8. Esperar a que caduque y recargar: PostgreSQL (si nadie regeneró la copia).' \
	  '9. make redis-stop ENV=prod; recargar: PostgreSQL; después make redis-start ENV=prod.' \
	  '10. make db-stop ENV=dev; comprobar el panel; recuperar con make db-start ENV=dev.' \
	  '11. make down ENV=dev / make down ENV=prod: terminar conservando los datos.'
