import base64
import hashlib
import hmac
import ipaddress
import json
import os
import secrets
import sqlite3
import time
import uuid
from contextlib import contextmanager
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, Request
from pydantic import BaseModel, Field


DB_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "conecta_local.db")
TOKEN_LIFETIME_SECONDS = 8 * 60 * 60
PASSWORD_ITERATIONS = 310_000
router = APIRouter()


class AdminLogin(BaseModel):
    identificador: str = Field(min_length=1, max_length=254)
    contrasena: str = Field(min_length=1, max_length=1024)


@contextmanager
def _connection(path=None):
    connection = sqlite3.connect(path or DB_PATH, timeout=15)
    try:
        yield connection
        connection.commit()
    except Exception:
        connection.rollback()
        raise
    finally:
        connection.close()


open_database = _connection


def _add_column(cursor, table, column, definition):
    existing = {row[1] for row in cursor.execute(f"PRAGMA table_info({table})")}
    if column not in existing:
        cursor.execute(f"ALTER TABLE {table} ADD COLUMN {column} {definition}")


def ensure_admin_schema():
    with _connection() as connection:
        cursor = connection.cursor()
        cursor.execute(
            """
            CREATE TABLE IF NOT EXISTS admin_users (
                id_admin INTEGER PRIMARY KEY AUTOINCREMENT,
                identificador TEXT NOT NULL UNIQUE COLLATE NOCASE,
                password_hash TEXT NOT NULL,
                password_salt TEXT NOT NULL,
                rol TEXT NOT NULL CHECK (rol = 'superadmin'),
                activo INTEGER NOT NULL DEFAULT 1,
                created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
            )
            """
        )
        cursor.execute(
            """
            CREATE TABLE IF NOT EXISTS admin_login_attempts (
                id_attempt INTEGER PRIMARY KEY AUTOINCREMENT,
                identificador TEXT NOT NULL,
                client_ip TEXT NOT NULL,
                attempted_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
            )
            """
        )
        cursor.execute(
            """
            CREATE TABLE IF NOT EXISTS admin_sessions (
                jti TEXT PRIMARY KEY,
                id_admin INTEGER NOT NULL,
                issued_at INTEGER NOT NULL,
                expires_at INTEGER NOT NULL,
                revoked_at INTEGER
            )
            """
        )
        cursor.execute(
            "CREATE INDEX IF NOT EXISTS ix_admin_login_attempts "
            "ON admin_login_attempts(identificador, client_ip, attempted_at)"
        )
        cursor.execute(
            """
            CREATE TABLE IF NOT EXISTS auditoria_admin (
                id_log INTEGER PRIMARY KEY AUTOINCREMENT,
                actor_id INTEGER NOT NULL,
                actor_role TEXT NOT NULL,
                action TEXT NOT NULL,
                entity_type TEXT NOT NULL,
                entity_id TEXT NOT NULL,
                client_ip TEXT NOT NULL,
                reason TEXT NOT NULL,
                before_json TEXT,
                after_json TEXT,
                request_id TEXT NOT NULL,
                fecha TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
            )
            """
        )
        for column, definition in (
            ("actor_id", "INTEGER NOT NULL DEFAULT 0"),
            ("actor_role", "TEXT NOT NULL DEFAULT 'legacy'"),
            ("action", "TEXT NOT NULL DEFAULT ''"),
            ("entity_type", "TEXT NOT NULL DEFAULT 'legacy'"),
            ("entity_id", "TEXT NOT NULL DEFAULT ''"),
            ("client_ip", "TEXT NOT NULL DEFAULT '0.0.0.0'"),
            ("reason", "TEXT NOT NULL DEFAULT 'Registro anterior a la auditoría estructurada'"),
            ("before_json", "TEXT"),
            ("after_json", "TEXT"),
            ("request_id", "TEXT NOT NULL DEFAULT 'legacy'"),
            ("fecha", "TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP"),
        ):
            _add_column(cursor, "auditoria_admin", column, definition)
        legacy_columns = {
            row[1] for row in cursor.execute("PRAGMA table_info(auditoria_admin)")
        }
        if "accion" in legacy_columns:
            cursor.execute(
                """
                UPDATE auditoria_admin SET action = accion
                WHERE action = '' AND accion IS NOT NULL
                """
            )
        cursor.execute(
            """
            CREATE TABLE IF NOT EXISTS eventos_pedido (
                id_evento INTEGER PRIMARY KEY AUTOINCREMENT,
                id_pedido INTEGER NOT NULL,
                estado_anterior TEXT,
                estado_nuevo TEXT NOT NULL,
                actor_type TEXT NOT NULL,
                actor_id TEXT,
                motivo TEXT NOT NULL DEFAULT '',
                duracion_etapa_segundos INTEGER,
                fecha TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
            )
            """
        )
        cursor.execute(
            "CREATE INDEX IF NOT EXISTS ix_auditoria_fecha ON auditoria_admin(fecha DESC, id_log DESC)"
        )
        cursor.execute(
            "CREATE INDEX IF NOT EXISTS ix_auditoria_entidad ON auditoria_admin(entity_type, entity_id, id_log DESC)"
        )
        cursor.execute(
            "CREATE INDEX IF NOT EXISTS ix_eventos_pedido ON eventos_pedido(id_pedido, id_evento)"
        )
        cursor.execute(
            """
            CREATE TRIGGER IF NOT EXISTS auditoria_admin_no_update
            BEFORE UPDATE ON auditoria_admin BEGIN
                SELECT RAISE(ABORT, 'admin audit log is append-only');
            END
            """
        )
        cursor.execute(
            """
            CREATE TRIGGER IF NOT EXISTS auditoria_admin_no_delete
            BEFORE DELETE ON auditoria_admin BEGIN
                SELECT RAISE(ABORT, 'admin audit log is append-only');
            END
            """
        )
        cursor.execute(
            """
            CREATE TRIGGER IF NOT EXISTS eventos_pedido_no_update
            BEFORE UPDATE ON eventos_pedido BEGIN
                SELECT RAISE(ABORT, 'order events are append-only');
            END
            """
        )
        cursor.execute(
            """
            CREATE TRIGGER IF NOT EXISTS eventos_pedido_no_delete
            BEFORE DELETE ON eventos_pedido BEGIN
                SELECT RAISE(ABORT, 'order events are append-only');
            END
            """
        )
        for table in ("mensajes_chat", "soporte", "anuncios_globales"):
            if cursor.execute(
                "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = ?",
                (table,),
            ).fetchone():
                _add_column(cursor, table, "archivado", "INTEGER NOT NULL DEFAULT 0")
        if cursor.execute(
            "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = 'soporte'"
        ).fetchone():
            _add_column(
                cursor,
                "soporte",
                "canal",
                "TEXT NOT NULL DEFAULT 'admin_cliente'",
            )
        if cursor.execute(
            "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = 'mensajes_chat'"
        ).fetchone():
            message_columns = {
                row[1] for row in cursor.execute("PRAGMA table_info(mensajes_chat)")
            }
            if {"id_pedido", "canal", "id_mensaje"}.issubset(message_columns):
                cursor.execute(
                    "CREATE INDEX IF NOT EXISTS ix_mensajes_chat_ticket "
                    "ON mensajes_chat(id_pedido, canal, id_mensaje)"
                )
        if cursor.execute(
            "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = 'soporte'"
        ).fetchone():
            ticket_columns = {
                row[1] for row in cursor.execute("PRAGMA table_info(soporte)")
            }
            if {"id_pedido", "canal", "estado", "archivado"}.issubset(
                ticket_columns
            ):
                cursor.execute(
                    "CREATE INDEX IF NOT EXISTS ix_soporte_canal_estado "
                    "ON soporte(id_pedido, canal, estado, archivado)"
                )


