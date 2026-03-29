from flask import Flask, jsonify, render_template


def create_app() -> Flask:
    app = Flask(__name__)

    @app.get("/")
    def home():
        return render_template("index.html")

    @app.get("/health")
    def health():
        return jsonify(status="OK"), 200

    return app


app = create_app()


if __name__ == "__main__":
    # For local dev only. In Docker we run with gunicorn.
    app.run(host="0.0.0.0", port=5000)

