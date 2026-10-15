import json
import os

import psycopg
from psycopg.rows import dict_row
from flask import Flask, jsonify, redirect, render_template, url_for

app = Flask(__name__)
app.config["APP_ENV"] = os.environ.get("APP_ENV", "development")
CACHE_KEY = "jugadores:v1"
CACHE_TTL = 30  # Segundos desde que guardamos la copia; leerla no renueva el plazo.


@app.context_processor
def contexto_entorno():
    return {"is_production": app.config["APP_ENV"] == "production"}


def get_db_connection():
    return psycopg.connect(
        host=os.environ["DB_HOST"],
        port=os.environ["DB_PORT"],
        dbname=os.environ["POSTGRES_DB"],
        user=os.environ["POSTGRES_USER"],
        password=os.environ["POSTGRES_PASSWORD"],
        connect_timeout=3,
    )

def get_redis_connection():
    """Prepara el cliente que usamos solo en producción."""
    import redis
    from redis.backoff import NoBackoff
    from redis.retry import Retry

    return redis.Redis(
        host=os.environ["REDIS_HOST"],
        port=int(os.environ["REDIS_PORT"]),
        socket_connect_timeout=1,
        socket_timeout=1,
        retry=Retry(NoBackoff(), 0),
        decode_responses=True,
    )


@app.route("/")
def home():
    return redirect(url_for("jugadores"))


def agrupar_jugadores(lista_jugadores):
    # Aceptamos también los nombres de posiciones usados en el diseño de Stitch.
    grupos = [
        {"clave": "porteros", "titulo": "Porteros", "posiciones": {"portero", "arquero"}, "jugadores": []},
        {"clave": "defensas", "titulo": "Defensas", "posiciones": {"defensa", "defensor"}, "jugadores": []},
        {"clave": "centrocampistas", "titulo": "Centrocampistas", "posiciones": {"centrocampista", "mediocampista"}, "jugadores": []},
        {"clave": "delanteros", "titulo": "Delanteros", "posiciones": {"delantero"}, "jugadores": []},
        {"clave": "otros", "titulo": "Otras posiciones", "posiciones": set(), "jugadores": []},
    ]
    for jugador in lista_jugadores:
        posicion = jugador["posicion"].strip().casefold()
        grupo = next((grupo for grupo in grupos if posicion in grupo["posiciones"]), grupos[-1])
        grupo["jugadores"].append(jugador)
    return [grupo for grupo in grupos if grupo["jugadores"]]


@app.route("/health")
def health():
    db_connected = comprobar_db()
    cache_status = "not_applicable"
    if app.config["APP_ENV"] == "production":
        cache_status = "connected" if comprobar_redis() else "disconnected"
    healthy = db_connected and cache_status != "disconnected"
    response = jsonify({
        "status": "healthy" if healthy else "degraded",
        "services": {
            "web": "connected",
            "db": "connected" if db_connected else "disconnected",
            "cache": cache_status,
        },
    })
    response.headers["Cache-Control"] = "no-store"
    return response, 200 if healthy else 503



def comprobar_redis():
    """Comprueba la conexión sin leer ni renovar la caché de jugadores."""
    import redis

    try:
        with get_redis_connection() as connection:
            return connection.ping()
    except redis.RedisError:
        return False


def comprobar_db():
    """Comprueba una consulta real, sin leer ni modificar los jugadores."""
    try:
        with get_db_connection() as connection:
            with connection.cursor() as cursor:
                cursor.execute("SET LOCAL statement_timeout = '3s';")
                cursor.execute("SELECT 1;")
                return cursor.fetchone()[0] == 1
    except psycopg.Error:
        return False


def consultar_jugadores_db():
    with get_db_connection() as connection:
        with connection.cursor(row_factory=dict_row) as cursor:
            cursor.execute("SELECT nombre, posicion, imagen FROM jugadores ORDER BY id;")
            return cursor.fetchall()


def obtener_jugadores():
    """Devuelve el listado y una explicación del origen de esta petición."""
    if app.config["APP_ENV"] != "production":
        return consultar_jugadores_db(), "PostgreSQL", "Desarrollo: caché desactivada."

    import redis

    cache_disponible = True
    try:
        with get_redis_connection() as connection:
            contenido = connection.get(CACHE_KEY)
            ttl = connection.ttl(CACHE_KEY)
        if contenido is not None and ttl >= 0:
            datos = json.loads(contenido)
            # Una copia dañada se descarta y se vuelve a consultar PostgreSQL.
            if isinstance(datos, list) and all(
                isinstance(jugador, dict)
                and isinstance(jugador.get("nombre"), str)
                and isinstance(jugador.get("posicion"), str)
                and (jugador.get("imagen") is None or isinstance(jugador["imagen"], str))
                for jugador in datos
            ):
                return datos, "Redis", f"A la copia le quedaban {ttl} s al cargar esta página."
    except ValueError:
        pass
    except redis.RedisError:
        cache_disponible = False

    datos = consultar_jugadores_db()
    if cache_disponible:
        try:
            with get_redis_connection() as connection:
                connection.set(CACHE_KEY, json.dumps(datos), ex=CACHE_TTL)
            return datos, "PostgreSQL", f"Copia guardada en Redis durante {CACHE_TTL} s."
        except redis.RedisError:
            pass
    return datos, "PostgreSQL", "No se pudo utilizar Redis; consulta directa a la base."


@app.route("/jugadores")
def jugadores():
    try:
        lista_jugadores, origen, detalle_cache = obtener_jugadores()
    except psycopg.Error:
        response = app.make_response((render_template(
            "jugadores.html",
            jugadores=[],
            error="No se pudo consultar el listado de jugadores. Inténtalo de nuevo más tarde.",
        ), 503))
        response.headers["Cache-Control"] = "no-store"
        return response

    response = app.make_response(render_template(
        "jugadores.html",
        jugadores=lista_jugadores,
        grupos=agrupar_jugadores(lista_jugadores),
        error=None,
        origen=origen,
        detalle_cache=detalle_cache,
    ))
    # Cada recarga llega a Flask; la caché del listado se gestiona en Redis.
    response.headers["Cache-Control"] = "no-store"
    return response


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