def _b64url(value):
    return base64.urlsafe_b64encode(value).rstrip(b"=").decode("ascii")


def _jwt_secret():
    secret = os.environ.get("ADMIN_JWT_SECRET", "")
    if len(secret.encode("utf-8")) < 32:
        raise HTTPException(
            status_code=503,
            detail="La autenticación administrativa no está configurada. Defina ADMIN_JWT_SECRET (mínimo 32 bytes).",
        )
    return secret.encode("utf-8")


def _make_token(admin_id, role):
    header = _b64url(b'{"alg":"HS256","typ":"JWT"}')
    issued_at = int(time.time())
    expires_at = issued_at + TOKEN_LIFETIME_SECONDS
    token_id = secrets.token_urlsafe(24)
    claims = {
        "sub": str(admin_id),
        "role": role,
        "iat": issued_at,
        "exp": expires_at,
        "iss": "conecta-admin",
        "jti": token_id,
    }
    payload = _b64url(json.dumps(claims, separators=(",", ":")).encode("utf-8"))
    signing_input = f"{header}.{payload}".encode("ascii")
    signature = hmac.new(_jwt_secret(), signing_input, hashlib.sha256).digest()
    token = f"{header}.{payload}.{_b64url(signature)}"
    with _connection() as connection:
        connection.execute(
            "INSERT INTO admin_sessions (jti, id_admin, issued_at, expires_at) "
            "VALUES (?, ?, ?, ?)",
            (token_id, admin_id, issued_at, expires_at),
        )
    return token


