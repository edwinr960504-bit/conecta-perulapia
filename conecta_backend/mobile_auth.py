import base64
import hashlib
import hmac
import json
import os
import secrets
import sqlite3
import time
import re
from datetime import datetime, timezone
from contextlib import contextmanager

from fastapi import APIRouter, Depends, HTTPException, Request


DB_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "conecta_local.db")
PASSWORD_ITERATIONS = 310_000
TOKEN_LIFETIME_SECONDS = 12 * 60 * 60
GPS_STALE_AFTER_SECONDS = 300
router = APIRouter()


@contextmanager
def _connection():
    connection = sqlite3.connect(DB_PATH, timeout=15)
    try:
        yield connection
        connection.commit()
    except Exception:
        connection.rollback()
        raise
    finally:
        connection.close()


def ensure_mobile_schema():
    with _connection() as connection:
        additions = {
            "usuarios": (
                ("password_hash", "TEXT"),
                ("password_salt", "TEXT"),
                ("latitud_actual", "REAL"),
                ("longitud_actual", "REAL"),
                ("gps_actualizado_en", "TEXT"),
            ),
            "comercios": (
                ("password_hash", "TEXT"),
                ("password_salt", "TEXT"),
            ),
            "pedidos": (
                ("gps_repartidor_en", "TEXT"),
                ("gps_cliente_en", "TEXT"),
            ),
        }
        for table, columns_to_add in additions.items():
            columns = {
                row[1]
                for row in connection.execute(f"PRAGMA table_info({table})")
            }
            if not columns:
                continue
            for column, definition in columns_to_add:
                if column not in columns:
                    connection.execute(
                        f"ALTER TABLE {table} ADD COLUMN {column} {definition}"
                    )
        connection.execute(
            """
            CREATE TABLE IF NOT EXISTS mobile_sessions (
                jti TEXT PRIMARY KEY,
                subject_id INTEGER NOT NULL,
                role TEXT NOT NULL,
                issued_at INTEGER NOT NULL,
                expires_at INTEGER NOT NULL,
                revoked_at INTEGER
            )
            """
        )
        connection.execute(
            "CREATE INDEX IF NOT EXISTS ix_mobile_sessions_subject "
            "ON mobile_sessions(subject_id, role, expires_at)"
        )


def _secret():
    secret = os.environ.get("MOBILE_JWT_SECRET", "")
    if len(secret.encode("utf-8")) < 32:
        raise HTTPException(
            status_code=503,
            detail=(
                "La autenticación móvil no está configurada. "
                "Defina MOBILE_JWT_SECRET con al menos 32 bytes."
            ),
        )
    return secret.encode("utf-8")


def hash_password(password):
    salt = secrets.token_bytes(32)
    digest = hashlib.pbkdf2_hmac(
        "sha256", password.encode("utf-8"), salt, PASSWORD_ITERATIONS
    )
    return digest.hex(), salt.hex()


def verify_and_upgrade_password(cursor, table, entity_id, password, stored, digest, salt):
    if digest and salt:
        actual = hashlib.pbkdf2_hmac(
            "sha256", password.encode("utf-8"), bytes.fromhex(salt), PASSWORD_ITERATIONS
        ).hex()
        return hmac.compare_digest(actual, digest)
    if stored is None or not hmac.compare_digest(str(stored), password):
        return False
    password_hash, password_salt = hash_password(password)
    cursor.execute(
        f"UPDATE {table} SET password_hash = ?, password_salt = ?, contrasena = '' "
        f"WHERE id_{'usuario' if table == 'usuarios' else 'comercio'} = ?",
        (password_hash, password_salt, entity_id),
    )
    return True


def _b64url(value):
    return base64.urlsafe_b64encode(value).rstrip(b"=").decode("ascii")


def issue_mobile_token(subject_id, role):
    ensure_mobile_schema()
    issued_at = int(time.time())
    expires_at = issued_at + TOKEN_LIFETIME_SECONDS
    token_id = secrets.token_urlsafe(24)
    claims = {
        "sub": str(subject_id),
        "role": role,
        "iat": issued_at,
        "exp": expires_at,
        "iss": "elielexpress-mobile",
        "jti": token_id,
    }
    header = _b64url(b'{"alg":"HS256","typ":"JWT"}')
    payload = _b64url(json.dumps(claims, separators=(",", ":")).encode("utf-8"))
    signing_input = f"{header}.{payload}".encode("ascii")
    signature = hmac.new(_secret(), signing_input, hashlib.sha256).digest()
    with _connection() as connection:
        connection.execute(
            """
            INSERT INTO mobile_sessions
                (jti, subject_id, role, issued_at, expires_at)
            VALUES (?, ?, ?, ?, ?)
            """,
            (token_id, subject_id, role, issued_at, expires_at),
        )
    return f"{header}.{payload}.{_b64url(signature)}"


