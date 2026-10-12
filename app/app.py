import os

import psycopg
from psycopg.rows import dict_row
from flask import Flask, jsonify, redirect, render_template, url_for

app = Flask(__name__)


def get_db_connection():
    return psycopg.connect(
        host=os.environ["DB_HOST"],
        port=os.environ["DB_PORT"],
        dbname=os.environ["POSTGRES_DB"],
        user=os.environ["POSTGRES_USER"],
        password=os.environ["POSTGRES_PASSWORD"],
        connect_timeout=3,
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
    response = jsonify({
        "status": "healthy" if db_connected else "degraded",
        "service": "web",
        "services": {
            "web": "connected",
            "db": "connected" if db_connected else "disconnected",
            "cache": "not_applicable",
        },
    })
    response.headers["Cache-Control"] = "no-store"
    return response, 200 if db_connected else 503


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


@app.route("/db-check")
def db_check():
    if not comprobar_db():
        return jsonify({"status": "disconnected", "service": "db"}), 503

    return jsonify({"status": "connected", "service": "db", "result": 1}), 200


@app.route("/jugadores")
def jugadores():
    try:
        with get_db_connection() as connection:
            with connection.cursor(row_factory=dict_row) as cursor:
                cursor.execute("SELECT nombre, posicion, imagen FROM jugadores ORDER BY id;")
                lista_jugadores = cursor.fetchall()
    except psycopg.Error:
        return render_template(
            "jugadores.html",
            jugadores=[],
            error="No se pudo consultar el listado de jugadores. Inténtalo de nuevo más tarde.",
        ), 503

    return render_template(
        "jugadores.html",
        jugadores=lista_jugadores,
        grupos=agrupar_jugadores(lista_jugadores),
        error=None,
    )


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
