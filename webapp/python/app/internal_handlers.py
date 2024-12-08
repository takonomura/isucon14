from http import HTTPStatus

from fastapi import APIRouter
from sqlalchemy import text

from .models import Chair, Ride
from .sql import engine

router = APIRouter(prefix="/api/internal")


# このAPIをインスタンス内から一定間隔で叩かせることで、椅子とライドをマッチングさせる
@router.get("/matching", status_code=HTTPStatus.NO_CONTENT)
def internal_get_matching() -> None:
    # MEMO: 一旦最も待たせているリクエストに適当な空いている椅子マッチさせる実装とする。おそらくもっといい方法があるはず…
    with engine.begin() as conn:
        row = conn.execute(
            text(
                "SELECT * FROM rides WHERE chair_id IS NULL ORDER BY created_at LIMIT 1"
            )
        ).fetchone()
    if row is None:
        return
    ride = Ride.model_validate(row)

    matched: Chair | None = None
    empty = False
    for _ in range(10):
        with engine.begin() as conn:
            row = conn.execute(
                text(
                    "SELECT * FROM chairs INNER JOIN (SELECT id FROM chairs WHERE is_active = TRUE ORDER BY RAND() LIMIT 1) AS tmp ON chairs.id = tmp.id LIMIT 1"
                )
            ).fetchone()
        if row is None:
            return
        matched = Chair.model_validate(row)

        with engine.begin() as conn:
            empty = bool(
                conn.execute(
                    text(
                        "SELECT COUNT(*) = 0 FROM (SELECT COUNT(chair_sent_at) = 6 AS completed FROM ride_statuses WHERE ride_id IN (SELECT id FROM rides WHERE chair_id = :chair_id) GROUP BY ride_id) is_completed WHERE completed = FALSE"
                    ),
                    {"chair_id": matched.id},
                ).scalar()
            )
        if empty:
            break

    if not empty:
        return

    assert matched is not None
    with engine.begin() as conn:
        conn.execute(
            text("UPDATE rides SET chair_id = :chair_id WHERE id = :id"),
            {"chair_id": matched.id, "id": ride.id},
        )
