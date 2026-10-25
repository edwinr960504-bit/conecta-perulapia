# Repartidores propios de un comercio (Plan A) y lanzamiento al radar general (Plan B).
import os
import secrets
import sqlite3
import string

from fastapi import APIRouter, Request
from pydantic import BaseModel

import mobile_auth

router = APIRouter()
DB_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "conecta_local.db")
ESTADOS_OCUPADO = ("asignado", "en_camino")


class RepartidorPropioNuevo(BaseModel):
    id_comercio: int
    nombre: str
    telefono: str
    correo: str = ""


class QuitarRepartidorPropio(BaseModel):
    id_comercio: int
    id_repartidor: int


class AsignarRepartidor(BaseModel):
    id_pedido: int
    id_repartidor: int


class LanzarRadar(BaseModel):
    id_pedido: int


def _conectar():
    mobile_auth.ensure_mobile_schema()
    return sqlite3.connect(DB_PATH, timeout=15)


def comercio_tiene_flota(cursor, id_comercio):
    cursor.execute(
        "SELECT 1 FROM usuarios WHERE id_comercio_propio = ? AND rol = 'repartidor' "
        "AND estado = 'activo' LIMIT 1",
        (id_comercio,),
    )
    return cursor.fetchone() is not None


def repartidor_puede_tomar(cursor, id_repartidor, id_pedido):
    """Devuelve (permitido, mensaje) según la propiedad del repartidor y el despacho del pedido."""
    cursor.execute("SELECT id_comercio_propio FROM usuarios WHERE id_usuario = ?", (id_repartidor,))
    fila = cursor.fetchone()
    comercio_propio = fila[0] if fila else None
    cursor.execute(
        "SELECT id_comercio, COALESCE(despacho_externo, 0) FROM pedidos WHERE id_pedido = ?",
        (id_pedido,),
    )
    pedido = cursor.fetchone()
    if not pedido:
        return False, "Pedido no encontrado."
    if comercio_propio:
        if pedido[0] != comercio_propio:
            return False, "Este pedido no pertenece a tu local."
        return True, ""
    if not pedido[1] and comercio_tiene_flota(cursor, pedido[0]):
        return False, "Este pedido lo atiende la flota propia del local."
    return True, ""


@router.get("/api/comercio/repartidores_propios/{id_comercio}")
def listar_repartidores_propios(id_comercio: int):
    conexion = _conectar()
    cursor = conexion.cursor()
    cursor.execute(
        """
        SELECT u.id_usuario, u.nombre, u.telefono, COALESCE(u.correo, ''),
               EXISTS(SELECT 1 FROM pedidos p WHERE p.id_repartidor = u.id_usuario
                      AND p.estado IN ('asignado', 'en_camino'))
        FROM usuarios u
        WHERE u.id_comercio_propio = ? AND u.rol = 'repartidor' AND u.estado = 'activo'
        ORDER BY u.nombre
        """,
        (id_comercio,),
    )
    filas = cursor.fetchall()
    conexion.close()
    return {
        "status": "ok",
        "repartidores": [
            {"id_repartidor": f[0], "nombre": f[1], "telefono": f[2], "correo": f[3], "ocupado": bool(f[4])}
            for f in filas
        ],
    }


@router.post("/api/comercio/repartidores_propios")
def crear_repartidor_propio(datos: RepartidorPropioNuevo, request: Request):
    mobile_auth.require_actor_id(request, datos.id_comercio, "comercio")
    nombre = datos.nombre.strip()
    telefono = datos.telefono.strip()
    correo = datos.correo.strip().lower()
    if len(nombre) < 3 or len(telefono) < 8:
        return {"status": "error", "mensaje": "Escribe el nombre y un teléfono válido."}

    conexion = _conectar()
    cursor = conexion.cursor()
    cursor.execute(
        "SELECT 1 FROM usuarios WHERE telefono = ? OR (? != '' AND LOWER(correo) = ?)",
        (telefono, correo, correo),
    )
    ocupado = cursor.fetchone()
    if not ocupado:
        cursor.execute(
            "SELECT 1 FROM comercios WHERE telefono = ? OR (? != '' AND LOWER(correo) = ?)",
            (telefono, correo, correo),
        )
        ocupado = cursor.fetchone()
    if ocupado:
        conexion.close()
        return {"status": "error", "mensaje": "Ese teléfono o correo ya está registrado."}

    alfabeto = string.ascii_uppercase + string.digits
    contrasena = "".join(secrets.choice(alfabeto) for _ in range(8))
    password_hash, password_salt = mobile_auth.hash_password(contrasena)
    cursor.execute(
        """
        INSERT INTO usuarios (nombre, telefono, correo, contrasena, rol, dui, direccion,
                              estado, password_hash, password_salt, id_comercio_propio)
        VALUES (?, ?, ?, '', 'repartidor', ?, 'Repartidor del local', 'activo', ?, ?, ?)
        """,
        (nombre, telefono, correo, f"PROPIO-{secrets.token_hex(4)}",
         password_hash, password_salt, datos.id_comercio),
    )
    id_nuevo = cursor.lastrowid
    conexion.commit()
    conexion.close()
    return {
        "status": "ok",
        "id_repartidor": id_nuevo,
        "usuario": telefono,
        "contrasena": contrasena,
        "mensaje": "Repartidor registrado. Entrégale estas credenciales; no se volverán a mostrar.",
    }


