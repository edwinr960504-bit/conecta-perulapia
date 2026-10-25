import asyncio
import os
import sqlite3
import sys
import tempfile
import unittest
from contextlib import closing
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import admin_core
from fastapi import HTTPException
from starlette.requests import Request


class AdminCoreTests(unittest.TestCase):
    def setUp(self):
        self.temp_dir = tempfile.TemporaryDirectory(prefix="admin-core-tests-")
        self.old_db_path = admin_core.DB_PATH
        self.old_secret = os.environ.get("ADMIN_JWT_SECRET")
        admin_core.DB_PATH = str(Path(self.temp_dir.name) / "admin-test.db")
        os.environ["ADMIN_JWT_SECRET"] = "test-signing-secret-that-is-at-least-32-bytes"
        self._create_legacy_database()
        admin_core.ensure_admin_schema()

    def tearDown(self):
        admin_core.DB_PATH = self.old_db_path
        if self.old_secret is None:
            os.environ.pop("ADMIN_JWT_SECRET", None)
        else:
            os.environ["ADMIN_JWT_SECRET"] = self.old_secret
        self.temp_dir.cleanup()

    def _create_legacy_database(self):
        with closing(sqlite3.connect(admin_core.DB_PATH)) as connection, connection:
            connection.executescript(
                """
                CREATE TABLE auditoria_admin (
                    id_log INTEGER PRIMARY KEY AUTOINCREMENT,
                    accion TEXT,
                    fecha TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                );
                INSERT INTO auditoria_admin (accion) VALUES ('legacy action');
                CREATE TABLE mensajes_chat (
                    id_mensaje INTEGER PRIMARY KEY,
                    mensaje TEXT
                );
                CREATE TABLE soporte (
                    id_soporte INTEGER PRIMARY KEY,
                    estado TEXT
                );
                CREATE TABLE anuncios_globales (
                    id INTEGER PRIMARY KEY,
                    mensaje TEXT,
                    imagen_url TEXT
                );
                CREATE TABLE comercios (
                    id_comercio INTEGER PRIMARY KEY,
                    estado TEXT
                );
                CREATE TABLE usuarios (
                    id_usuario INTEGER PRIMARY KEY,
                    rol TEXT,
                    estado TEXT
                );
                CREATE TABLE pedidos (
                    id_pedido INTEGER PRIMARY KEY,
                    estado TEXT
                );
                INSERT INTO comercios VALUES (1, 'pendiente');
                INSERT INTO pedidos VALUES (1, 'pendiente');
                """
            )

    @staticmethod
    def _request(headers=()):
        return Request(
            {
                "type": "http",
                "asgi": {"version": "3.0"},
                "http_version": "1.1",
                "method": "POST",
                "scheme": "http",
                "path": "/",
                "raw_path": b"/",
                "query_string": b"",
                "headers": list(headers),
                "client": ("127.0.0.1", 54321),
                "server": ("test", 80),
            }
        )

    def test_bootstrap_is_one_time_and_issues_revocable_signed_tokens(self):
        admin_id = admin_core.bootstrap_admin(
            "owner@example.test", "sufficient-local-passphrase"
        )
        self.assertEqual(admin_id, 1)
        with self.assertRaises(RuntimeError):
            admin_core.bootstrap_admin(
                "second@example.test", "another-sufficient-passphrase"
            )

        login = admin_core.admin_login(
            admin_core.AdminLogin(
                identificador="owner@example.test",
                contrasena="sufficient-local-passphrase",
            ),
            self._request(),
        )
        authorization = [
            (b"authorization", f"Bearer {login['access_token']}".encode())
        ]
        request = self._request(authorization)
        admin = asyncio.run(admin_core.require_admin(request))
        self.assertEqual(admin["rol"], "superadmin")

        header, payload, signature = login["access_token"].split(".")
        tampered_signature = ("A" if signature[0] != "A" else "B") + signature[1:]
        with self.assertRaises(HTTPException) as invalid:
            admin_core._verify_token(f"{header}.{payload}.{tampered_signature}")
        self.assertEqual(invalid.exception.status_code, 401)

        admin_core.admin_logout(request)
        with self.assertRaises(HTTPException) as revoked:
            admin_core._verify_token(login["access_token"])
        self.assertEqual(revoked.exception.status_code, 401)

    def test_admin_radar_returns_delivery_destination_separately_from_rider_gps(self):
        import tuberias_admin

        old_module_db = tuberias_admin.DB_PATH
        tuberias_admin.DB_PATH = admin_core.DB_PATH
        self.addCleanup(setattr, tuberias_admin, "DB_PATH", old_module_db)

        with closing(sqlite3.connect(admin_core.DB_PATH)) as connection, connection:
            connection.executescript(
                """
                ALTER TABLE comercios ADD COLUMN nombre_local TEXT;
                ALTER TABLE pedidos ADD COLUMN descripcion TEXT;
                ALTER TABLE pedidos ADD COLUMN total_pago REAL;
                ALTER TABLE pedidos ADD COLUMN distancia_km REAL;
                ALTER TABLE pedidos ADD COLUMN id_comercio INTEGER;
                ALTER TABLE pedidos ADD COLUMN id_repartidor INTEGER;
                ALTER TABLE pedidos ADD COLUMN latitud_repartidor REAL;
                ALTER TABLE pedidos ADD COLUMN longitud_repartidor REAL;
                ALTER TABLE pedidos ADD COLUMN latitud_cliente REAL;
                ALTER TABLE pedidos ADD COLUMN longitud_cliente REAL;
                ALTER TABLE usuarios ADD COLUMN nombre TEXT;
                UPDATE comercios
                SET estado = 'activo', nombre_local = 'Local de prueba'
                WHERE id_comercio = 1;
                INSERT INTO pedidos (
                    id_pedido, estado, id_comercio, id_repartidor,
                    latitud_repartidor, longitud_repartidor,
                    latitud_cliente, longitud_cliente
                ) VALUES (5, 'en_camino', 1, NULL, 13.70, -89.10, 13.71, -89.11);
                """
            )

        order = tuberias_admin.radar_despacho()[0]
        self.assertEqual((order["lat"], order["lon"]), (13.70, -89.10))
        self.assertEqual(
            (order["lat_cliente"], order["lon_cliente"]),
            (13.71, -89.11),
        )

    def test_operational_metrics_count_active_and_inactive_entities(self):
        import tuberias_admin

        old_module_db = tuberias_admin.DB_PATH
        tuberias_admin.DB_PATH = admin_core.DB_PATH
        self.addCleanup(setattr, tuberias_admin, "DB_PATH", old_module_db)

        with closing(sqlite3.connect(admin_core.DB_PATH)) as connection, connection:
            connection.execute(
                "INSERT INTO usuarios (id_usuario, rol, estado) "
                "VALUES (20, 'repartidor', 'activo'), (21, 'motorista', 'inactivo')"
            )
            connection.execute(
                "INSERT INTO comercios (id_comercio, estado) VALUES (20, 'activo')"
            )
            connection.execute(
                "UPDATE pedidos SET estado='pendiente' WHERE id_pedido=1"
            )

        metrics = tuberias_admin.metricas_operativas()
        self.assertEqual(metrics["pedidos"]["total"], 1)
        self.assertEqual(metrics["pedidos"]["activos"], 1)
        self.assertEqual(metrics["pedidos"]["pendientes"], 1)
        self.assertEqual(metrics["repartidores"]["activos"], 1)
        self.assertEqual(metrics["repartidores"]["inactivos"], 1)
        self.assertEqual(metrics["comercios"]["activos"], 1)
        self.assertEqual(metrics["comercios"]["inactivos"], 1)

    def test_customer_support_tickets_are_personal_or_owned_order_only(self):
        import adm_soporte

        old_module_db = adm_soporte.DB_PATH
        adm_soporte.DB_PATH = admin_core.DB_PATH
        self.addCleanup(setattr, adm_soporte, "DB_PATH", old_module_db)
        with closing(sqlite3.connect(admin_core.DB_PATH)) as connection, connection:
            connection.executescript(
                """
                ALTER TABLE pedidos ADD COLUMN id_cliente INTEGER;
                ALTER TABLE pedidos ADD COLUMN codigo_rastreo TEXT;
                ALTER TABLE pedidos ADD COLUMN id_comercio INTEGER;
                ALTER TABLE pedidos ADD COLUMN id_repartidor INTEGER;
                ALTER TABLE pedidos ADD COLUMN descripcion TEXT;
                ALTER TABLE pedidos ADD COLUMN total_pago REAL;
                ALTER TABLE pedidos ADD COLUMN distancia_km REAL;
                ALTER TABLE pedidos ADD COLUMN latitud_repartidor REAL;
                ALTER TABLE pedidos ADD COLUMN longitud_repartidor REAL;
                ALTER TABLE pedidos ADD COLUMN latitud_cliente REAL;
                ALTER TABLE pedidos ADD COLUMN longitud_cliente REAL;
                ALTER TABLE pedidos ADD COLUMN latitud_comercio REAL;
                ALTER TABLE pedidos ADD COLUMN longitud_comercio REAL;
                ALTER TABLE pedidos ADD COLUMN fecha TEXT;
                ALTER TABLE pedidos ADD COLUMN fecha_entrega TEXT;
                ALTER TABLE comercios ADD COLUMN nombre_local TEXT;
                ALTER TABLE comercios ADD COLUMN telefono TEXT;
                ALTER TABLE usuarios ADD COLUMN nombre TEXT;
                ALTER TABLE usuarios ADD COLUMN telefono TEXT;
                INSERT INTO usuarios (id_usuario, rol, estado, nombre)
                VALUES (7, 'cliente', 'activo', 'Cliente propio'),
                       (8, 'cliente', 'activo', 'Otro cliente'),
                       (9, 'repartidor', 'activo', 'Motorista prueba');
                UPDATE pedidos SET id_cliente=7, id_comercio=1,
                    id_repartidor=9, codigo_rastreo='CP-OWNED'
                WHERE id_pedido=1;
                DROP TABLE soporte;
                DROP TABLE mensajes_chat;
                CREATE TABLE soporte (
                    id_soporte INTEGER PRIMARY KEY AUTOINCREMENT,
                    id_usuario INTEGER, rol TEXT, id_pedido INTEGER,
                    mensaje TEXT, evidencia TEXT DEFAULT '',
                    estado TEXT DEFAULT 'abierto',
                    respuesta_admin TEXT DEFAULT '',
                    fecha TEXT DEFAULT CURRENT_TIMESTAMP,
                    canal TEXT NOT NULL DEFAULT 'admin_cliente',
                    archivado INTEGER DEFAULT 0
                );
                CREATE TABLE mensajes_chat (
                    id_mensaje INTEGER PRIMARY KEY AUTOINCREMENT,
                    id_pedido INTEGER, remitente TEXT, mensaje TEXT,
                    evidencia TEXT DEFAULT '', canal TEXT DEFAULT 'admin_cliente',
                    fecha TEXT DEFAULT CURRENT_TIMESTAMP, leido INTEGER DEFAULT 0,
                    archivado INTEGER DEFAULT 0
                );
                INSERT INTO soporte (id_usuario, rol, id_pedido, mensaje, canal)
                VALUES (7, 'cliente', 1, 'Pedido', 'admin_cliente'),
                       (7, 'cliente', -7, 'Consulta general', 'admin_cliente_personal'),
                       (8, 'cliente', -8, 'Caso privado', 'admin_cliente_personal');
                INSERT INTO mensajes_chat (
                    id_pedido, remitente, mensaje, canal
                ) VALUES (1, 'Cliente', 'Pedido', 'admin_cliente'),
                         (-7, 'Cliente', 'Consulta general', 'admin_cliente_personal'),
                         (-8, 'Cliente', 'Caso privado', 'admin_cliente_personal');
                """
            )

        tickets = adm_soporte.tickets_cliente(7)
        self.assertEqual(
            {ticket["id_pedido"] for ticket in tickets},
            {1, -7},
        )
        linked = adm_soporte.validar_rastreo_cliente("cp-owned", id_cliente=7)
        self.assertEqual(linked["status"], "ok")
        rejected = adm_soporte.validar_rastreo_cliente("CP-OWNED", id_cliente=8)
        self.assertEqual(rejected["status"], "error")
        commerce_linked = adm_soporte.validar_rastreo_comercio(1, "cp-owned")
        self.assertEqual(commerce_linked["status"], "ok")
        commerce_rejected = adm_soporte.validar_rastreo_comercio(2, "CP-OWNED")
        self.assertEqual(commerce_rejected["status"], "error")
        admin_tickets = adm_soporte.ver_quejas_admin()
        self.assertEqual(len(admin_tickets), 3)
        personal = next(ticket for ticket in admin_tickets if ticket["id_pedido"] == -7)
        self.assertEqual(personal["codigo_rastreo"], "Consulta personal")
        self.assertEqual(personal["canal"], "admin_cliente_personal")

    def test_admin_action_records_actor_ip_reason_and_structured_diff(self):
        from admin_core import open_database
        import tuberias_admin

        old_module_db = tuberias_admin.DB_PATH
        tuberias_admin.DB_PATH = admin_core.DB_PATH
        self.addCleanup(setattr, tuberias_admin, "DB_PATH", old_module_db)

        admin_core.bootstrap_admin(
            "owner@example.test", "sufficient-local-passphrase"
        )
        login = admin_core.admin_login(
            admin_core.AdminLogin(
                identificador="owner@example.test",
                contrasena="sufficient-local-passphrase",
            ),
            self._request(),
        )
        request = self._request(
            [(b"authorization", f"Bearer {login['access_token']}".encode())]
        )
        request.state.admin = asyncio.run(admin_core.require_admin(request))

        response = tuberias_admin.juzgar_comercio(
            tuberias_admin.DecisionJuez(
                id_objetivo=1,
                nuevo_estado="activo",
                motivo="Validación del expediente comercial",
            ),
            request,
        )
        self.assertEqual(response["status"], "ok")

        with open_database() as connection:
            record = connection.execute(
                """
                SELECT actor_id, client_ip, reason, before_json, after_json
                FROM auditoria_admin
                WHERE action = 'cambiar_estado' AND entity_type = 'comercio'
                """
            ).fetchone()
        self.assertEqual(record[0], request.state.admin["id"])
        self.assertEqual(record[1], "127.0.0.1")
        self.assertEqual(record[2], "Validación del expediente comercial")
        self.assertEqual(record[3], '{"estado":"pendiente"}')
        self.assertEqual(record[4], '{"estado":"activo"}')

    def test_audit_and_order_events_are_append_only(self):
        with admin_core.open_database() as connection:
            cursor = connection.cursor()
            cursor.execute(
                """
                INSERT INTO auditoria_admin (
                    actor_id, actor_role, action, entity_type, entity_id,
                    client_ip, reason, request_id
                ) VALUES (1, 'superadmin', 'test', 'test', '1',
                          '127.0.0.1', 'test reason', 'test-request')
                """
            )
            admin_core.append_order_event(
                cursor, 1, None, "pendiente", "cliente", 7, "Pedido creado"
            )
            admin_core.append_order_event(
                cursor, 1, "pendiente", "preparacion", "comercio", 4, "Aceptado"
            )
            events = connection.execute(
                """
                SELECT estado_anterior, estado_nuevo, duracion_etapa_segundos
                FROM eventos_pedido ORDER BY id_evento
                """
            ).fetchall()
        self.assertEqual(events[0], (None, "pendiente", None))
        self.assertEqual(events[1][:2], ("pendiente", "preparacion"))
        self.assertGreaterEqual(events[1][2], 0)

        with closing(sqlite3.connect(admin_core.DB_PATH)) as connection, connection:
            with self.assertRaises(sqlite3.IntegrityError):
                connection.execute(
                    "UPDATE auditoria_admin SET action='tampered' WHERE action='test'"
                )
            connection.rollback()
            with self.assertRaises(sqlite3.IntegrityError):
                connection.execute(
                    "DELETE FROM eventos_pedido WHERE id_pedido = 1"
                )

    def test_legacy_audit_rows_and_archive_columns_are_migrated(self):
        with admin_core.open_database() as connection:
            legacy = connection.execute(
                "SELECT action FROM auditoria_admin WHERE id_log = 1"
            ).fetchone()
            for table in ("mensajes_chat", "soporte", "anuncios_globales"):
                columns = {
                    row[1] for row in connection.execute(f"PRAGMA table_info({table})")
                }
                self.assertIn("archivado", columns)
        self.assertEqual(legacy[0], "legacy action")

    def test_audit_date_filters_include_the_full_end_date_and_reject_invalid_dates(self):
        import tuberias_admin

        old_module_db = tuberias_admin.DB_PATH
        tuberias_admin.DB_PATH = admin_core.DB_PATH
        self.addCleanup(setattr, tuberias_admin, "DB_PATH", old_module_db)
        admin_core.bootstrap_admin(
            "owner@example.test", "sufficient-local-passphrase"
        )
        with admin_core.open_database() as connection:
            audit_date = connection.execute(
                "SELECT substr(fecha, 1, 10) FROM auditoria_admin "
                "WHERE action = 'bootstrap_superadmin'"
            ).fetchone()[0]

        result = tuberias_admin.ver_auditoria(
            desde=audit_date,
            hasta=audit_date,
            actor_id=1,
            entidad="admin_user",
            accion="bootstrap_superadmin",
            offset=0,
            limit=50,
        )
        self.assertEqual(result["total"], 1)
        self.assertEqual(len(result["logs"]), 1)
        with self.assertRaises(HTTPException) as invalid_date:
            tuberias_admin.ver_auditoria(
                desde="not-a-date",
                hasta=None,
                actor_id=None,
                entidad=None,
                accion=None,
                offset=0,
                limit=50,
            )
        self.assertEqual(invalid_date.exception.status_code, 422)

    def test_admin_order_history_and_recent_order_events_are_paged(self):
        import tuberias_admin

        self.assertTrue(
            any(
                dependency.dependency is admin_core.require_admin
                for dependency in tuberias_admin.router.dependencies
            )
        )
        old_module_db = tuberias_admin.DB_PATH
        tuberias_admin.DB_PATH = admin_core.DB_PATH
        self.addCleanup(setattr, tuberias_admin, "DB_PATH", old_module_db)
        with admin_core.open_database() as connection:
            for column, definition in (
                ("descripcion", "TEXT"),
                ("fecha", "TEXT"),
                ("fecha_entrega", "TEXT"),
                ("total_pago", "REAL"),
                ("comision_app", "REAL"),
                ("tarifa_envio", "REAL"),
                ("metodo_pago", "TEXT"),
                ("codigo_rastreo", "TEXT"),
                ("id_repartidor", "INTEGER"),
                ("id_comercio", "INTEGER"),
                ("id_cliente", "INTEGER"),
            ):
                connection.execute(
                    f"ALTER TABLE pedidos ADD COLUMN {column} {definition}"
                )
            connection.execute("ALTER TABLE comercios ADD COLUMN nombre_local TEXT")
            connection.execute("ALTER TABLE usuarios ADD COLUMN nombre TEXT")
            connection.execute(
                "INSERT INTO usuarios (id_usuario, rol, estado, nombre) "
                "VALUES (2, 'cliente', 'activo', 'Cliente de prueba')"
            )
            connection.execute(
                "UPDATE comercios SET nombre_local = 'Comercio de prueba' "
                "WHERE id_comercio = 1"
            )
            connection.execute(
                """
                UPDATE pedidos SET
                    estado='entregado', descripcion='Pedido de prueba',
                    fecha='2026-10-17 10:00:00',
                    fecha_entrega='2026-10-17 10:30:00',
                    total_pago=10.5, comision_app=1.0, tarifa_envio=1.5,
                    metodo_pago='efectivo', codigo_rastreo='CP-12345',
                    id_repartidor=3, id_comercio=1, id_cliente=2
                WHERE id_pedido=1
                """
            )
            cursor = connection.cursor()
            admin_core.append_order_event(
                cursor, 1, None, "pendiente", "cliente", 2, "Pedido creado"
            )
            admin_core.append_order_event(
                cursor, 1, "pendiente", "entregado", "repartidor", 3, "Entregado"
            )

        history = tuberias_admin.pedidos_historial_admin(
            estado="historial",
            desde="2026-10-17",
            hasta="2026-10-17",
            offset=0,
            limit=10,
        )
        self.assertEqual(history["total"], 1)
        self.assertEqual(history["pedidos"][0]["comercio"], "Comercio de prueba")
        self.assertEqual(history["pedidos"][0]["metodo_pago"], "efectivo")

        events = tuberias_admin.eventos_pedido_admin(offset=0, limit=1)
        self.assertEqual(events["total"], 2)
        self.assertEqual(events["eventos"][0]["estado_nuevo"], "entregado")

        with self.assertRaises(HTTPException) as invalid_state:
            tuberias_admin.pedidos_historial_admin(
                estado="inexistente",
                desde=None,
                hasta=None,
                offset=0,
                limit=10,
            )
        self.assertEqual(invalid_state.exception.status_code, 422)

    def test_superadmin_support_reply_is_audited_and_archived_threads_are_read_only(self):
        import adm_soporte

        old_module_db = adm_soporte.DB_PATH
        adm_soporte.DB_PATH = admin_core.DB_PATH
        self.addCleanup(setattr, adm_soporte, "DB_PATH", old_module_db)
        with admin_core.open_database() as connection:
            connection.executescript(
                """
                DROP TABLE mensajes_chat;
                DROP TABLE soporte;
                CREATE TABLE mensajes_chat (
                    id_mensaje INTEGER PRIMARY KEY AUTOINCREMENT,
                    id_pedido INTEGER,
                    remitente TEXT,
                    mensaje TEXT,
                    evidencia TEXT DEFAULT '',
                    canal TEXT DEFAULT 'admin_cliente',
                    fecha TEXT DEFAULT CURRENT_TIMESTAMP,
                    leido INTEGER DEFAULT 0
                );
                CREATE TABLE soporte (
                    id_soporte INTEGER PRIMARY KEY AUTOINCREMENT,
                    id_usuario INTEGER,
                    rol TEXT,
                    id_pedido INTEGER,
                    mensaje TEXT,
                    evidencia TEXT DEFAULT '',
                    estado TEXT DEFAULT 'abierto',
                    respuesta_admin TEXT DEFAULT '',
                    fecha TEXT DEFAULT CURRENT_TIMESTAMP
                );
                INSERT INTO soporte (id_usuario, rol, id_pedido, mensaje)
                VALUES (7, 'cliente', 1, 'Pedido incompleto');
                INSERT INTO mensajes_chat (id_pedido, remitente, mensaje)
                VALUES (1, 'Cliente', 'Pedido incompleto');
                """
            )
        admin_core.ensure_admin_schema()
        admin_core.bootstrap_admin(
            "owner@example.test", "sufficient-local-passphrase"
        )
        login = admin_core.admin_login(
            admin_core.AdminLogin(
                identificador="owner@example.test",
                contrasena="sufficient-local-passphrase",
            ),
            self._request(),
        )
        request = self._request(
            [(b"authorization", f"Bearer {login['access_token']}".encode())]
        )
        request.state.admin = asyncio.run(admin_core.require_admin(request))
        self.assertTrue(
            any(
                dependency.call is admin_core.require_admin
                for dependency in adm_soporte.router.routes[
                    next(
                        index
                        for index, route in enumerate(adm_soporte.router.routes)
                        if route.path == "/api/admin/tickets_soporte/{id_ticket}/mensajes"
                        and "POST" in route.methods
                    )
                ].dependant.dependencies
            )
        )
        response = adm_soporte.responder_ticket_admin(
            1,
            adm_soporte.RespuestaAdmin(
                mensaje="Ya gestionamos el pedido.",
                motivo="Respuesta de soporte al cliente",
            ),
            request,
        )
        self.assertEqual(response["status"], "ok")
        thread = adm_soporte.mensajes_ticket_admin(1)
        self.assertEqual(thread["mensajes"][-1]["remitente"], "Admin Central")
        self.assertEqual(thread["mensajes"][-1]["mensaje"], "Ya gestionamos el pedido.")
        with admin_core.open_database() as connection:
            audit = connection.execute(
                "SELECT action, reason FROM auditoria_admin "
                "WHERE entity_type='ticket' AND entity_id='1'"
            ).fetchone()
            connection.execute(
                "UPDATE soporte SET archivado=1 WHERE id_soporte=1"
            )
        self.assertEqual(audit, ("responder_ticket", "Respuesta de soporte al cliente"))
        with self.assertRaises(HTTPException) as archived:
            adm_soporte.responder_ticket_admin(
                1,
                adm_soporte.RespuestaAdmin(
                    mensaje="No debería enviarse",
                    motivo="Intento de respuesta archivada",
                ),
                request,
            )
        self.assertEqual(archived.exception.status_code, 409)

    def test_support_channels_are_preserved_and_visible_in_admin_inbox(self):
        import adm_soporte

        old_module_db = adm_soporte.DB_PATH
        adm_soporte.DB_PATH = admin_core.DB_PATH
        self.addCleanup(setattr, adm_soporte, "DB_PATH", old_module_db)
        with admin_core.open_database() as connection:
            connection.executescript(
                """
                DROP TABLE mensajes_chat;
                DROP TABLE soporte;
                CREATE TABLE mensajes_chat (
                    id_mensaje INTEGER PRIMARY KEY AUTOINCREMENT,
                    id_pedido INTEGER,
                    remitente TEXT,
                    mensaje TEXT,
                    evidencia TEXT DEFAULT '',
                    canal TEXT DEFAULT 'admin_cliente',
                    fecha TEXT DEFAULT CURRENT_TIMESTAMP,
                    leido INTEGER DEFAULT 0
                );
                CREATE TABLE soporte (
                    id_soporte INTEGER PRIMARY KEY AUTOINCREMENT,
                    id_usuario INTEGER,
                    rol TEXT DEFAULT 'cliente',
                    id_pedido INTEGER,
                    mensaje TEXT,
                    evidencia TEXT DEFAULT '',
                    estado TEXT DEFAULT 'abierto',
                    respuesta_admin TEXT DEFAULT '',
                    fecha TEXT DEFAULT CURRENT_TIMESTAMP
                );
                ALTER TABLE pedidos ADD COLUMN codigo_rastreo TEXT;
                ALTER TABLE pedidos ADD COLUMN id_cliente INTEGER;
                ALTER TABLE pedidos ADD COLUMN id_comercio INTEGER;
                ALTER TABLE pedidos ADD COLUMN id_repartidor INTEGER;
                ALTER TABLE usuarios ADD COLUMN nombre TEXT;
                ALTER TABLE usuarios ADD COLUMN telefono TEXT;
                ALTER TABLE comercios ADD COLUMN nombre_local TEXT;
                ALTER TABLE comercios ADD COLUMN telefono TEXT;
                UPDATE pedidos SET estado='asignado', codigo_rastreo='CP-12345'
                WHERE id_pedido=1;
                """
            )
        admin_core.ensure_admin_schema()
        response = adm_soporte.enviar_mensaje(
            adm_soporte.MensajeChat(
                id_pedido=1,
                remitente="Repartidor #7",
                mensaje="Necesito ayuda con la entrega.",
                canal="admin_repartidor",
                id_usuario=7,
                rol="repartidor",
            )
        )
        self.assertEqual(response["canal"], "admin_repartidor")
        tickets = adm_soporte.ver_quejas_admin()
        self.assertEqual(len(tickets), 1)
        self.assertEqual(tickets[0]["canal"], "admin_repartidor")
        self.assertEqual(tickets[0]["mensajes_nuevos"], 1)
        mobile_history = adm_soporte.obtener_historial_chat(
            1, canal="admin_repartidor"
        )
        self.assertEqual(len(mobile_history["mensajes"]), 1)
        self.assertEqual(adm_soporte.ver_quejas_admin()[0]["mensajes_nuevos"], 1)
        thread = adm_soporte.mensajes_ticket_admin(tickets[0]["id_ticket"])
        self.assertEqual(thread["mensajes"][0]["mensaje"], "Necesito ayuda con la entrega.")
        self.assertEqual(adm_soporte.ver_quejas_admin()[0]["mensajes_nuevos"], 0)

        admin_core.bootstrap_admin(
            "owner@example.test", "sufficient-local-passphrase"
        )
        login = admin_core.admin_login(
            admin_core.AdminLogin(
                identificador="owner@example.test",
                contrasena="sufficient-local-passphrase",
            ),
            self._request(),
        )
        request = self._request(
            [(b"authorization", b"Bearer " + login["access_token"].encode())]
        )
        request.state.admin = asyncio.run(admin_core.require_admin(request))
        adm_soporte.responder_ticket_admin(
            tickets[0]["id_ticket"],
            adm_soporte.RespuestaAdmin(
                mensaje="Central atendiendo el caso.",
                motivo="Atención de incidencia del repartidor",
            ),
            request,
        )
        with admin_core.open_database() as connection:
            reply = connection.execute(
                "SELECT canal FROM mensajes_chat WHERE remitente='Admin Central'"
            ).fetchone()
        self.assertEqual(reply[0], "admin_repartidor")
        updated_thread = adm_soporte.mensajes_ticket_admin(tickets[0]["id_ticket"])
        self.assertEqual(updated_thread["mensajes"][-1]["mensaje"], "Central atendiendo el caso.")
        with admin_core.open_database() as connection:
            connection.execute(
                """
                INSERT INTO mensajes_chat
                    (id_pedido, remitente, mensaje, canal)
                VALUES (1, 'Cliente #9', 'Consulta independiente', 'admin_cliente')
                """
            )
        adm_soporte.borrar_todo_chat(1, canal="admin_repartidor")
        with admin_core.open_database() as connection:
            archived_channels = connection.execute(
                """
                SELECT canal, archivado FROM mensajes_chat
                WHERE id_pedido = 1 ORDER BY canal
                """
            ).fetchall()
        self.assertEqual(
            archived_channels,
            [
                ("admin_cliente", 0),
                ("admin_repartidor", 1),
                ("admin_repartidor", 1),
            ],
        )


if __name__ == "__main__":
    unittest.main()
