import json
import unittest
from unittest.mock import patch

from admin_api_client import AdminApiClient, AdminApiError, validate_base_url
from admin_app import login_error_message


class FakeResponse:
    def __init__(self, value):
        self.value = value

    def __enter__(self):
        return self

    def __exit__(self, *_args):
        return False

    def read(self):
        return json.dumps(self.value).encode("utf-8")


class AdminApiClientTests(unittest.TestCase):
    def test_http_is_allowed_only_for_loopback_and_https_for_remote_hosts(self):
        self.assertEqual(validate_base_url("http://127.0.0.1:8000/"), "http://127.0.0.1:8000")
        self.assertEqual(validate_base_url("https://admin.example.test"), "https://admin.example.test")
        for url in (
            "http://admin.example.test",
            "http://192.168.1.10:8000",
            "https://user:password@example.test",
            "https://example.test/api",
        ):
            with self.subTest(url=url), self.assertRaises(ValueError):
                validate_base_url(url)

    def test_login_validates_session_and_sends_bearer_token_only_after_auth(self):
        client = AdminApiClient()
        responses = [
            FakeResponse({"access_token": "signed-token", "token_type": "bearer"}),
            FakeResponse({"admin": {"rol": "superadmin"}}),
            FakeResponse({"logs": [], "total": 0}),
        ]
        with patch("admin_api_client.urlopen", side_effect=responses) as open_url:
            client.login("owner@example.test", "private-password")
            self.assertTrue(client.authenticated)
            client.get("/api/admin/auditoria_logs", query={"limit": "50"})

        login_request = open_url.call_args_list[0].args[0]
        me_request = open_url.call_args_list[1].args[0]
        audit_request = open_url.call_args_list[2].args[0]
        self.assertIsNone(login_request.get_header("Authorization"))
        self.assertEqual(
            me_request.get_header("Authorization"), "Bearer signed-token"
        )
        self.assertEqual(
            audit_request.get_header("Authorization"), "Bearer signed-token"
        )
        self.assertNotIn("private-password", repr(login_request.headers))

    def test_authenticated_calls_require_a_session(self):
        client = AdminApiClient()
        with self.assertRaises(AdminApiError):
            client.get("/api/admin/auditoria_logs")

    def test_login_errors_distinguish_credentials_from_jwt_configuration(self):
        credentials = login_error_message(
            AdminApiError("Credenciales administrativas incorrectas.", 401)
        )
        configuration = login_error_message(
            AdminApiError(
                "Defina ADMIN_JWT_SECRET (mínimo 32 bytes).",
                503,
            )
        )
        self.assertIn("HTTP 401", credentials)
        self.assertIn("no es la contraseña", credentials)
        self.assertIn("ADMIN_JWT_SECRET", configuration)
        self.assertIn("reinicia Uvicorn", configuration)


if __name__ == "__main__":
    unittest.main()
