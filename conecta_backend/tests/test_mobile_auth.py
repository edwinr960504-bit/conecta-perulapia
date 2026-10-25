import asyncio
import os
import sqlite3
import sys
import tempfile
import unittest
from contextlib import closing
from pathlib import Path

from fastapi import HTTPException
from starlette.requests import Request

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import mobile_auth
import tuberias_identidad


class MobileAuthenticationTests(unittest.TestCase):
    def setUp(self):
        self.temp_dir = tempfile.TemporaryDirectory(prefix="mobile-auth-tests-")
        self.db_path = str(Path(self.temp_dir.name) / "mobile-test.db")
        self.old_mobile_db_path = mobile_auth.DB_PATH
        self.old_identity_db_path = tuberias_identidad.DB_PATH
        self.old_secret = os.environ.get("MOBILE_JWT_SECRET")
        mobile_auth.DB_PATH = self.db_path
        tuberias_identidad.DB_PATH = self.db_path
        os.environ["MOBILE_JWT_SECRET"] = (
            "test-mobile-signing-secret-at-least-32-bytes"
        )
        with closing(sqlite3.connect(self.db_path)) as connection, connection:
            connection.executescript(
                """
                CREATE TABLE usuarios (
                    id_usuario INTEGER PRIMARY KEY,
                    nombre TEXT,
                    telefono TEXT,
                    correo TEXT,
                    contrasena TEXT,
                    rol TEXT,
                    dui TEXT,
                    direccion TEXT,
                    foto_perfil TEXT,
                    estado TEXT
                );
                CREATE TABLE comercios (
                    id_comercio INTEGER PRIMARY KEY,
                    nombre_local TEXT,
                    telefono TEXT,
                    correo TEXT,
                    contrasena TEXT,
                    dui TEXT,
                    estado TEXT
                );
                INSERT INTO usuarios (
                    id_usuario, nombre, telefono, correo, contrasena,
                    rol, dui, estado
                ) VALUES (
                    7, 'Test Client', '5550007', 'client@example.test',
                    'legacy-password', 'cliente', '00000007-0', 'activo'
                );
                """
            )

    def tearDown(self):
        mobile_auth.DB_PATH = self.old_mobile_db_path
        tuberias_identidad.DB_PATH = self.old_identity_db_path
        if self.old_secret is None:
            os.environ.pop("MOBILE_JWT_SECRET", None)
        else:
            os.environ["MOBILE_JWT_SECRET"] = self.old_secret
        self.temp_dir.cleanup()

    def test_login_migrates_password_and_issues_revocable_token(self):
        response = tuberias_identidad.login(
            tuberias_identidad.Credenciales(
                identificador="client@example.test",
                contrasena="legacy-password",
            )
        )

        self.assertEqual(response["status"], "ok")
        self.assertEqual(response["id"], 7)
        claims = mobile_auth.verify_mobile_token(response["access_token"])
        self.assertEqual(claims["role"], "cliente")
        self.assertEqual(claims["id"], 7)

        with closing(sqlite3.connect(self.db_path)) as connection:
            stored = connection.execute(
                "SELECT contrasena, password_hash, password_salt "
                "FROM usuarios WHERE id_usuario = 7"
            ).fetchone()
        self.assertEqual(stored[0], "")
        self.assertTrue(stored[1])
        self.assertTrue(stored[2])

        asyncio.run(mobile_auth.mobile_logout(claims))
        with self.assertRaises(HTTPException):
            mobile_auth.verify_mobile_token(response["access_token"])

    @staticmethod
    def _request(path):
        return Request(
            {
                "type": "http",
                "asgi": {"version": "3.0"},
                "http_version": "1.1",
                "method": "GET",
                "scheme": "https",
                "path": path,
                "raw_path": path.encode(),
                "query_string": b"",
                "headers": [],
                "client": ("127.0.0.1", 1234),
                "server": ("test", 443),
            }
        )

    def test_authenticated_routes_enforce_role_and_actor_ownership(self):
        request = self._request("/api/perfil/8")
        request.state.mobile_user = {"id": 7, "role": "cliente", "jti": "test"}
        with self.assertRaises(HTTPException) as wrong_owner:
            mobile_auth.authorize_path_resource(request, request.state.mobile_user)
        self.assertEqual(wrong_owner.exception.status_code, 403)

        rider_route = self._request("/api/pedidos_disponibles")
        rider_route.state.mobile_user = request.state.mobile_user
        with self.assertRaises(HTTPException) as wrong_role:
            mobile_auth.authorize_path_resource(
                rider_route, rider_route.state.mobile_user
            )
        self.assertEqual(wrong_role.exception.status_code, 403)

    def test_mobile_dependency_rejects_missing_and_invalid_tokens(self):
        request = self._request("/api/pedidos_disponibles")
        with self.assertRaises(HTTPException) as missing:
            asyncio.run(mobile_auth.require_mobile_user(request))
        self.assertEqual(missing.exception.status_code, 401)

        invalid_request = self._request("/api/pedidos_disponibles")
        invalid_request.scope["headers"] = [
            (b"authorization", b"Bearer invalid")
        ]
        with self.assertRaises(HTTPException) as invalid:
            asyncio.run(mobile_auth.require_mobile_user(invalid_request))
        self.assertEqual(invalid.exception.status_code, 401)

    def test_login_rejects_wrong_password_without_issuing_token(self):
        response = tuberias_identidad.login(
            tuberias_identidad.Credenciales(
                identificador="client@example.test",
                contrasena="wrong-password",
            )
        )

        self.assertEqual(response["status"], "error")
        self.assertNotIn("access_token", response)


if __name__ == "__main__":
    unittest.main()
