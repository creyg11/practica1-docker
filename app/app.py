from flask import Flask, jsonify

app = Flask(__name__)

@app.route("/")
def home():
    return "<h1>Servicio Web Activo</h1><p>Práctica 1 - Despliegue Multi-Entorno</p>"

@app.route("/health")
def health():
    return jsonify({"status": "healthy", "service": "web"}), 200

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
