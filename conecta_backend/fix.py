import sqlite3

conexion = sqlite3.connect("conecta_local.db")
cursor = conexion.cursor()

try:
    cursor.execute("ALTER TABLE comercios ADD COLUMN fecha_registro TIMESTAMP DEFAULT CURRENT_TIMESTAMP")
    conexion.commit()
    print("¡Columna 'fecha_registro' agregada con éxito a la tabla comercios!")
except Exception as e:
    print("La columna ya existía o hubo un detalle:", e)

conexion.close()