import nox


@nox.session(python="3.13")
def lint(session: nox.Session) -> None:
    session.install("pre-commit")
    session.run("pre-commit", "run", "--all-files")


@nox.session(python="3.13")
def mypy(session: nox.Session) -> None:
    session.install(
        "mypy",
        "cryptography",
        "fastapi",
        "python-ulid",
        "sqlalchemy",
        "urllib3",
    )
    session.run(
        "mypy",
        "app",
    )
