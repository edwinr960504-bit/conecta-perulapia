from pyngrok import ngrok
public_url = ngrok.connect(8000)
print("TU URL PUBLICA ES:", public_url)
input("Presiona Enter para cerrar el túnel...")