import sqlite3

conexion = sqlite3.connect("conecta_local.db")
cursor = conexion.cursor()

print("--- COMERCIOS REGISTRADOS ---")
cursor.execute("SELECT id_comercio, nombre_local, telefono, estado FROM comercios")
filas = cursor.fetchall()

for f in filas:
    print(f"ID: {f[0]} | Nombre: {f[1]} | Tel: {f[2]} | Estado: {f[3]}")

conexion.close()