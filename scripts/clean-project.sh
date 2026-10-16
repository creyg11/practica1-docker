#!/bin/sh
# Ejecutar desde la raíz del proyecto mediante make clean-all.
set -eu

compose_dev() {
    docker compose --env-file .env.dev -f docker-compose.dev.yml "$@"
}

compose_prod() {
    docker compose --env-file .env.prod -f docker-compose.prod.yml "$@"
}

# Validar los dos entornos antes de eliminar recursos.
compose_dev config --quiet
compose_prod config --quiet

# Recoger los nombres generados por Compose y las imágenes realmente usadas.
# Los IDs permiten localizar también una imagen que haya perdido su etiqueta.
dev_images=$(compose_dev config --images)
prod_images=$(compose_prod config --images)
dev_ids=$(compose_dev images --quiet)
prod_ids=$(compose_prod images --quiet)
base_images=$(awk '$1 == "FROM" {print $2}' app/Dockerfile app/Dockerfile.prod)

printf 'Eliminando los dos entornos y sus volúmenes de PostgreSQL.\n'
# Primero quitar TODOS nuestros contenedores, que comparten la imagen PostgreSQL.
compose_dev down --volumes
compose_prod down --volumes

printf 'Eliminando imágenes de web, PostgreSQL, Redis y Python.\n'
cleanup_status=0
# Eliminar etiquetas antes que IDs; algunos candidatos se repetirán o ya no existirán.
for project_image in $dev_images $prod_images $base_images $dev_ids $prod_ids; do
    if docker image inspect "$project_image" >/dev/null 2>&1; then
        if ! docker image rm "$project_image"; then
            printf 'No se pudo eliminar %s; revisa si otro contenedor la utiliza.\n' "$project_image" >&2
            cleanup_status=1
        fi
    else
        # Una imagen ausente es normal; un daemon inaccesible debe producir error.
        docker info >/dev/null
    fi
done

# No forzamos borrados ni hacemos prune global sobre otros proyectos.
exit "$cleanup_status"