@router.post("/api/comercio/repartidores_propios/quitar")
def quitar_repartidor_propio(datos: QuitarRepartidorPropio, request: Request):
    mobile_auth.require_actor_id(request, datos.id_comercio, "comercio")
    conexion = _conectar()
    cursor = conexion.cursor()
    cursor.execute(
        "SELECT 1 FROM usuarios WHERE id_usuario = ? AND id_comercio_propio = ?",
        (datos.id_repartidor, datos.id_comercio),
    )
    if not cursor.fetchone():
        conexion.close()
        return {"status": "error", "mensaje": "Ese repartidor no pertenece a tu local."}
    cursor.execute(
        "SELECT 1 FROM pedidos WHERE id_repartidor = ? AND estado IN ('asignado', 'en_camino')",
        (datos.id_repartidor,),
    )
    if cursor.fetchone():
        conexion.close()
        return {"status": "error", "mensaje": "Tiene un pedido en curso; no se puede quitar todavía."}
    cursor.execute("UPDATE usuarios SET estado = 'suspendido' WHERE id_usuario = ?", (datos.id_repartidor,))
    cursor.execute(
        "UPDATE mobile_sessions SET revoked_at = strftime('%s','now') "
        "WHERE subject_id = ? AND role = 'repartidor' AND revoked_at IS NULL",
        (datos.id_repartidor,),
    )
    conexion.commit()
    conexion.close()
    return {"status": "ok", "mensaje": "Repartidor quitado de tu flota."}


@router.post("/api/comercio/asignar_repartidor")
def asignar_repartidor_propio(datos: AsignarRepartidor, request: Request):
    user = mobile_auth.require_order_owner(request, datos.id_pedido, "comercio")
    conexion = _conectar()
    cursor = conexion.cursor()
    cursor.execute(
        "SELECT 1 FROM usuarios WHERE id_usuario = ? AND id_comercio_propio = ? "
        "AND rol = 'repartidor' AND estado = 'activo'",
        (datos.id_repartidor, user["id"]),
    )
    if not cursor.fetchone():
        conexion.close()
        return {"status": "error", "mensaje": "Ese repartidor no pertenece a tu local."}
    cursor.execute(
        "SELECT 1 FROM pedidos WHERE id_repartidor = ? AND estado IN ('asignado', 'en_camino')",
        (datos.id_repartidor,),
    )
    if cursor.fetchone():
        conexion.close()
        return {"status": "error", "mensaje": "Ese repartidor ya está en un viaje."}
    cursor.execute(
        """
        UPDATE pedidos SET estado = 'asignado', id_repartidor = ?
        WHERE id_pedido = ? AND estado IN ('preparacion', 'listo_recoleccion')
          AND (id_repartidor IS NULL OR id_repartidor = 0)
        """,
        (datos.id_repartidor, datos.id_pedido),
    )
    if cursor.rowcount == 0:
        conexion.rollback()
        conexion.close()
        return {"status": "error", "mensaje": "El pedido ya tiene repartidor o aún no está aceptado."}
    conexion.commit()
    conexion.close()
    return {"status": "ok", "mensaje": "Pedido asignado a tu repartidor."}


@router.post("/api/comercio/lanzar_radar")
def lanzar_pedido_al_radar(datos: LanzarRadar, request: Request):
    mobile_auth.require_order_owner(request, datos.id_pedido, "comercio")
    conexion = _conectar()
    cursor = conexion.cursor()
    cursor.execute(
        """
        UPDATE pedidos SET despacho_externo = 1
        WHERE id_pedido = ? AND (id_repartidor IS NULL OR id_repartidor = 0)
          AND estado IN ('pendiente', 'preparacion', 'listo_recoleccion')
        """,
        (datos.id_pedido,),
    )
    if cursor.rowcount == 0:
        conexion.rollback()
        conexion.close()
        return {"status": "error", "mensaje": "El pedido ya tiene repartidor o no está activo."}
    conexion.commit()
    conexion.close()
    return {"status": "ok", "mensaje": "Pedido publicado en el radar de repartidores."}
