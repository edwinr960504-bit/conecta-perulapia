@echo off
title Servidor Central Conecta Perulapita
cd /d C:\Users\edwin\perulapia_connect\conecta_backend
python -m uvicorn main:app --host 0.0.0.0 --port 8000 --reload
pause