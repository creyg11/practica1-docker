import os

import psycopg
from psycopg.rows import dict_row
from flask import Flask, jsonify, render_template

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
    return (
        "<h1>Servicio Web Activo</h1>"
        "<p>Práctica 1 - Despliegue Multi-Entorno</p>"
        '<p><a href="/jugadores">Ver jugadores</a></p>'
    )


@app.route("/health")
def health():
    return jsonify({"status": "healthy", "service": "web"}), 200


@app.route("/db-check")
def db_check():
    try:
        with get_db_connection() as connection:
            with connection.cursor() as cursor:
                cursor.execute("SELECT 1;")
                result = cursor.fetchone()[0]
    except psycopg.Error:
        return jsonify({"status": "disconnected", "service": "db"}), 503

    return jsonify({"status": "connected", "service": "db", "result": result}), 200


@app.route("/jugadores")
def jugadores():
    try:
        with get_db_connection() as connection:
            with connection.cursor(row_factory=dict_row) as cursor:
                cursor.execute("SELECT nombre, posicion FROM jugadores ORDER BY id;")
                lista_jugadores = cursor.fetchall()
    except psycopg.Error:
        return render_template(
            "jugadores.html",
            jugadores=[],
            error="No se pudo consultar el listado de jugadores. Inténtalo de nuevo más tarde.",
        ), 503

    return render_template("jugadores.html", jugadores=lista_jugadores, error=None)


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
