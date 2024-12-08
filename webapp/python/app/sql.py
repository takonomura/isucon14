import os

import sqlalchemy

host = os.getenv("ISUCON_DB_HOST", "127.0.0.1")
port = int(os.getenv("ISUCON_DB_PORT", "3306"))
user = os.getenv("ISUCON_DB_USER", "isucon")
password = os.getenv("ISUCON_DB_PASSWORD", "isucon")
dbname = os.getenv("ISUCON_DB_NAME", "isuride")

engine = sqlalchemy.create_engine(
    f"mysql+pymysql://{user}:{password}@{host}:{port}/{dbname}"
)