def _verify_token(token):
    try:
        header, payload, signature = token.split(".")
        signing_input = f"{header}.{payload}".encode("ascii")
        expected = hmac.new(_jwt_secret(), signing_input, hashlib.sha256).digest()
        actual = base64.urlsafe_b64decode(
            signature + "=" * (-len(signature) % 4)
        )
        if not hmac.compare_digest(expected, actual):
            raise ValueError("invalid signature")
        claims = json.loads(
            base64.urlsafe_b64decode(payload + "=" * (-len(payload) % 4))
        )
        if (
            claims.get("iss") != "conecta-admin"
            or claims.get("role") != "superadmin"
            or int(claims.get("exp", 0)) <= int(time.time())
        ):
            raise ValueError("invalid claims")
        admin_id = int(claims["sub"])
        with _connection() as connection:
            row = connection.execute(
                """
                SELECT u.id_admin, u.identificador, u.rol
                FROM admin_users u
                JOIN admin_sessions s ON s.id_admin = u.id_admin
                WHERE u.id_admin = ? AND u.activo = 1 AND s.jti = ?
                  AND s.revoked_at IS NULL AND s.expires_at > ?
                """,
                (admin_id, claims["jti"], int(time.time())),
            ).fetchone()
        if not row:
            raise ValueError("inactive administrator")
        return {
            "id": row[0],
            "identificador": row[1],
            "rol": row[2],
            "jti": claims["jti"],
        }
    except HTTPException:
        raise
    except Exception as error:
        raise HTTPException(
            status_code=401,
            detail="Token administrativo inválido o vencido.",
            headers={"WWW-Authenticate": "Bearer"},
        ) from error


async def require_admin(request: Request):
    authorization = request.headers.get("Authorization", "")
    scheme, _, token = authorization.partition(" ")
    if scheme.lower() != "bearer" or not token:
        raise HTTPException(
            status_code=401,
            detail="Se requiere una sesión administrativa.",
            headers={"WWW-Authenticate": "Bearer"},
        )
    request.state.admin = _verify_token(token)
    return request.state.admin


@router.post("/api/admin/auth/login")
def admin_login(credentials: AdminLogin, request: Request):
    ensure_admin_schema()
    client_ip = validated_client_ip(request)
    identifier = credentials.identificador.strip()
    with _connection() as connection:
        attempts = connection.execute(
            """
            SELECT COUNT(*) FROM admin_login_attempts
            WHERE identificador = ? COLLATE NOCASE AND client_ip = ?
              AND attempted_at >= datetime('now', '-15 minutes')
            """,
            (identifier, client_ip),
        ).fetchone()[0]
        if attempts >= 5:
            raise HTTPException(
                status_code=429,
                detail="Demasiados intentos de acceso. Espera 15 minutos.",
            )
        row = connection.execute(
            """
            SELECT id_admin, password_hash, password_salt, rol
            FROM admin_users
            WHERE identificador = ? AND activo = 1
            """,
            (identifier,),
        ).fetchone()
    if row:
        actual = hashlib.pbkdf2_hmac(
            "sha256",
            credentials.contrasena.encode("utf-8"),
            bytes.fromhex(row[2]),
            PASSWORD_ITERATIONS,
        ).hex()
        valid = hmac.compare_digest(actual, row[1])
    else:
        hashlib.pbkdf2_hmac(
            "sha256",
            credentials.contrasena.encode("utf-8"),
            b"conecta-admin-fake-salt",
            PASSWORD_ITERATIONS,
        )
        valid = False
    if not valid:
        with _connection() as connection:
            connection.execute(
                "INSERT INTO admin_login_attempts (identificador, client_ip) VALUES (?, ?)",
                (identifier, client_ip),
            )
        raise HTTPException(status_code=401, detail="Credenciales administrativas incorrectas.")
    with _connection() as connection:
        connection.execute(
            "DELETE FROM admin_login_attempts WHERE identificador = ? COLLATE NOCASE "
            "AND client_ip = ?",
            (identifier, client_ip),
        )
    return {
        "access_token": _make_token(row[0], row[3]),
        "token_type": "bearer",
        "expires_in": TOKEN_LIFETIME_SECONDS,
        "rol": row[3],
    }


