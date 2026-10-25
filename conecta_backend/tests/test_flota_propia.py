import sqlite3
import sys
import tempfile
import unittest
from contextlib import closing
from pathlib import Path
from types import SimpleNamespace

from fastapi import HTTPException

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import flota_propia
import mobile_auth
import tuberias_identidad
import tuberias_logistica
import tuberias_pedidos


def peticion(rol, id_):
    return SimpleNamespace(state=SimpleNamespace(mobile_user={"role": rol, "id": id_}))


class FlotaPropiaTests(unittest.TestCase):
    def setUp(self):
        self.temp_dir = tempfile.TemporaryDirectory(prefix="flota-tests-")
        self.db_path = str(Path(self.temp_dir.name) / "flota.db")
        self.modulos = (mobile_auth, flota_propia, tuberias_pedidos, tuberias_logistica, tuberias_identidad)
        self.anteriores = [m.DB_PATH for m in self.modulos]
        for modulo in self.modulos:
            modulo.DB_PATH = self.db_path
        with closing(sqlite3.connect(self.db_path)) as c, c:
            c.executescript(
                """
                CREATE TABLE usuarios (id_usuario INTEGER PRIMARY KEY, nombre TEXT, telefono TEXT,
                    correo TEXT, contrasena TEXT, rol TEXT, dui TEXT, direccion TEXT, estado TEXT);
                CREATE TABLE comercios (id_comercio INTEGER PRIMARY KEY, nombre_local TEXT, telefono TEXT,
                    correo TEXT, contrasena TEXT, dui TEXT, estado TEXT, latitud REAL, longitud REAL);
                CREATE TABLE pedidos (id_pedido INTEGER PRIMARY KEY, id_cliente INTEGER, id_comercio INTEGER,
                    descripcion TEXT, precio_comida REAL, total_pago REAL, estado TEXT, fecha TEXT,
                    id_repartidor INTEGER DEFAULT 0, latitud_comercio REAL, longitud_comercio REAL,
                    distancia_km REAL, tarifa_envio REAL, codigo_rastreo TEXT, numero_diario INTEGER);
                INSERT INTO comercios (id_comercio, nombre_local, telefono, estado) VALUES
                    (1, 'Con flota', '70000001', 'activo'), (2, 'Sin flota', '70000002', 'activo');
                INSERT INTO usuarios (id_usuario, nombre, telefono, rol, estado) VALUES
                    (50, 'Plataforma', '71110000', 'repartidor', 'activo');
                INSERT INTO pedidos (id_pedido, id_comercio, estado) VALUES
                    (10, 1, 'preparacion'), (11, 2, 'preparacion');
                """
            )

    def tearDown(self):
        for modulo, ruta in zip(self.modulos, self.anteriores):
            modulo.DB_PATH = ruta
        self.temp_dir.cleanup()

    def crear_propio(self, telefono="72220000"):
        return flota_propia.crear_repartidor_propio(
            flota_propia.RepartidorPropioNuevo(id_comercio=1, nombre="Juan Perez", telefono=telefono),
            peticion("comercio", 1),
        )

    def ids_bolsa(self, rol, id_):
        pedidos = tuberias_pedidos.pedidos_disponibles(peticion(rol, id_))
        return sorted(p["id_pedido"] for p in pedidos)

    def test_crea_cuenta_con_login_y_sin_duplicados(self):
        creado = self.crear_propio()
        self.assertEqual(creado["status"], "ok")
        self.assertEqual(self.crear_propio()["status"], "error")
        resp = tuberias_identidad.login(
            tuberias_identidad.Credenciales(identificador=creado["usuario"], contrasena=creado["contrasena"])
        )
        self.assertEqual(resp["status"], "ok")
        self.assertEqual(resp["rol"], "repartidor")

    def test_comercio_ajeno_no_puede_crear(self):
        with self.assertRaises(HTTPException):
            flota_propia.crear_repartidor_propio(
                flota_propia.RepartidorPropioNuevo(id_comercio=1, nombre="Juan Perez", telefono="73330000"),
                peticion("comercio", 2),
            )

    def test_bolsa_oculta_pedidos_del_local_con_flota(self):
        propio = self.crear_propio()["id_repartidor"]
        self.assertEqual(self.ids_bolsa("repartidor", 50), [11])
        self.assertEqual(self.ids_bolsa("repartidor", propio), [10])
        flota_propia.lanzar_pedido_al_radar(flota_propia.LanzarRadar(id_pedido=10), peticion("comercio", 1))
        self.assertEqual(self.ids_bolsa("repartidor", 50), [10, 11])

    def test_tomar_pedido_respeta_la_flota(self):
        propio = self.crear_propio()["id_repartidor"]
        tomar = tuberias_logistica.TomarPedido
        self.assertEqual(
            tuberias_logistica.repartidor_toma_pedido(tomar(id_pedido=10, id_repartidor=50), peticion("repartidor", 50))["status"],
            "error",
        )
        self.assertEqual(
            tuberias_logistica.repartidor_toma_pedido(tomar(id_pedido=11, id_repartidor=propio), peticion("repartidor", propio))["status"],
            "error",
        )
        self.assertEqual(
            tuberias_logistica.repartidor_toma_pedido(tomar(id_pedido=10, id_repartidor=propio), peticion("repartidor", propio))["status"],
            "ok",
        )

    def test_asignar_valida_pertenencia_y_ocupacion(self):
        propio = self.crear_propio()["id_repartidor"]
        asignar = flota_propia.AsignarRepartidor
        ajeno = flota_propia.asignar_repartidor_propio(asignar(id_pedido=10, id_repartidor=50), peticion("comercio", 1))
        self.assertEqual(ajeno["status"], "error")
        ok = flota_propia.asignar_repartidor_propio(asignar(id_pedido=10, id_repartidor=propio), peticion("comercio", 1))
        self.assertEqual(ok["status"], "ok")
        with closing(sqlite3.connect(self.db_path)) as c:
            self.assertEqual(c.execute("SELECT estado, id_repartidor FROM pedidos WHERE id_pedido = 10").fetchone(), ("asignado", propio))
        with self.assertRaises(HTTPException):
            flota_propia.asignar_repartidor_propio(asignar(id_pedido=11, id_repartidor=propio), peticion("comercio", 1))

    def test_quitar_bloquea_cuenta_y_libera_bolsa(self):
        propio = self.crear_propio()["id_repartidor"]
        res = flota_propia.quitar_repartidor_propio(
            flota_propia.QuitarRepartidorPropio(id_comercio=1, id_repartidor=propio), peticion("comercio", 1)
        )
        self.assertEqual(res["status"], "ok")
        self.assertEqual(self.ids_bolsa("repartidor", 50), [10, 11])
        self.assertEqual(flota_propia.listar_repartidores_propios(1)["repartidores"], [])


if __name__ == "__main__":
    unittest.main()
