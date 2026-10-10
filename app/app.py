import os

import psycopg
from flask import Flask, jsonify

app = Flask(__name__)

@app.route("/")
def home():
    return "<h1>Servicio Web Activo</h1><p>Práctica 1 - Despliegue Multi-Entorno</p>"

@app.route("/health")
def health():
    return jsonify({"status": "healthy", "service": "web"}), 200


@app.route("/db-check")
def db_check():
    try:
        with psycopg.connect(
            host=os.environ["DB_HOST"],
            port=os.environ["DB_PORT"],
            dbname=os.environ["POSTGRES_DB"],
            user=os.environ["POSTGRES_USER"],
            password=os.environ["POSTGRES_PASSWORD"],
            connect_timeout=3,
        ) as connection:
            with connection.cursor() as cursor:
                cursor.execute("SELECT 1;")
                result = cursor.fetchone()[0]
    except psycopg.Error:
        return jsonify({"status": "disconnected", "service": "db"}), 503

    return jsonify({"status": "connected", "service": "db", "result": result}), 200


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
