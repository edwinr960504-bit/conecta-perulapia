import getpass
import re

from admin_core import bootstrap_admin


def main():
    identifier = input("Correo/identificador del Superadmin: ").strip()
    if not identifier or len(identifier) > 254:
        raise SystemExit("El identificador debe tener entre 1 y 254 caracteres.")
    if not re.fullmatch(r"[^@\s]+@[^@\s]+\.[^@\s]+", identifier):
        raise SystemExit("Usa un correo válido como identificador de administración.")

    password = getpass.getpass("Contraseña nueva (mínimo 14 caracteres): ")
    confirmation = getpass.getpass("Confirma la contraseña: ")
    if len(password) < 14:
        raise SystemExit("La contraseña debe tener al menos 14 caracteres.")
    if password != confirmation:
        raise SystemExit("Las contraseñas no coinciden.")

    try:
        admin_id = bootstrap_admin(identifier, password)
    except Exception as error:
        raise SystemExit(f"No se pudo crear el Superadmin: {error}") from error
    print(f"Superadmin inicial creado con ID {admin_id}. Conserva el acceso de forma segura.")


if __name__ == "__main__":
    main()
