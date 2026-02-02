import os
import logging

from flask import Flask, Response
import psycopg2

app = Flask(__name__)
logging.basicConfig(level=logging.INFO)

@app.route("/")
def hello_world():
    name = os.environ.get("NAME", "World")
    logging.info(f"Hello {name}")
    return f"Hello {name}!"

@app.route("/db-test")
def db_test():
    try:
        conn = psycopg2.connect(
            host=os.environ["DB_HOST"],
            dbname=os.environ["DB_NAME"],
            user=os.environ["DB_USER"],
            password=os.environ["DB_PASSWORD"],
            connect_timeout=3,
        )
        conn.close()
        logging.info("DB connection test: success")
        return Response("DB connection test: success", status=200)
    except Exception:
        logging.warning("DB connection test: failed")
        return Response("DB connection test: failed", status=500)

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=int(os.environ.get("PORT", 8080)))
