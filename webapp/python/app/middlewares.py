from http import HTTPStatus
from typing import Annotated

from fastapi import Cookie, HTTPException
from sqlalchemy import text

from .models import Chair, Owner, User
from .sql import engine


def app_auth_middleware(app_session: Annotated[str | None, Cookie()] = None) -> User:
    if not app_session:
        raise HTTPException(
            status_code=HTTPStatus.UNAUTHORIZED, detail="app_session cookie is required"
        )

    with engine.begin() as conn:
        row = conn.execute(
            text("SELECT * FROM users WHERE access_token = :access_token"),
            {"access_token": app_session},
        ).fetchone()

        if row is None:
            raise HTTPException(
                status_code=HTTPStatus.UNAUTHORIZED, detail="invalid access token"
            )
        user = User.model_validate(row)

        return user


def owner_auth_middleware(
    owner_session: Annotated[str | None, Cookie()] = None,
) -> Owner:
    if not owner_session:
        raise HTTPException(
            status_code=HTTPStatus.UNAUTHORIZED,
            detail="owner_session cookie is required",
        )

    with engine.begin() as conn:
        row = conn.execute(
            text("SELECT * FROM owners WHERE access_token = :access_token"),
            {"access_token": owner_session},
        ).fetchone()

        if row is None:
            raise HTTPException(
                status_code=HTTPStatus.UNAUTHORIZED, detail="invalid access token"
            )

        return Owner.model_validate(row)


def chair_auth_middleware(
    chair_session: Annotated[str | None, Cookie()] = None,
) -> Chair:
    if not chair_session:
        raise HTTPException(
            status_code=HTTPStatus.UNAUTHORIZED,
            detail="chair_session cookie is required",
        )

    with engine.begin() as conn:
        row = conn.execute(
            text("SELECT * FROM chairs WHERE access_token = :access_token"),
            {"access_token": chair_session},
        ).fetchone()

        if row is None:
            raise HTTPException(
                status_code=HTTPStatus.UNAUTHORIZED, detail="invalid access token"
            )

        return Chair.model_validate(row)