def revoke_mobile_session(token_id):
    with _connection() as connection:
        connection.execute(
            "UPDATE mobile_sessions SET revoked_at = ? "
            "WHERE jti = ? AND revoked_at IS NULL",
            (int(time.time()), token_id),
        )


def gps_age_seconds(timestamp):
    if not timestamp:
        return None
    try:
        value = datetime.fromisoformat(timestamp.replace("Z", "+00:00"))
        if value.tzinfo is None:
            value = value.replace(tzinfo=timezone.utc)
        return max(0, int((datetime.now(timezone.utc) - value).total_seconds()))
    except (TypeError, ValueError):
        return None


def verify_mobile_token(token):
    try:
        header, payload, signature = token.split(".")
        signing_input = f"{header}.{payload}".encode("ascii")
        expected = hmac.new(_secret(), signing_input, hashlib.sha256).digest()
        actual = base64.urlsafe_b64decode(
            signature + "=" * (-len(signature) % 4)
        )
        if not hmac.compare_digest(expected, actual):
            raise ValueError("invalid signature")
        claims = json.loads(
            base64.urlsafe_b64decode(payload + "=" * (-len(payload) % 4))
        )
        subject_id = int(claims["sub"])
        expires_at = int(claims["exp"])
        role = claims["role"]
        now = int(time.time())
        if (
            claims.get("iss") != "elielexpress-mobile"
            or role not in {"cliente", "repartidor", "comercio"}
            or expires_at <= now
            or int(claims.get("iat", 0)) > now
        ):
            raise ValueError("invalid claims")
        table = "comercios" if role == "comercio" else "usuarios"
        id_column = "id_comercio" if role == "comercio" else "id_usuario"
        with _connection() as connection:
            row = connection.execute(
                f"SELECT estado FROM {table} WHERE {id_column} = ?",
                (subject_id,),
            ).fetchone()
            session = connection.execute(
                """
                SELECT 1 FROM mobile_sessions
                WHERE jti = ? AND subject_id = ? AND role = ?
                  AND revoked_at IS NULL AND expires_at > ?
                """,
                (claims["jti"], subject_id, role, now),
            ).fetchone()
        if not row or str(row[0]).lower() != "activo" or not session:
            raise ValueError("inactive session or account")
        return {"id": subject_id, "role": role, "jti": claims["jti"]}
    except HTTPException:
        raise
    except Exception as error:
        raise HTTPException(
            status_code=401,
            detail="La sesión móvil no es válida o venció.",
            headers={"WWW-Authenticate": "Bearer"},
        ) from error


async def require_mobile_user(request: Request):
    authorization = request.headers.get("Authorization", "")
    scheme, _, token = authorization.partition(" ")
    if scheme.lower() != "bearer" or not token:
        raise HTTPException(
            status_code=401,
            detail="Se requiere una sesión móvil.",
            headers={"WWW-Authenticate": "Bearer"},
        )
    user = verify_mobile_token(token)
    request.state.mobile_user = user
    return user


@router.get("/api/mobile/auth/me")
async def mobile_me(user=Depends(require_mobile_user)):
    return {"status": "ok", "user": user}


@router.post("/api/mobile/auth/logout")
async def mobile_logout(user=Depends(require_mobile_user)):
    revoke_mobile_session(user["jti"])
    return {"status": "ok"}


def require_role(request: Request, *roles):
    user = getattr(request.state, "mobile_user", None)
    if not user or user["role"] not in roles:
        raise HTTPException(status_code=403, detail="La operación no está permitida para este rol.")
    return user


def require_order_owner(request: Request, order_id, *roles):
    user = require_role(request, *roles)
    try:
        order_id = int(order_id)
    except (TypeError, ValueError) as error:
        raise HTTPException(status_code=422, detail="El identificador de pedido no es válido.") from error
    owner_columns = {
        "cliente": ("id_cliente",),
        "comercio": ("id_comercio",),
        "repartidor": ("id_repartidor",),
    }
    with _connection() as connection:
        row = connection.execute(
            "SELECT id_cliente, id_comercio, id_repartidor FROM pedidos WHERE id_pedido = ?",
            (order_id,),
        ).fetchone()
    if not row:
        raise HTTPException(status_code=404, detail="Pedido no encontrado.")
    indexes = {"id_cliente": 0, "id_comercio": 1, "id_repartidor": 2}
    if not any(
        row[indexes[column]] == user["id"]
        for role in roles
        for column in owner_columns[role]
    ):
        raise HTTPException(status_code=403, detail="El pedido no pertenece a esta cuenta.")
    return user


def require_actor_id(request: Request, actor_id, *roles):
    user = require_role(request, *roles)
    try:
        actor_id = int(actor_id)
    except (TypeError, ValueError) as error:
        raise HTTPException(status_code=422, detail="El identificador no es válido.") from error
    if actor_id != user["id"]:
        raise HTTPException(status_code=403, detail="La cuenta no puede acceder a este recurso.")
    return user


