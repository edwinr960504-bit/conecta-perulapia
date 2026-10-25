import ipaddress
import json
from urllib.error import HTTPError, URLError
from urllib.parse import urlencode, urlsplit
from urllib.request import Request, urlopen


DEFAULT_BASE_URL = "http://127.0.0.1:8000"


class AdminApiError(RuntimeError):
    def __init__(self, message, status_code=None):
        super().__init__(message)
        self.status_code = status_code


def validate_base_url(value):
    parts = urlsplit(value.strip())
    if (
        parts.scheme not in {"http", "https"}
        or not parts.hostname
        or parts.username
        or parts.password
        or parts.query
        or parts.fragment
        or parts.path not in {"", "/"}
    ):
        raise ValueError("Indica un origen HTTP(S) válido, sin rutas ni credenciales.")

    if parts.scheme == "http":
        host = parts.hostname.lower()
        is_loopback = host == "localhost"
        try:
            is_loopback = is_loopback or ipaddress.ip_address(host).is_loopback
        except ValueError:
            pass
        if not is_loopback:
            raise ValueError("Para conexiones fuera de esta PC se requiere HTTPS.")

    return value.strip().rstrip("/")


class AdminApiClient:
    def __init__(self, base_url=DEFAULT_BASE_URL, timeout=15):
        self.base_url = validate_base_url(base_url)
        self.timeout = timeout
        self._access_token = None

    @property
    def authenticated(self):
        return self._access_token is not None

    def set_base_url(self, value):
        self.base_url = validate_base_url(value)

    def _request(self, method, path, body=None, query=None, authenticated=True):
        if not path.startswith("/") or path.startswith("//"):
            raise ValueError("La ruta de API debe ser relativa al servidor.")
        if authenticated and not self._access_token:
            raise AdminApiError("Inicia sesión como Superadmin para continuar.")

        url = f"{self.base_url}{path}"
        if query:
            url = f"{url}?{urlencode(query)}"
        headers = {"Accept": "application/json"}
        payload = None
        if body is not None:
            headers["Content-Type"] = "application/json; charset=utf-8"
            payload = json.dumps(body, ensure_ascii=False).encode("utf-8")
        if authenticated:
            headers["Authorization"] = f"Bearer {self._access_token}"

        request = Request(url, data=payload, headers=headers, method=method)
        try:
            with urlopen(request, timeout=self.timeout) as response:
                raw = response.read()
                if not raw:
                    return None
                return json.loads(raw.decode("utf-8"))
        except HTTPError as error:
            raw = error.read()
            try:
                detail = json.loads(raw.decode("utf-8")).get("detail")
            except (UnicodeDecodeError, json.JSONDecodeError, AttributeError):
                detail = None
            if error.code == 401 and authenticated:
                self._access_token = None
            raise AdminApiError(
                str(detail or f"El servidor respondió HTTP {error.code}."),
                status_code=error.code,
            ) from error
        except (URLError, TimeoutError, OSError, json.JSONDecodeError) as error:
            raise AdminApiError(
                f"No fue posible completar la solicitud al backend: {error}"
            ) from error

    def login(self, identifier, password):
        response = self._request(
            "POST",
            "/api/admin/auth/login",
            body={"identificador": identifier, "contrasena": password},
            authenticated=False,
        )
        token = response.get("access_token") if isinstance(response, dict) else None
        if not token:
            raise AdminApiError("El servidor no devolvió una sesión administrativa.")
        self._access_token = token
        try:
            self._request("GET", "/api/admin/auth/me")
        except AdminApiError:
            self._access_token = None
            raise

    def logout(self):
        if not self._access_token:
            return
        try:
            self._request("POST", "/api/admin/auth/logout")
        finally:
            self._access_token = None

    def get(self, path, query=None):
        return self._request("GET", path, query=query)

    def post(self, path, body):
        return self._request("POST", path, body=body)