def validated_client_ip(request: Request):
    host = request.client.host if request.client else ""
    try:
        return str(ipaddress.ip_address(host))
    except ValueError as error:
        raise HTTPException(
            status_code=400,
            detail="No se pudo validar la dirección IP de origen; no se aplicó la acción.",
        ) from error


def append_admin_audit(
    cursor,
    request: Request,
    action,
    entity_type,
    entity_id,
    reason,
    before=None,
    after=None,
):
    admin = getattr(request.state, "admin", None)
    if not admin:
        raise HTTPException(status_code=401, detail="Sesión administrativa requerida.")
    normalized_reason = reason.strip()
    if not normalized_reason:
        raise HTTPException(status_code=422, detail="El motivo de la acción es obligatorio.")
    def encode(value):
        if value is None:
            return None
        return json.dumps(
            value, ensure_ascii=False, sort_keys=True, separators=(",", ":")
        )
    cursor.execute(
        """
        INSERT INTO auditoria_admin (
            actor_id, actor_role, action, entity_type, entity_id,
            client_ip, reason, before_json, after_json, request_id
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """,
        (
            admin["id"],
            admin["rol"],
            action,
            entity_type,
            str(entity_id),
            validated_client_ip(request),
            normalized_reason,
            encode(before),
            encode(after),
            request.headers.get("X-Request-ID", str(uuid.uuid4()))[:128],
        ),
    )


def append_order_event(
    cursor,
    order_id,
    previous_status,
    new_status,
    actor_type,
    actor_id=None,
    reason="",
):
    cursor.execute(
        """
        INSERT INTO eventos_pedido (
            id_pedido, estado_anterior, estado_nuevo, actor_type,
            actor_id, motivo, duracion_etapa_segundos
        )
        SELECT ?, ?, ?, ?, ?, ?,
            CASE WHEN MAX(fecha) IS NULL THEN NULL
                 ELSE MAX(0, CAST((julianday('now') - julianday(MAX(fecha))) * 86400 AS INTEGER))
            END
        FROM eventos_pedido WHERE id_pedido = ?
        """,
        (
            order_id,
            previous_status,
            new_status,
            actor_type,
            str(actor_id) if actor_id is not None else None,
            reason.strip(),
            order_id,
        ),
    )


@router.get("/api/admin/auth/me", dependencies=[Depends(require_admin)])
def admin_me(request: Request):
    return {"admin": request.state.admin}


@router.post("/api/admin/auth/logout", dependencies=[Depends(require_admin)])
def admin_logout(request: Request):
    with _connection() as connection:
        connection.execute(
            "UPDATE admin_sessions SET revoked_at = ? WHERE jti = ? AND revoked_at IS NULL",
            (int(time.time()), request.state.admin["jti"]),
        )
    return {"status": "ok"}


def bootstrap_admin(identifier, password):
    ensure_admin_schema()
    salt = secrets.token_bytes(32)
    password_hash = hashlib.pbkdf2_hmac(
        "sha256", password.encode("utf-8"), salt, PASSWORD_ITERATIONS
    ).hex()
    with _connection() as connection:
        cursor = connection.cursor()
        cursor.execute("BEGIN IMMEDIATE")
        if cursor.execute("SELECT COUNT(*) FROM admin_users").fetchone()[0]:
            raise RuntimeError(
                "Ya existe un administrador. El bootstrap inicial solo puede usarse una vez."
            )
        cursor.execute(
            """
            INSERT INTO admin_users (
                identificador, password_hash, password_salt, rol
            ) VALUES (?, ?, ?, 'superadmin')
            """,
            (identifier.strip(), password_hash, salt.hex()),
        )
        admin_id = cursor.lastrowid
        cursor.execute(
            """
            INSERT INTO auditoria_admin (
                actor_id, actor_role, action, entity_type, entity_id,
                client_ip, reason, before_json, after_json, request_id
            ) VALUES (?, 'superadmin', 'bootstrap_superadmin', 'admin_user', ?,
                      'local-console', 'Alta inicial local de la cuenta propietaria',
                      NULL, ?, ?)
            """,
            (
                admin_id,
                str(admin_id),
                json.dumps(
                    {"identificador": identifier.strip(), "rol": "superadmin"},
                    ensure_ascii=False,
                    sort_keys=True,
                ),
                f"bootstrap-{uuid.uuid4()}",
            ),
        )
        return admin_id


def utc_timestamp():
    return datetime.now(timezone.utc).isoformat(timespec="seconds")