def require_product_owner(request: Request, product_id, *roles):
    user = require_role(request, *roles)
    try:
        product_id = int(product_id)
    except (TypeError, ValueError) as error:
        raise HTTPException(status_code=422, detail="El identificador del producto no es válido.") from error
    with _connection() as connection:
        row = connection.execute(
            "SELECT id_comercio FROM productos WHERE id_producto = ?",
            (product_id,),
        ).fetchone()
    if not row:
        raise HTTPException(status_code=404, detail="Producto no encontrado.")
    if user["role"] == "comercio" and row[0] != user["id"]:
        raise HTTPException(status_code=403, detail="El producto no pertenece a este comercio.")
    return user


def authorize_path_resource(request, user):
    path = request.url.path.rstrip("/")
    role_patterns = (
        (r"/(?:api/)?crear_pedido", {"cliente"}),
        (r"/(?:api/)?pedidos_disponibles", {"repartidor"}),
        (r"/(?:api/)?tomar_pedido", {"repartidor"}),
        (r"/api/repartidor/(?:notificar_llegada|borrar_movimiento)", {"repartidor"}),
        (r"/api/motorista/actualizar_gps_vivo", {"repartidor"}),
        (r"/(?:api/)?(?:recoger_pedido|entregar_pedido|actualizar_gps)", {"repartidor"}),
        (r"/api/actualizar_gps_cliente", {"cliente"}),
        (r"/(?:api/)?(?:comercio_acepta|comercio_pedido_listo)", {"comercio"}),
        (r"/api/comercio/(?:actualizar_perfil|estado/\d+)", {"comercio"}),
        (r"/(?:api/)?(?:agregar_producto|registrar_producto|actualizar_producto|eliminar_producto)", {"comercio"}),
        (r"/api/(?:subir_foto_comercio|subir_foto_producto)", {"comercio"}),
        (r"/api/(?:enviar_soporte|chat/enviar_mensaje|chat/subir_evidencia)", {"cliente", "comercio", "repartidor"}),
        (r"/api/cliente/(?:notificaciones_chat|validar_soporte/[^/]+)", {"cliente"}),
        (r"/api/chat/(?:borrar_mensaje/\d+|borrar_todo/-?\d+)", {"cliente", "comercio", "repartidor"}),
        (r"/api/(?:actualizar_contacto|subir_foto_cliente)", {"cliente", "repartidor"}),
    )
    for pattern, allowed_roles in role_patterns:
        if re.fullmatch(pattern, path) and user["role"] not in allowed_roles:
            raise HTTPException(status_code=403, detail="La operación no está permitida para este rol.")
    actor_patterns = (
        (r"/(?:api/)?perfil/(\d+)", {"cliente", "repartidor"}),
        (r"/api/comercio/perfil/(\d+)", {"comercio"}),
        (r"/(?:api/)?pedidos_comercio/(\d+)", {"comercio"}),
        (r"/(?:api/)?viaje_activo/repartidor/(\d+)", {"repartidor"}),
        (r"/(?:api/)?repartidor/billetera/(\d+)", {"repartidor"}),
        (r"/(?:api/)?repartidor/limpiar_todo/(\d+)", {"repartidor"}),
        (r"/api/cliente/mis_tickets/(\d+)", {"cliente"}),
        (r"/api/cliente/chat_activo/(\d+)", {"cliente"}),
        (r"/api/pedidos_activos/cliente/(\d+)", {"cliente"}),
        (r"/api/historial_cliente/(\d+)", {"cliente"}),
        (r"/(?:api/)?cliente/limpiar_todo/(\d+)", {"cliente"}),
        (r"/api/comercio/estado/(\d+)", {"comercio"}),
        (r"/(?:api/)?billetera/comercio/(\d+)", {"comercio"}),
    )
    for pattern, allowed_roles in actor_patterns:
        match = re.fullmatch(pattern, path)
        if match:
            require_actor_id(request, match.group(1), user["role"])
            if user["role"] not in allowed_roles:
                raise HTTPException(status_code=403, detail="La operación no está permitida para este rol.")
            return

    path_actor_patterns = (
        (r"/api/repartidor/validar_soporte/(\d+)/[^/]+", "repartidor"),
        (r"/api/comercio/validar_soporte/(\d+)/[^/]+", "comercio"),
    )
    for pattern, role in path_actor_patterns:
        match = re.fullmatch(pattern, path)
        if match:
            require_actor_id(request, match.group(1), role)
            return

    if re.fullmatch(r"/api/cliente/validar_soporte/[^/]+", path):
        require_role(request, "cliente")

    order_match = re.fullmatch(
        r"/api/(?:chat/(?:historial|codigo_por_pedido)|obtener_gps|obtener_gps_pedido)/(-?\d+)",
        path,
    )
    if order_match:
        order_id = order_match.group(1)
        if int(order_id) < 0:
            require_actor_id(request, -int(order_id), user["role"])
        else:
            require_order_owner(request, order_id, user["role"])
