import csv
import json
import tkinter as tk
from concurrent.futures import ThreadPoolExecutor
from tkinter import filedialog, messagebox, simpledialog, ttk

import tkintermapview

from admin_api_client import AdminApiClient, AdminApiError, DEFAULT_BASE_URL


COLORS = {
    "navy": "#10243A",
    "navy_light": "#193754",
    "blue": "#2563EB",
    "blue_pale": "#E8F0FF",
    "canvas": "#F2F5F9",
    "surface": "#FFFFFF",
    "border": "#DCE4EE",
    "text": "#16263A",
    "muted": "#64748B",
    "green": "#15803D",
    "green_pale": "#E8F5EC",
    "amber": "#B45309",
    "amber_pale": "#FFF4DB",
    "red": "#B42318",
    "red_pale": "#FDECEA",
}


def support_channel_label(channel):
    return {
        "admin_cliente": "Cliente · pedido",
        "admin_cliente_personal": "Cliente · general",
        "admin_comercio": "Comercio · pedido",
        "admin_comercio_personal": "Comercio · general",
        "admin_repartidor": "Repartidor · pedido",
        "admin_repartidor_personal": "Repartidor · general",
    }.get(channel, channel or "Canal no identificado")


def login_error_message(error):
    if not isinstance(error, AdminApiError):
        return str(error)
    if error.status_code == 401:
        return (
            "FastAPI rechazó el identificador o la contraseña de Superadmin "
            "(HTTP 401). ADMIN_JWT_SECRET no es la contraseña de la cuenta."
        )
    if error.status_code == 429:
        return (
            "Se alcanzó el límite de intentos de acceso (HTTP 429). "
            "Espera 15 minutos antes de volver a intentarlo."
        )
    if error.status_code == 503 and "ADMIN_JWT_SECRET" in str(error):
        return (
            "La cuenta pasó la validación, pero FastAPI no pudo emitir el token. "
            "Configura ADMIN_JWT_SECRET en el proceso del backend (mínimo 32 bytes) "
            "y reinicia Uvicorn."
        )
    return str(error)


class AdminDesktopApp:
    def __init__(self, root):
        self.root = root
        self.api = AdminApiClient()
        self.executor = ThreadPoolExecutor(max_workers=4)
        self._session_generation = 0
        self._pending_refreshes = set()
        self._refresh_after_id = None
        self._closing = False
        self.root.title("Conecta Perulapia | Admin Core 2.0")
        self.root.geometry("1280x820")
        self.root.minsize(980, 640)
        self.root.protocol("WM_DELETE_WINDOW", self._close)
        self._configure_style()
        self._show_login()

    def _configure_style(self):
        style = ttk.Style(self.root)
        if "clam" in style.theme_names():
            style.theme_use("clam")
        self.root.configure(background=COLORS["canvas"])
        style.configure(".", font=("Segoe UI", 10), foreground=COLORS["text"])
        style.configure("TFrame", background=COLORS["canvas"])
        style.configure("Card.TFrame", background=COLORS["surface"])
        style.configure("Header.TFrame", background=COLORS["navy"])
        style.configure(
            "Title.TLabel",
            background=COLORS["canvas"],
            foreground=COLORS["navy"],
            font=("Segoe UI", 22, "bold"),
        )
        style.configure(
            "CardTitle.TLabel",
            background=COLORS["surface"],
            foreground=COLORS["navy"],
            font=("Segoe UI", 22, "bold"),
        )
        style.configure(
            "CardText.TLabel",
            background=COLORS["surface"],
            foreground=COLORS["muted"],
        )
        style.configure(
            "HeaderTitle.TLabel",
            background=COLORS["navy"],
            foreground=COLORS["surface"],
            font=("Segoe UI", 18, "bold"),
        )
        style.configure(
            "HeaderMeta.TLabel",
            background=COLORS["navy"],
            foreground="#C8D5E3",
            font=("Segoe UI", 9),
        )
        style.configure(
            "Section.TLabel",
            background=COLORS["canvas"],
            foreground=COLORS["navy"],
            font=("Segoe UI", 13, "bold"),
        )
        style.configure(
            "Muted.TLabel",
            background=COLORS["canvas"],
            foreground=COLORS["muted"],
        )
        style.configure(
            "TNotebook",
            background=COLORS["canvas"],
            borderwidth=0,
            tabmargins=(2, 5, 2, 0),
        )
        style.configure(
            "TNotebook.Tab",
            padding=(16, 10),
            background="#E7EDF4",
            foreground=COLORS["muted"],
            font=("Segoe UI", 10, "bold"),
        )
        style.map(
            "TNotebook.Tab",
            background=[("selected", COLORS["surface"])],
            foreground=[("selected", COLORS["blue"])],
        )
        style.configure(
            "Treeview",
            rowheight=32,
            background=COLORS["surface"],
            fieldbackground=COLORS["surface"],
            foreground=COLORS["text"],
            bordercolor=COLORS["border"],
            font=("Segoe UI", 9),
        )
        style.configure(
            "Treeview.Heading",
            rowheight=34,
            background="#EAF0F6",
            foreground=COLORS["navy"],
            font=("Segoe UI", 9, "bold"),
        )
        style.map("Treeview", background=[("selected", COLORS["blue_pale"])])
        style.configure(
            "TButton",
            padding=(12, 7),
            background="#E7EDF4",
            foreground=COLORS["navy"],
            font=("Segoe UI", 9, "bold"),
        )
        style.map(
            "TButton",
            background=[("active", "#D6E2F0"), ("disabled", "#EEF2F6")],
            foreground=[("disabled", "#94A3B8")],
        )
        style.configure(
            "Primary.TButton",
            background=COLORS["blue"],
            foreground=COLORS["surface"],
        )
        style.map(
            "Primary.TButton",
            background=[("active", "#1D4ED8")],
            foreground=[("active", COLORS["surface"])],
        )

    def _clear(self):
        for child in self.root.winfo_children():
            child.destroy()

    def _show_login(self):
        self._session_generation += 1
        if self._refresh_after_id is not None:
            self.root.after_cancel(self._refresh_after_id)
            self._refresh_after_id = None
        self._clear()
        container = ttk.Frame(self.root, style="Card.TFrame", padding=36)
        container.place(relx=0.5, rely=0.45, anchor="center")
        ttk.Label(
            container,
            text="Admin Core 2.0",
            style="CardTitle.TLabel",
        ).grid(row=0, column=0, columnspan=2, sticky="w", pady=(0, 8))
        ttk.Label(
            container,
            text="CENTRO DE CONTROL PRIVADO  ·  ACCESO SUPERADMIN",
            style="CardText.TLabel",
        ).grid(row=1, column=0, columnspan=2, sticky="w", pady=(0, 24))

        ttk.Label(container, text="Servidor FastAPI", style="CardText.TLabel").grid(
            row=2, column=0, sticky="w", pady=6
        )
        self.base_url = ttk.Entry(container, width=48)
        self.base_url.insert(0, self.api.base_url or DEFAULT_BASE_URL)
        self.base_url.grid(row=2, column=1, sticky="ew", pady=6)

        ttk.Label(container, text="Identificador", style="CardText.TLabel").grid(
            row=3, column=0, sticky="w", pady=6
        )
        self.identifier = ttk.Entry(container, width=48)
        self.identifier.grid(row=3, column=1, sticky="ew", pady=6)

        ttk.Label(container, text="Contraseña", style="CardText.TLabel").grid(
            row=4, column=0, sticky="w", pady=6
        )
        self.password = ttk.Entry(container, width=48, show="*")
        self.password.grid(row=4, column=1, sticky="ew", pady=6)
        self.password.bind("<Return>", lambda _: self._login())

        self.login_button = ttk.Button(
            container,
            text="Iniciar sesión",
            command=self._login,
            style="Primary.TButton",
        )
        self.login_button.grid(
            row=5, column=0, columnspan=2, sticky="ew", pady=(20, 8)
        )
        self.login_status = ttk.Label(
            container,
            text="",
            foreground=COLORS["red"],
            background=COLORS["surface"],
        )
        self.login_status.grid(row=6, column=0, columnspan=2, sticky="w")
        container.columnconfigure(1, weight=1)
        self.identifier.focus_set()

    def _login(self):
        if getattr(self, "_login_pending", False):
            return
        identifier = self.identifier.get().strip()
        password = self.password.get()
        if not identifier or not password:
            self.login_status.configure(text="Ingresa el identificador y la contraseña.")
            return
        try:
            self.api.set_base_url(self.base_url.get())
        except ValueError as error:
            self.login_status.configure(text=str(error))
            return
        self._login_pending = True
        self.login_button.configure(state="disabled")
        self.login_status.configure(text="Validando acceso con el servidor…")

        def authenticated(_result):
            self._login_pending = False
            self.password.delete(0, tk.END)
            self._session_generation += 1
            self._show_console()

        def login_failed(error):
            self._login_pending = False
            self.login_button.configure(state="normal")
            self.login_status.configure(text=login_error_message(error))

        self._run_async(
            "login",
            lambda: self.api.login(identifier, password),
            authenticated,
            error_callback=login_failed,
            require_authenticated=False,
        )

    def _show_console(self):
        self._clear()
        header = ttk.Frame(self.root, style="Header.TFrame", padding=(20, 14))
        header.pack(fill="x")
        ttk.Label(header, text="CONECTA  /  ADMIN CORE", style="HeaderTitle.TLabel").pack(
            side="left"
        )
        ttk.Label(
            header,
            text=f"SUPERADMIN  ·  {self.api.base_url}",
            style="HeaderMeta.TLabel",
        ).pack(side="left", padx=20)
        ttk.Button(header, text="Cerrar sesión", command=self._logout).pack(
            side="right"
        )

        self.notebook = ttk.Notebook(self.root)
        self.notebook.pack(fill="both", expand=True, padx=14, pady=(0, 8))
        self.status = ttk.Label(
            self.root,
            text="Sesión autenticada.",
            anchor="w",
            background=COLORS["navy"],
            foreground="#D8E3EE",
            padding=(16, 8),
        )
        self.status.pack(fill="x", side="bottom")

        self._build_dashboard_tab()
        self._build_live_operations_tab()
        self._build_directory_tab()
        self._build_finance_tab()
        self._build_audit_tab()
        self._build_operations_tab()
        self._build_support_tab()
        self._load_dashboard()
        self.notebook.bind("<<NotebookTabChanged>>", self._on_tab_changed)
        self._schedule_live_refresh()

    def _logout(self):
        try:
            self.api.logout()
        except AdminApiError as error:
            messagebox.showerror(
                "No se pudo confirmar el cierre remoto",
                f"La sesión local fue eliminada, pero el backend no confirmó la revocación:\n{error}",
                parent=self.root,
            )
        self._show_login()

    def _close(self):
        self._closing = True
        if self.api.authenticated:
            try:
                self.api.logout()
            except AdminApiError as error:
                messagebox.showwarning(
                    "No se confirmó la revocación",
                    "El panel se cerrará, pero el servidor no confirmó el cierre de sesión. "
                    f"El token vencerá según su plazo configurado.\n\n{error}",
                    parent=self.root,
                )
        self.executor.shutdown(wait=False, cancel_futures=True)
        self.root.destroy()

    def _set_status(self, message):
        self.status.configure(text=message)

    def _run_async(
        self,
        key,
        operation,
        callback,
        error_callback=None,
        require_authenticated=True,
    ):
        if key in self._pending_refreshes or (
            require_authenticated and not self.api.authenticated
        ):
            return
        self._pending_refreshes.add(key)
        generation = self._session_generation
        future = self.executor.submit(operation)

        def poll():
            if self._closing:
                return
            if not future.done():
                self.root.after(50, poll)
                return
            self._pending_refreshes.discard(key)
            if generation != self._session_generation or (
                require_authenticated and not self.api.authenticated
            ):
                return
            try:
                callback(future.result())
            except AdminApiError as error:
                if error.status_code == 401 and require_authenticated:
                    self._show_login()
                    self.login_status.configure(
                        text="La sesión venció o fue revocada. Inicia sesión nuevamente."
                    )
                    return
                if error_callback:
                    error_callback(error)
                else:
                    self._set_status(f"Error al actualizar {key}: {error}")
            except (ValueError, TypeError, KeyError) as error:
                self._set_status(f"Respuesta inválida al actualizar {key}: {error}")

        self.root.after(50, poll)

    def _fetch_async(self, key, path, callback, query=None, error_callback=None):
        return self._run_async(
            key,
            lambda: self.api.get(path, query),
            callback,
            error_callback=error_callback,
        )

    def _on_tab_changed(self, _event=None):
        if not hasattr(self, "notebook") or not self.api.authenticated:
            return
        selected = self.notebook.tab(self.notebook.select(), "text")
        if selected == "Resumen":
            self._load_dashboard()
        elif selected == "Operación en vivo":
            self._refresh_selected_live_view()
        elif selected == "Finanzas":
            self._load_finance()
        elif selected == "Directorio":
            self._load_directory()
        elif selected == "Auditoría":
            self._load_audit()
        elif selected == "Soporte":
            self._load_support()

    def _schedule_live_refresh(self):
        if not self.api.authenticated:
            return

        def refresh():
            self._refresh_after_id = None
            if self.api.authenticated:
                if not hasattr(self, "notebook"):
                    return
                selected = self.notebook.tab(self.notebook.select(), "text")
                if selected == "Resumen":
                    self._load_dashboard()
                elif selected == "Soporte":
                    self._load_support()
                elif selected == "Operación en vivo":
                    self._refresh_selected_live_view()
                self._refresh_after_id = self.root.after(15000, refresh)

        self._refresh_after_id = self.root.after(15000, refresh)

    def _refresh_selected_live_view(self):
        if not hasattr(self, "live_notebook"):
            return
        selected = self.live_notebook.tab(self.live_notebook.select(), "text")
        if selected == "Radar":
            self._load_live_radar()
        elif selected == "Pedidos":
            self._load_active_orders()
            self._load_order_history()
        elif selected == "Actividad":
            self._load_activity()

    def _report_error(self, operation, error):
        if isinstance(error, AdminApiError) and error.status_code == 401:
            self._show_login()
            self.login_status.configure(
                text="La sesión venció o fue revocada. Inicia sesión nuevamente."
            )
            return
        self._set_status(f"{operation}: {error}")
        messagebox.showerror(operation, str(error), parent=self.root)

    @staticmethod
    def _pretty(value):
        return json.dumps(value, ensure_ascii=False, indent=2, default=str)

    def _build_dashboard_tab(self):
        page = ttk.Frame(self.notebook, padding=18)
        self.notebook.add(page, text="Resumen")
        heading = ttk.Frame(page)
        heading.pack(fill="x", pady=(0, 12))
        ttk.Label(heading, text="Estado operativo", style="Section.TLabel").pack(
            side="left"
        )
        ttk.Button(
            heading,
            text="Actualizar ahora",
            command=self._load_dashboard,
        ).pack(side="right")
        self.dashboard_cards = ttk.Frame(page)
        self.dashboard_cards.pack(fill="x", pady=(0, 14))
        card_specs = (
            ("clientes", "Clientes activos", COLORS["blue"], COLORS["blue_pale"]),
            ("pendientes", "Pendientes", COLORS["amber"], COLORS["amber_pale"]),
            ("preparacion", "En preparación", COLORS["blue"], COLORS["blue_pale"]),
            ("ruta", "En ruta", COLORS["green"], COLORS["green_pale"]),
            ("incidencias", "Tickets abiertos", COLORS["red"], COLORS["red_pale"]),
        )
        self.dashboard_metrics = {
            key: self._metric_card(self.dashboard_cards, title, color, fill)
            for key, title, color, fill in card_specs
        }
        for index in range(len(card_specs)):
            self.dashboard_cards.columnconfigure(index, weight=1, uniform="dashboard")
        self.dashboard_operational_metrics = ttk.Label(
            page,
            text="Métricas logísticas: pendientes de consultar",
            style="Muted.TLabel",
        )
        self.dashboard_operational_metrics.pack(anchor="w", pady=(0, 10))
        details = ttk.LabelFrame(page, text="Resumen de plataforma", padding=12)
        details.pack(fill="both", expand=True)
        self.dashboard_text = tk.Text(
            details,
            wrap="word",
            height=18,
            state="disabled",
            background=COLORS["surface"],
            foreground=COLORS["text"],
            relief="flat",
            padx=12,
            pady=10,
            font=("Cascadia Mono", 9),
        )
        self.dashboard_text.pack(fill="both", expand=True)

    def _load_dashboard(self):
        if not hasattr(self, "dashboard_text") or not self.api.authenticated:
            return
        paths = (
            ("Alertas operativas", "/api/admin/alertas_dashboard"),
            ("Métricas del directorio", "/api/admin/metricas_globales"),
            ("Finanzas agregadas", "/api/admin/finanzas_caja"),
            ("Pedidos activos", "/api/admin/radar_despacho"),
            ("Clientes activos", "/api/admin/clientes_activos"),
            ("Métricas operativas", "/api/admin/metricas_operativas"),
        )
        results = {}

        def render():
            if len(results) != len(paths):
                return
            orders = results["Pedidos activos"]
            clients = results["Clientes activos"]
            operational = results["Métricas operativas"]
            alerts = results["Alertas operativas"]
            orders_ok = isinstance(orders, list) and all(
                isinstance(order, dict) for order in orders
            )
            clients_ok = isinstance(clients, list) and all(
                isinstance(client, dict) for client in clients
            )
            orders = orders if orders_ok else []
            clients = clients if clients_ok else []
            ticket_count = (
                alerts.get("tickets_abiertos")
                if isinstance(alerts, dict)
                else None
            )
            counts = {
                "clientes": sum(
                    1 for client in clients if client.get("activo_buscando")
                ) if clients_ok else "—",
                "pendientes": operational.get("pedidos", {}).get("pendientes", "—")
                if isinstance(operational, dict) and not operational.get("error")
                else "—",
                "preparacion": sum(
                    1
                    for order in orders
                    if order.get("estado") in ("preparacion", "listo_recoleccion")
                ) if orders_ok else "—",
                "ruta": sum(
                    1
                    for order in orders
                    if order.get("estado") in ("asignado", "en_camino")
                ) if orders_ok else "—",
                "incidencias": ticket_count
                if isinstance(ticket_count, int)
                else "—",
            }
            for key, value in counts.items():
                self._set_metric(self.dashboard_metrics[key], value)
            if isinstance(operational, dict) and not operational.get("error"):
                order_counts = operational.get("pedidos", {})
                rider_counts = operational.get("repartidores", {})
                business_counts = operational.get("comercios", {})
                self.dashboard_operational_metrics.configure(
                    text=(
                        f"Pedidos: {order_counts.get('activos', '—')} activos / "
                        f"{order_counts.get('total', '—')} totales · "
                        f"{order_counts.get('pendientes', '—')} pendientes     "
                        f"Repartidores: {rider_counts.get('activos', '—')} activos / "
                        f"{rider_counts.get('inactivos', '—')} inactivos     "
                        f"Locales: {business_counts.get('activos', '—')} activos / "
                        f"{business_counts.get('inactivos', '—')} inactivos"
                    )
                )
            else:
                self.dashboard_operational_metrics.configure(
                    text="No se pudieron consultar las métricas logísticas."
                )
            sections = [
                f"{title}\n{self._pretty(results[title])}"
                for title, _path in paths
            ]
            self.dashboard_text.configure(state="normal")
            self.dashboard_text.delete("1.0", tk.END)
            self.dashboard_text.insert("1.0", "\n\n".join(sections))
            self.dashboard_text.configure(state="disabled")
            failures = [
                title
                for title, result in results.items()
                if isinstance(result, dict) and result.get("error")
            ]
            if not orders_ok and "Pedidos activos" not in failures:
                failures.append("Pedidos activos (respuesta inválida)")
            if not clients_ok and "Clientes activos" not in failures:
                failures.append("Clientes activos (respuesta inválida)")
            self._set_status(
                "Resumen operativo actualizado."
                if not failures
                else "Resumen parcial; revisa: " + ", ".join(failures)
            )

        for title, path in paths:
            self._fetch_async(
                f"dashboard-{title}",
                path,
                lambda value, title=title: (results.update({title: value}), render()),
                error_callback=lambda error, title=title: (
                    results.update({title: {"error": str(error)}}),
                    render(),
                ),
            )

    def _metric_card(self, parent, title, color, _fill):
        card = tk.Frame(
            parent,
            background=COLORS["surface"],
            highlightbackground=COLORS["border"],
            highlightthickness=1,
            padx=13,
            pady=10,
        )
        card.pack(side="left", fill="both", expand=True, padx=(0, 8))
        tk.Frame(card, background=color, height=4).pack(fill="x", pady=(0, 9))
        tk.Label(
            card,
            text=title.upper(),
            background=COLORS["surface"],
            foreground=COLORS["muted"],
            font=("Segoe UI", 8, "bold"),
        ).pack(anchor="w")
        value = tk.Label(
            card,
            text="—",
            background=COLORS["surface"],
            foreground=color,
            font=("Segoe UI", 24, "bold"),
        )
        value.pack(anchor="w", pady=(3, 0))
        return value

    @staticmethod
    def _set_metric(label, value):
        label.configure(text=f"{value:,}" if isinstance(value, int) else str(value))

    def _build_live_operations_tab(self):
        page = ttk.Frame(self.notebook, padding=8)
        self.notebook.add(page, text="Operación en vivo")
        self.live_notebook = ttk.Notebook(page)
        self.live_notebook.pack(fill="both", expand=True)
        self.live_notebook.bind("<<NotebookTabChanged>>", self._on_live_tab_changed)

        radar = ttk.Frame(self.live_notebook, padding=10)
        self.live_notebook.add(radar, text="Radar")
        toolbar = ttk.Frame(radar)
        toolbar.pack(fill="x", pady=(0, 8))
        ttk.Label(
            toolbar,
            text=(
                "Mapa © OpenStreetMap contributors · muestra flota, locales y destinos GPS; requiere internet. "
                "La antigüedad de cada GPS no está disponible."
            ),
        ).pack(side="left")
        ttk.Button(toolbar, text="Actualizar", command=self._load_live_radar).pack(
            side="right"
        )
        self.radar_metrics_frame = ttk.Frame(radar)
        self.radar_metrics_frame.pack(fill="x", pady=(0, 10))
        radar_specs = (
            ("clientes", "Clientes activos", COLORS["blue"]),
            ("repartidores", "Repartidores", COLORS["green"]),
            ("pendientes", "Pendientes", COLORS["amber"]),
            ("preparacion", "Preparación", COLORS["blue"]),
            ("ruta", "En ruta", COLORS["red"]),
        )
        self.radar_metrics = {
            key: self._metric_card(
                self.radar_metrics_frame,
                title,
                color,
                COLORS["surface"],
            )
            for key, title, color in radar_specs
        }
        for index in range(len(radar_specs)):
            self.radar_metrics_frame.columnconfigure(index, weight=1, uniform="radar")
        self.radar_operational_metrics = ttk.Label(
            radar,
            text="Pedidos, repartidores y locales: pendientes de consultar",
            style="Muted.TLabel",
        )
        self.radar_operational_metrics.pack(anchor="w", pady=(0, 8))
        split = ttk.Panedwindow(radar, orient="horizontal")
        split.pack(fill="both", expand=True)
        map_frame = ttk.Frame(split)
        list_frame = ttk.Frame(split, padding=(10, 0, 0, 0))
        split.add(map_frame, weight=3)
        split.add(list_frame, weight=2)
        self.radar_map = tkintermapview.TkinterMapView(
            map_frame,
            width=680,
            height=520,
            corner_radius=0,
        )
        self.radar_map.pack(fill="both", expand=True)
        self.radar_map.set_position(13.7333, -89.1167)
        self.radar_map.set_zoom(12)
        self._radar_initial_fit_done = False
        self.radar_legend = ttk.Label(
            list_frame,
            text="● Repartidor activo   ● Pedido   ● Local activo   ● Inactivo gris",
            foreground="#334155",
        )
        self.radar_legend.pack(anchor="w", pady=(0, 6))
        self.radar_status = ttk.Label(list_frame, text="Esperando actualización")
        self.radar_status.pack(anchor="w", pady=(0, 6))
        self.radar_table = self._tree(
            list_frame,
            ("tipo", "id", "nombre", "estado", "lat", "lon"),
            ("Tipo", "ID", "Nombre / comercio", "Estado", "Latitud", "Longitud"),
            (90, 55, 160, 110, 105, 105),
        )
        self.radar_table.bind("<Double-1>", self._radar_row_detail)
        self._radar_points = []
        self._radar_orders = []
        self._radar_fleet = []
        self._radar_businesses = []

        orders = ttk.Frame(self.live_notebook, padding=10)
        self.live_notebook.add(orders, text="Pedidos")
        order_filters = ttk.Frame(orders)
        order_filters.pack(fill="x", pady=(0, 8))
        ttk.Label(order_filters, text="Filtrar estado").pack(side="left")
        self.order_state_filter = ttk.Combobox(
            order_filters,
            values=(
                "Todos",
                "pendiente",
                "preparacion",
                "listo_recoleccion",
                "asignado",
                "en_camino",
                "entregado",
                "cancelado",
                "archivado",
            ),
            state="readonly",
            width=22,
        )
        self.order_state_filter.set("Todos")
        self.order_state_filter.pack(side="left", padx=(6, 14))
        ttk.Label(order_filters, text="Buscar").pack(side="left")
        self.order_search = ttk.Entry(order_filters, width=34)
        self.order_search.pack(side="left", padx=6)
        self.order_state_filter.bind(
            "<<ComboboxSelected>>", lambda _event: self._apply_order_filters()
        )
        self.order_search.bind("<KeyRelease>", lambda _event: self._apply_order_filters())
        order_tabs = ttk.Notebook(orders)
        order_tabs.pack(fill="both", expand=True)
        self.order_tables = {}
        for title, key in (
            ("Pendientes por aceptar", "pendiente"),
            ("En curso", "en_curso"),
            ("Historial", "historial"),
        ):
            panel = ttk.Frame(order_tabs, padding=8)
            order_tabs.add(panel, text=title)
            controls = ttk.Frame(panel)
            controls.pack(fill="x", pady=(0, 8))
            ttk.Button(
                controls,
                text="Actualizar",
                command=self._refresh_selected_live_view,
            ).pack(side="right")
            table = self._tree(
                panel,
                ("id", "fecha", "estado", "comercio", "cliente", "total", "repartidor", "descripcion"),
                ("Pedido", "Fecha", "Estado", "Comercio", "Cliente", "Total", "ID repartidor", "Detalle"),
                (65, 145, 105, 160, 140, 85, 90, 320),
            )
            table.tag_configure("pendiente", background=COLORS["amber_pale"])
            table.tag_configure("preparacion", background=COLORS["blue_pale"])
            table.tag_configure("listo_recoleccion", background="#EEF2FF")
            table.tag_configure("asignado", background=COLORS["green_pale"])
            table.tag_configure("en_camino", background=COLORS["green_pale"])
            table.tag_configure("entregado", foreground=COLORS["green"])
            table.tag_configure("cancelado", foreground=COLORS["muted"])
            table.bind("<Double-1>", lambda _event, table=table: self._order_table_detail(table))
            self.order_tables[key] = table
            if key == "historial":
                paging = ttk.Frame(panel)
                paging.pack(fill="x", pady=(8, 0))
                self.order_history_status = ttk.Label(paging, text="Historial")
                self.order_history_status.pack(side="left")
                ttk.Button(
                    paging,
                    text="Anterior",
                    command=self._order_history_previous,
                ).pack(side="right", padx=4)
                ttk.Button(
                    paging,
                    text="Siguiente",
                    command=self._order_history_next,
                ).pack(side="right", padx=4)
        self.order_history_offset = 0
        self.order_rows_by_bucket = {
            "pendiente": [],
            "en_curso": [],
            "historial": [],
        }

        activity = ttk.Frame(self.live_notebook, padding=10)
        self.live_notebook.add(activity, text="Actividad")
        activity_toolbar = ttk.Frame(activity)
        activity_toolbar.pack(fill="x", pady=(0, 8))
        ttk.Label(
            activity_toolbar,
            text="Eventos de pedido y actos administrativos recientes (refresco automático cada 15 s).",
        ).pack(side="left")
        ttk.Button(activity_toolbar, text="Actualizar", command=self._load_activity).pack(
            side="right"
        )
        self.activity_table = self._tree(
            activity,
            ("fecha", "tipo", "pedido", "actor", "evento", "motivo", "duracion"),
            ("Fecha", "Tipo", "Pedido", "Actor", "Cambio / acción", "Motivo", "Etapa (s)"),
            (155, 110, 70, 120, 210, 360, 80),
        )
        self.activity_table.bind("<Double-1>", self._activity_detail)
        self.activity_rows = {}

    def _on_live_tab_changed(self, _event=None):
        self._refresh_selected_live_view()

    def _load_live_radar(self):
        received = {}

        def render():
            if len(received) != 5:
                return
            self._radar_orders = received["orders"] if isinstance(received["orders"], list) else []
            self._radar_fleet = received["fleet"] if isinstance(received["fleet"], list) else []
            self._radar_businesses = received["businesses"] if isinstance(received["businesses"], list) else []
            clients = received["clients"] if isinstance(received["clients"], list) else []
            self._render_radar_table()
            self._draw_radar()
            failures = {
                key
                for key, value in received.items()
                if isinstance(value, dict) and value.get("error")
            }
            self._update_radar_metrics(clients, failures)
            metrics = received["metrics"]
            if isinstance(metrics, dict) and not metrics.get("error"):
                order_counts = metrics.get("pedidos", {})
                rider_counts = metrics.get("repartidores", {})
                business_counts = metrics.get("comercios", {})
                self.radar_operational_metrics.configure(
                    text=(
                        f"Pedidos: {order_counts.get('activos', '—')} activos / "
                        f"{order_counts.get('total', '—')} totales · "
                        f"{order_counts.get('pendientes', '—')} pendientes     "
                        f"Repartidores: {rider_counts.get('activos', '—')} activos / "
                        f"{rider_counts.get('inactivos', '—')} inactivos     "
                        f"Locales: {business_counts.get('activos', '—')} activos / "
                        f"{business_counts.get('inactivos', '—')} inactivos"
                    )
                )
            else:
                self.radar_operational_metrics.configure(
                    text="No se pudieron consultar las métricas operativas."
                )
            valid_count = sum(1 for point in self._all_radar_points() if point["valid"])
            self.radar_status.configure(
                text=f"{'—' if 'fleet' in failures else len(self._radar_fleet)} repartidores · "
                f"{'—' if 'orders' in failures else len(self._radar_orders)} pedidos · "
                f"{'—' if 'businesses' in failures else len(self._radar_businesses)} comercios · "
                f"{valid_count} posiciones GPS válidas"
            )
            failure_details = [
                f"{key}: {value['error']}"
                for key, value in received.items()
                if isinstance(value, dict) and value.get("error")
            ]
            self._set_status(
                "Radar y contadores actualizados desde FastAPI."
                if not failure_details
                else "No se pudieron cargar algunos datos del radar: "
                + " | ".join(failure_details)
            )

        def loaded(key, rows):
            if not isinstance(rows, list) or not all(
                isinstance(row, dict) for row in rows
            ):
                failed(
                    key,
                    AdminApiError(
                        f"El backend devolvió una lista inválida para {key} en el radar."
                    ),
                )
                return
            received[key] = rows
            render()

        def loaded_metrics(value):
            if not isinstance(value, dict) or not all(
                isinstance(value.get(key), dict)
                for key in ("pedidos", "repartidores", "comercios")
            ):
                failed(
                    "metrics",
                    AdminApiError(
                        "El backend devolvió métricas operativas inválidas."
                    ),
                )
                return
            received["metrics"] = value
            render()

        def failed(key, error):
            received[key] = {"error": str(error)}
            render()

        self._fetch_async(
            "radar-pedidos",
            "/api/admin/radar_despacho",
            lambda value: loaded("orders", value),
            error_callback=lambda error: failed("orders", error),
        )
        self._fetch_async(
            "radar-flota",
            "/api/admin/flota_admin",
            lambda value: loaded("fleet", value),
            error_callback=lambda error: failed("fleet", error),
        )
        self._fetch_async(
            "radar-comercios",
            "/api/admin/comercios_admin",
            lambda value: loaded("businesses", value),
            error_callback=lambda error: failed("businesses", error),
        )
        self._fetch_async(
            "radar-clientes",
            "/api/admin/clientes_activos",
            lambda value: loaded("clients", value),
            error_callback=lambda error: failed("clients", error),
        )
        self._fetch_async(
            "radar-metricas",
            "/api/admin/metricas_operativas",
            lambda value: loaded_metrics(value),
            error_callback=lambda error: failed("metrics", error),
        )

    def _update_radar_metrics(self, clients, failures):
        orders = self._radar_orders
        values = {
            "clientes": sum(
                1 for client in clients if client.get("activo_buscando")
            ) if "clients" not in failures else "—",
            "repartidores": sum(
                1
                for rider in self._radar_fleet
                if str(rider.get("estado", "")).lower() == "activo"
            ) if "fleet" not in failures else "—",
            "pendientes": sum(1 for order in orders if order.get("estado") == "pendiente")
            if "orders" not in failures else "—",
            "preparacion": sum(
                1
                for order in orders
                if order.get("estado") in ("preparacion", "listo_recoleccion")
            ) if "orders" not in failures else "—",
            "ruta": sum(
                1 for order in orders if order.get("estado") in ("asignado", "en_camino")
            ) if "orders" not in failures else "—",
        }
        for key, value in values.items():
            self._set_metric(self.radar_metrics[key], value)

    @staticmethod
    def _valid_coordinate(latitude, longitude):
        try:
            lat = float(latitude)
            lon = float(longitude)
        except (TypeError, ValueError):
            return None
        if not (-90 <= lat <= 90 and -180 <= lon <= 180):
            return None
        if (lat, lon) == (0.0, 0.0) or (lat, lon) == (13.7746, -89.0244):
            return None
        return lat, lon

    def _all_radar_points(self):
        points = []
        for rider in self._radar_fleet:
            coords = self._valid_coordinate(
                rider.get("latitud"), rider.get("longitud")
            )
            points.append(
                {
                    "kind": "repartidor",
                    "id": rider.get("id_repartidor"),
                    "name": rider.get("nombre", "Repartidor"),
                    "status": rider.get("estado", "activo").capitalize(),
                    "coords": coords,
                    "raw": rider,
                    "valid": coords is not None,
                }
            )
        for order in self._radar_orders:
            coords = self._valid_coordinate(
                order.get("lat_cliente"), order.get("lon_cliente")
            )
            points.append(
                {
                    "kind": "pedido",
                    "id": order.get("id_pedido"),
                    "name": (
                        f"{order.get('comercio', 'Pedido')} · "
                        f"{order.get('repartidor', 'Esperando motorista')}"
                    ),
                    "status": order.get("estado", ""),
                    "coords": coords,
                    "raw": order,
                    "valid": coords is not None,
                }
            )
        for business in self._radar_businesses:
            coords = self._valid_coordinate(
                business.get("latitud"), business.get("longitud")
            )
            points.append(
                {
                    "kind": "comercio",
                    "id": business.get("id_comercio", business.get("id")),
                    "name": business.get("nombre_local", business.get("nombre", "Comercio")),
                    "status": (
                        "Activo"
                        if business.get(
                            "activo_app",
                            str(business.get("estado", "")).lower() == "activo",
                        )
                        else "Inactivo"
                    ),
                    "coords": coords,
                    "raw": business,
                    "valid": coords is not None,
                }
            )
        return points

    def _render_radar_table(self):
        points = self._all_radar_points()
        self._clear_tree(self.radar_table)
        for index, point in enumerate(points):
            lat, lon = point["coords"] or (None, None)
            self.radar_table.insert(
                "",
                "end",
                iid=f"radar-{point['kind']}-{point['id']}-{index}",
                values=(
                    point["kind"].capitalize(),
                    point["id"],
                    point["name"],
                    point["status"],
                    f"{lat:.6f}" if lat is not None else "Sin señal GPS",
                    f"{lon:.6f}" if lon is not None else "Sin señal GPS",
                ),
            )

    def _draw_radar(self):
        if not hasattr(self, "radar_map"):
            return
        radar_map = self.radar_map
        radar_map.delete_all_marker()
        points = [item for item in self._all_radar_points() if item["coords"]]
        if not points:
            return

        marker_colors = {
            "repartidor": ("#2563EB", "#1D4ED8"),
            "pedido": ("#DC2626", "#B91C1C"),
            "comercio": ("#16A34A", "#15803D"),
        }
        for point in points:
            lat, lon = point["coords"]
            inside, outside = marker_colors[point["kind"]]
            if point["status"] == "Inactivo":
                inside, outside = "#64748B", "#475569"
            radar_map.set_marker(
                lat,
                lon,
                text=(
                    f"{point['kind'].capitalize()} {point['id']} · "
                    f"{point['name']} · {point['status']}"
                ),
                marker_color_circle=inside,
                marker_color_outside=outside,
            )
        if self._radar_initial_fit_done:
            return
        unique_coords = {point["coords"] for point in points}
        if len(unique_coords) == 1:
            radar_map.set_position(*next(iter(unique_coords)))
            radar_map.set_zoom(15)
        else:
            latitudes = [point["coords"][0] for point in points]
            longitudes = [point["coords"][1] for point in points]
            lat_padding = max((max(latitudes) - min(latitudes)) * 0.1, 0.0005)
            lon_padding = max((max(longitudes) - min(longitudes)) * 0.1, 0.0005)
            north_west = (
                min(85.0511, max(latitudes) + lat_padding),
                max(-180, min(longitudes) - lon_padding),
            )
            south_east = (
                max(-85.0511, min(latitudes) - lat_padding),
                min(180, max(longitudes) + lon_padding),
            )
            radar_map.fit_bounding_box(north_west, south_east)
        self._radar_initial_fit_done = True

    def _radar_row_detail(self, _event=None):
        selected = self.radar_table.selection()
        if not selected:
            return
        values = self.radar_table.item(selected[0], "values")
        if len(values) > 1 and str(values[0]).lower() == "pedido":
            self._show_order_tracking(values[1])

    def _order_table_detail(self, table):
        selected = table.selection()
        if selected:
            self._show_order_tracking(selected[0])

    def _show_order_tracking(self, order_id):
        try:
            numeric_id = int(order_id)
        except (TypeError, ValueError):
            return
        window = tk.Toplevel(self.root)
        window.title(f"Seguimiento del pedido {numeric_id}")
        window.geometry("760x560")
        text = tk.Text(window, wrap="word", state="disabled")
        text.pack(fill="both", expand=True, padx=10, pady=10)
        text.configure(state="normal")
        text.insert("1.0", "Consultando ubicación y cronología del pedido…\n")
        text.configure(state="disabled")
        results = {}

        def update():
            if len(results) != 2 or not window.winfo_exists():
                return
            text.configure(state="normal")
            text.delete("1.0", tk.END)
            text.insert("1.0", "UBICACIONES GPS\n")
            text.insert("end", self._pretty(results["gps"]))
            text.insert("end", "\n\nCRONOLOGÍA\n")
            text.insert("end", self._pretty(results["timeline"]))
            text.configure(state="disabled")

        self._fetch_async(
            f"track-gps-{numeric_id}",
            f"/api/admin/pedidos/{numeric_id}/gps",
            lambda value: (results.update(gps=value), update()),
        )
        self._fetch_async(
            f"track-timeline-{numeric_id}",
            f"/api/admin/pedidos/{numeric_id}/timeline",
            lambda value: (results.update(timeline=value), update()),
        )

    def _focus_selected_support_order(self):
        selected = self.support_table.selection()
        if not selected:
            messagebox.showwarning(
                "Selecciona un expediente",
                "Selecciona un ticket vinculado a un pedido.",
                parent=self.root,
            )
            return
        ticket = self.support_rows.get(selected[0], {})
        self._focus_order_on_radar(ticket.get("id_pedido"))

    def _focus_order_on_radar(self, order_id):
        try:
            numeric_id = int(order_id)
        except (TypeError, ValueError):
            numeric_id = 0
        if numeric_id <= 0:
            messagebox.showinfo(
                "Consulta general",
                "Este caso no está asociado a un pedido ni tiene una ubicación de entrega.",
                parent=self.root,
            )
            return
        for tab_id in self.notebook.tabs():
            if self.notebook.tab(tab_id, "text") == "Operación en vivo":
                self.notebook.select(tab_id)
                break
        self.live_notebook.select(0)
        self._fetch_async(
            f"support-order-gps-{numeric_id}",
            f"/api/admin/pedidos/{numeric_id}/gps",
            lambda data: self._center_radar_on_order(numeric_id, data),
            error_callback=lambda error: self._report_error(
                "Ubicación del pedido", error
            ),
        )

    def _center_radar_on_order(self, order_id, gps):
        if not isinstance(gps, dict) or gps.get("status") != "ok":
            raise AdminApiError("El backend devolvió una ubicación de pedido inválida.")
        locations = (
            ("Repartidor", "latitud_repartidor", "longitud_repartidor", "#2563EB"),
            ("Cliente", "latitud_cliente", "longitud_cliente", "#DC2626"),
            ("Local", "latitud_comercio", "longitud_comercio", "#16A34A"),
        )
        points = []
        for label, lat_key, lon_key, color in locations:
            coords = self._valid_coordinate(gps.get(lat_key), gps.get(lon_key))
            if coords:
                points.append((label, coords, color))
        self.radar_map.delete_all_marker()
        if not points:
            self.radar_status.configure(
                text=f"Pedido #{order_id} · {gps.get('estado_pedido', '')} · sin coordenadas GPS"
            )
            return
        for label, coords, color in points:
            self.radar_map.set_marker(
                *coords,
                text=f"Pedido #{order_id} · {label} · {gps.get('estado_pedido', '')}",
                marker_color_circle=color,
                marker_color_outside=color,
            )
        unique_coords = {coords for _label, coords, _color in points}
        if len(unique_coords) == 1:
            self.radar_map.set_position(*next(iter(unique_coords)))
            self.radar_map.set_zoom(15)
        else:
            latitudes = [coords[0] for _label, coords, _color in points]
            longitudes = [coords[1] for _label, coords, _color in points]
            lat_padding = max((max(latitudes) - min(latitudes)) * 0.1, 0.0005)
            lon_padding = max((max(longitudes) - min(longitudes)) * 0.1, 0.0005)
            self.radar_map.fit_bounding_box(
                (
                    min(85.0511, max(latitudes) + lat_padding),
                    max(-180, min(longitudes) - lon_padding),
                ),
                (
                    max(-85.0511, min(latitudes) - lat_padding),
                    min(180, max(longitudes) + lon_padding),
                ),
            )
        self.radar_status.configure(
            text=f"Pedido #{order_id} · {gps.get('estado_pedido', '')} · "
            + ", ".join(label for label, _coords, _color in points)
        )

    def _build_order_tables(self, key, rows):
        self.order_rows_by_bucket[key] = rows
        self._apply_order_filters()

    def _apply_order_filters(self):
        if not hasattr(self, "order_tables"):
            return
        selected_state = self.order_state_filter.get()
        search = self.order_search.get().strip().casefold()
        for key, table in self.order_tables.items():
            self._clear_tree(table)
            for row in self.order_rows_by_bucket.get(key, []):
                if selected_state != "Todos" and row.get("estado") != selected_state:
                    continue
                searchable = " ".join(
                    str(row.get(field, ""))
                    for field in (
                        "id_pedido",
                        "estado",
                        "comercio",
                        "cliente",
                        "codigo_rastreo",
                        "descripcion",
                    )
                ).casefold()
                if search and search not in searchable:
                    continue
                identifier = str(row.get("id_pedido", ""))
                if not identifier:
                    continue
                self._insert_order_row(table, row, identifier)

    @staticmethod
    def _insert_order_row(table, row, identifier):
        state = str(row.get("estado", ""))
        tags = (state,) if state in {
            "pendiente",
            "preparacion",
            "listo_recoleccion",
            "asignado",
            "en_camino",
            "entregado",
            "cancelado",
        } else ()
        table.insert(
            "",
            "end",
            iid=identifier,
            tags=tags,
            values=(
                identifier,
                row.get("fecha", ""),
                row.get("estado", ""),
                row.get("comercio", ""),
                row.get("cliente", ""),
                row.get("total_pago", row.get("total", "")),
                row.get("id_repartidor", ""),
                row.get("descripcion", row.get("articulos", "")),
            ),
        )

    def _load_active_orders(self):
        def render(rows):
            if not isinstance(rows, list) or not all(
                isinstance(row, dict) for row in rows
            ):
                raise ValueError("Formato inesperado en la bandeja de pedidos activos.")
            pending = [row for row in rows if row.get("estado") == "pendiente"]
            active = [row for row in rows if row.get("estado") != "pendiente"]
            self._build_order_tables("pendiente", pending)
            self._build_order_tables("en_curso", active)
            self._set_status(
                f"Pedidos en vivo: {len(pending)} pendientes · {len(active)} en curso."
            )

        self._fetch_async("orders-active", "/api/admin/radar_despacho", render)

    def _load_order_history(self):
        table = self.order_tables.get("historial")
        if not table:
            return
        self._fetch_async(
            "orders-history",
            "/api/admin/pedidos_historial",
            lambda result: self._render_order_history(result),
            query={
                "estado": "historial",
                "offset": self.order_history_offset,
                "limit": 100,
            },
        )

    def _render_order_history(self, result):
        if not isinstance(result, dict) or not isinstance(result.get("pedidos"), list):
            raise ValueError("Formato inesperado en el historial de pedidos.")
        rows = result.get("pedidos", [])
        self._build_order_tables("historial", rows)
        total = int(result.get("total", len(rows)))
        self.order_history_status.configure(
            text=f"Historial: {self.order_history_offset + 1 if total else 0}–"
            f"{min(self.order_history_offset + len(rows), total)} de {total}"
        )
        self._set_status("Historial actualizado.")

    def _order_history_previous(self):
        self.order_history_offset = max(0, self.order_history_offset - 100)
        self._load_order_history()

    def _order_history_next(self):
        self.order_history_offset += 100
        self._load_order_history()

    def _build_finance_tab(self):
        page = ttk.Frame(self.notebook, padding=12)
        self.notebook.add(page, text="Finanzas")
        summary = ttk.Frame(page)
        summary.pack(fill="x", pady=(0, 10))
        self.finance_summary = ttk.Label(summary, text="Consultando resumen financiero…")
        self.finance_summary.pack(side="left")
        ttk.Button(summary, text="Actualizar", command=self._load_finance).pack(
            side="right"
        )
        ttk.Button(
            summary,
            text="Exportar CSV",
            command=self._export_finance_csv,
        ).pack(side="right", padx=8)
        filters = ttk.Frame(page)
        filters.pack(fill="x", pady=(0, 8))
        self.finance_from = ttk.Entry(filters, width=16)
        self.finance_until = ttk.Entry(filters, width=16)
        ttk.Label(filters, text="Desde (AAAA-MM-DD)").pack(side="left")
        self.finance_from.pack(side="left", padx=(6, 14))
        ttk.Label(filters, text="Hasta (AAAA-MM-DD)").pack(side="left")
        self.finance_until.pack(side="left", padx=6)
        ttk.Button(filters, text="Filtrar pedidos entregados", command=self._load_finance).pack(
            side="left", padx=8
        )
        self.finance_table = self._tree(
            page,
            ("id", "fecha", "comercio", "cliente", "pago", "metodo", "comision", "envio", "estado"),
            ("Pedido", "Fecha", "Comercio", "Cliente", "Total", "Método", "Comisión", "Envío", "Estado"),
            (65, 145, 150, 140, 85, 105, 85, 85, 100),
        )
        self.finance_table.bind("<Double-1>", self._order_table_detail)
        self.finance_offset = 0
        controls = ttk.Frame(page)
        controls.pack(fill="x", pady=(8, 0))
        self.finance_page_status = ttk.Label(controls, text="")
        self.finance_page_status.pack(side="left")
        ttk.Button(controls, text="Anterior", command=self._finance_previous).pack(
            side="right", padx=4
        )
        ttk.Button(controls, text="Siguiente", command=self._finance_next).pack(
            side="right", padx=4
        )

    def _load_finance(self):
        self._fetch_async(
            "finance-summary",
            "/api/admin/finanzas_caja",
            self._render_finance_summary,
        )
        query = {
            "estado": "entregado",
            "offset": self.finance_offset,
            "limit": 100,
        }
        if self.finance_from.get().strip():
            query["desde"] = self.finance_from.get().strip()
        if self.finance_until.get().strip():
            query["hasta"] = self.finance_until.get().strip()
        self._fetch_async(
            "finance-orders",
            "/api/admin/pedidos_historial",
            self._render_finance_orders,
            query=query,
        )

    def _render_finance_summary(self, result):
        self.finance_summary.configure(
            text=(
                f"Acumulado de entregados: ventas ${result.get('volumen_total_ventas', 0):,.2f}  ·  "
                f"comisiones ${result.get('ganancia_comisiones_app', 0):,.2f}  ·  "
                f"tarifas ${result.get('pago_total_motoristas', 0):,.2f}  ·  "
                f"pedidos {result.get('pedidos_completados', 0)}"
            )
        )

    def _render_finance_orders(self, result):
        rows = result.get("pedidos", [])
        self._clear_tree(self.finance_table)
        for row in rows:
            self.finance_table.insert(
                "",
                "end",
                iid=str(row.get("id_pedido")),
                values=(
                    row.get("id_pedido", ""),
                    row.get("fecha_entrega") or row.get("fecha", ""),
                    row.get("comercio", ""),
                    row.get("cliente", ""),
                    row.get("total_pago", ""),
                    row.get("metodo_pago", ""),
                    row.get("comision_app", ""),
                    row.get("tarifa_envio", ""),
                    row.get("estado", ""),
                ),
            )
        total = int(result.get("total", 0))
        self.finance_page_status.configure(
            text=f"Detalle transaccional por pedido: {self.finance_offset + 1 if total else 0}–"
            f"{min(self.finance_offset + len(rows), total)} de {total}"
        )

    def _load_activity(self):
        results = {}

        def finish_if_ready():
            if len(results) != 2:
                return
            events = results["events"].get("eventos", [])
            audits = results["audits"].get("logs", [])
            combined = []
            for event in events:
                combined.append(
                    {
                        "fecha": event.get("fecha", ""),
                        "tipo": "Pedido",
                        "pedido": event.get("id_pedido", ""),
                        "actor": f"{event.get('actor_type', '')} {event.get('actor_id') or ''}".strip(),
                        "evento": (
                            f"{event.get('estado_anterior') or '—'} → "
                            f"{event.get('estado_nuevo', '')}"
                        ),
                        "motivo": event.get("motivo", ""),
                        "duracion": event.get("duracion_etapa_segundos"),
                        "detalle": event,
                    }
                )
            for audit in audits:
                combined.append(
                    {
                        "fecha": audit.get("fecha", ""),
                        "tipo": "Administración",
                        "pedido": audit.get("entity_id", "")
                        if audit.get("entity_type") == "pedido"
                        else "",
                        "actor": f"{audit.get('actor_role', '')} {audit.get('actor_id', '')}".strip(),
                        "evento": f"{audit.get('action', '')} · {audit.get('entity_type', '')}",
                        "motivo": audit.get("reason", ""),
                        "duracion": "",
                        "detalle": audit,
                    }
                )
            combined.sort(key=lambda row: row["fecha"], reverse=True)
            self.activity_rows.clear()
            self._clear_tree(self.activity_table)
            for index, item in enumerate(combined):
                iid = f"activity-{index}"
                self.activity_rows[iid] = item
                self.activity_table.insert(
                    "",
                    "end",
                    iid=iid,
                    values=(
                        item["fecha"],
                        item["tipo"],
                        item["pedido"],
                        item["actor"],
                        item["evento"],
                        item["motivo"],
                        item["duracion"],
                    ),
                )
            self._set_status(
                f"Actividad actualizada: {len(events)} eventos de pedidos y "
                f"{len(audits)} actos administrativos."
            )

        self._fetch_async(
            "activity-order-events",
            "/api/admin/eventos_pedido",
            lambda value: (results.update(events=value), finish_if_ready()),
            query={"offset": 0, "limit": 100},
        )
        self._fetch_async(
            "activity-admin-audit",
            "/api/admin/auditoria_logs",
            lambda value: (results.update(audits=value), finish_if_ready()),
            query={"offset": 0, "limit": 100},
        )

    def _activity_detail(self, _event=None):
        selected = self.activity_table.selection()
        if not selected:
            return
        item = self.activity_rows.get(selected[0])
        if item:
            if item["pedido"]:
                self._show_order_tracking(item["pedido"])
            else:
                self._show_json_window("Detalle de actividad", item["detalle"])

    def _finance_previous(self):
        self.finance_offset = max(0, self.finance_offset - 100)
        self._load_finance()

    def _finance_next(self):
        self.finance_offset += 100
        self._load_finance()

    def _export_finance_csv(self):
        destination = filedialog.asksaveasfilename(
            parent=self.root,
            title="Exportar pedidos entregados",
            defaultextension=".csv",
            filetypes=(("CSV", "*.csv"),),
        )
        if not destination:
            return
        query = {"estado": "entregado", "limit": 200}
        if self.finance_from.get().strip():
            query["desde"] = self.finance_from.get().strip()
        if self.finance_until.get().strip():
            query["hasta"] = self.finance_until.get().strip()

        def fetch_all():
            offset = 0
            result_rows = []
            while True:
                page = self.api.get(
                    "/api/admin/pedidos_historial",
                    {**query, "offset": offset},
                )
                page_rows = page.get("pedidos", [])
                result_rows.extend(page_rows)
                offset += len(page_rows)
                if not page_rows or offset >= int(page.get("total", 0)):
                    return result_rows

        def write_csv(rows):
            columns = (
                "id_pedido", "fecha", "fecha_entrega", "estado", "comercio",
                "cliente", "codigo_rastreo", "total_pago", "metodo_pago",
                "comision_app", "tarifa_envio", "id_repartidor",
            )
            try:
                with open(destination, "w", newline="", encoding="utf-8-sig") as output:
                    writer = csv.DictWriter(output, fieldnames=columns, extrasaction="ignore")
                    writer.writeheader()
                    writer.writerows(rows)
            except OSError as error:
                self._report_error("Exportación financiera", error)
                return
            messagebox.showinfo(
                "Exportación completada",
                f"Se exportaron {len(rows)} pedidos a:\n{destination}",
                parent=self.root,
            )

        self._run_async(
            "finance-export",
            fetch_all,
            write_csv,
            error_callback=lambda error: self._report_error(
                "Exportación financiera", error
            ),
        )

    def _build_audit_tab(self):
        page = ttk.Frame(self.notebook, padding=12)
        self.notebook.add(page, text="Auditoría")
        filters = ttk.Frame(page)
        filters.pack(fill="x", pady=(0, 10))
        self.audit_filters = {}
        definitions = (
            ("Desde (AAAA-MM-DD)", "desde", 14),
            ("Hasta (AAAA-MM-DD)", "hasta", 14),
            ("ID actor", "actor_id", 9),
            ("Entidad", "entidad", 14),
            ("Acción", "accion", 18),
        )
        for index, (label, key, width) in enumerate(definitions):
            field = ttk.Frame(filters)
            field.grid(row=0, column=index, padx=(0, 8), sticky="w")
            ttk.Label(field, text=label).pack(anchor="w")
            entry = ttk.Entry(field, width=width)
            entry.pack()
            self.audit_filters[key] = entry
        ttk.Button(filters, text="Buscar", command=self._load_audit).grid(
            row=0, column=len(definitions), padx=4, sticky="s"
        )
        self.audit_table = self._tree(
            page,
            ("fecha", "actor_id", "action", "entity_type", "entity_id", "ip", "reason"),
            ("Fecha", "Actor", "Acción", "Entidad", "ID", "IP", "Motivo"),
            (150, 70, 145, 105, 80, 120, 360),
        )
        self.audit_table.bind("<Double-1>", self._show_audit_detail)
        controls = ttk.Frame(page)
        controls.pack(fill="x", pady=(8, 0))
        self.audit_total = ttk.Label(controls, text="Sin consultar")
        self.audit_total.pack(side="left")
        ttk.Button(controls, text="Anterior", command=self._audit_previous).pack(
            side="right", padx=4
        )
        ttk.Button(controls, text="Siguiente", command=self._audit_next).pack(
            side="right", padx=4
        )
        self.audit_offset = 0
        self.audit_limit = 50
        self.audit_rows = {}

    def _build_directory_tab(self):
        page = ttk.Frame(self.notebook, padding=12)
        self.notebook.add(page, text="Directorio")
        toolbar = ttk.Frame(page)
        toolbar.pack(fill="x", pady=(0, 8))
        ttk.Label(toolbar, text="Usuarios y comercios").pack(side="left")
        ttk.Button(toolbar, text="Actualizar", command=self._load_directory).pack(
            side="right"
        )
        self.directory_metrics = ttk.Label(
            page,
            text="Contadores de operación: pendientes de consultar",
            style="Muted.TLabel",
        )
        self.directory_metrics.pack(anchor="w", pady=(0, 8))
        self.directory_table = self._tree(
            page,
            ("id", "tipo", "nombre", "rol", "estado", "telefono", "correo", "direccion", "latitud", "longitud"),
            ("ID", "Tipo", "Nombre", "Rol", "Estado", "Teléfono", "Correo", "Dirección", "Latitud", "Longitud"),
            (65, 95, 190, 95, 100, 120, 200, 240, 105, 105),
        )
        self.directory_rows = {}
        self.directory_table.bind("<Double-1>", self._show_directory_detail)

    def _load_directory(self):
        def render(result):
            rows = result.get("directorio", []) if isinstance(result, dict) else None
            if not isinstance(rows, list):
                raise AdminApiError("El backend devolvió un formato de directorio inválido.")
            self.directory_rows.clear()
            self._clear_tree(self.directory_table)
            for index, row in enumerate(rows):
                row_id = f"{row.get('tipo', 'registro')}-{row.get('id', index)}"
                self.directory_rows[row_id] = row
                self.directory_table.insert(
                    "",
                    "end",
                    iid=row_id,
                    values=(
                        row.get("id", ""),
                        row.get("tipo", ""),
                        row.get("nombre", ""),
                        row.get("rol", ""),
                        row.get("estado", ""),
                        row.get("telefono", ""),
                        row.get("correo", ""),
                        row.get("direccion", ""),
                        row.get("latitud") if row.get("latitud") is not None else "",
                        row.get("longitud") if row.get("longitud") is not None else "",
                    ),
                )
            self._set_status(f"Directorio cargado: {len(rows)} registros.")

        self._fetch_async(
            "directory",
            "/api/admin/directorio_completo",
            render,
            error_callback=lambda error: self._report_error(
                "Consulta de directorio", error
            ),
        )
        self._fetch_async(
            "directory-operational-metrics",
            "/api/admin/metricas_operativas",
            self._render_directory_metrics,
            error_callback=lambda error: self._report_error(
                "Métricas del directorio", error
            ),
        )

    def _render_directory_metrics(self, metrics):
        if not isinstance(metrics, dict):
            raise AdminApiError("El backend devolvió métricas operativas inválidas.")
        riders = metrics.get("repartidores", {})
        businesses = metrics.get("comercios", {})
        orders = metrics.get("pedidos", {})
        self.directory_metrics.configure(
            text=(
                f"Pedidos: {orders.get('activos', '—')} activos / "
                f"{orders.get('total', '—')} totales · "
                f"{orders.get('pendientes', '—')} pendientes     "
                f"Repartidores: {riders.get('activos', '—')} activos / "
                f"{riders.get('inactivos', '—')} inactivos     "
                f"Locales: {businesses.get('activos', '—')} activos / "
                f"{businesses.get('inactivos', '—')} inactivos"
            )
        )

    def _show_directory_detail(self, _event=None):
        selected = self.directory_table.selection()
        if selected:
            item = self.directory_rows.get(selected[0])
            if item:
                self._show_json_window("Detalle del directorio", item)

    def _audit_query(self):
        query = {
            key: field.get().strip()
            for key, field in self.audit_filters.items()
            if field.get().strip()
        }
        actor = query.get("actor_id")
        if actor:
            try:
                query["actor_id"] = str(int(actor))
            except ValueError:
                raise ValueError("El ID del actor debe ser numérico.")
        query.update(offset=str(self.audit_offset), limit=str(self.audit_limit))
        return query

    def _load_audit(self):
        try:
            query = self._audit_query()
        except ValueError as error:
            self._report_error("Consulta de auditoría", error)
            return

        def render(result):
            logs = result.get("logs", [])
            self.audit_rows.clear()
            self._clear_tree(self.audit_table)
            for item in logs:
                row_id = str(item.get("id", ""))
                self.audit_rows[row_id] = item
                self.audit_table.insert(
                    "",
                    "end",
                    iid=row_id or None,
                    values=(
                        item.get("fecha", ""),
                        item.get("actor_id", ""),
                        item.get("action", ""),
                        item.get("entity_type", ""),
                        item.get("entity_id", ""),
                        item.get("ip", ""),
                        item.get("reason", ""),
                    ),
                )
            total = int(result.get("total", 0))
            self.audit_total.configure(
                text=f"Registros {self.audit_offset + 1 if total else 0}–"
                f"{min(self.audit_offset + len(logs), total)} de {total}"
            )
            self._set_status("Bitácora cargada.")

        self._fetch_async(
            "audit-page",
            "/api/admin/auditoria_logs",
            render,
            query=query,
            error_callback=lambda error: self._report_error(
                "Consulta de auditoría", error
            ),
        )

    def _audit_previous(self):
        self.audit_offset = max(0, self.audit_offset - self.audit_limit)
        self._load_audit()

    def _audit_next(self):
        self.audit_offset += self.audit_limit
        self._load_audit()

    def _show_audit_detail(self, _event=None):
        selected = self.audit_table.selection()
        if not selected:
            return
        item = self.audit_rows.get(selected[0])
        if item:
            self._show_json_window("Detalle de auditoría", item)

    def _build_operations_tab(self):
        page = ttk.Frame(self.notebook, padding=18)
        self.notebook.add(page, text="Operaciones")
        ttk.Label(
            page,
            text="Las acciones críticas requieren un motivo y se registran en auditoría.",
            wraplength=850,
        ).pack(anchor="w", pady=(0, 14))

        body = ttk.Frame(page)
        body.pack(fill="both", expand=True)
        for index in range(2):
            body.columnconfigure(index, weight=1)
        for index in range(4):
            body.rowconfigure(index, weight=1)

        self._action_form(
            body,
            "Estado de comercio",
            ("ID comercio", "id"),
            ("Nuevo estado", "estado", ("pendiente", "activo", "cerrado", "suspendido", "archivado")),
            endpoint="/api/admin/juez_comercio",
            entity="comercio",
            position=(0, 0),
        )
        self._action_form(
            body,
            "Estado de repartidor",
            ("ID repartidor", "id"),
            ("Nuevo estado", "estado", ("pendiente", "activo", "suspendido", "archivado")),
            endpoint="/api/admin/juez_repartidor",
            entity="repartidor",
            position=(0, 1),
        )
        self._action_form(
            body,
            "Cancelar pedido",
            ("ID pedido", "id"),
            endpoint="/api/cancelar_pedido",
            entity="pedido",
            position=(1, 0),
        )
        self._action_form(
            body,
            "Archivar usuario",
            ("ID usuario", "id"),
            endpoint="/api/admin/eliminar_usuario",
            entity="usuario",
            position=(1, 1),
        )
        self._action_form(
            body,
            "Archivar comercio",
            ("ID comercio", "id"),
            endpoint="/api/admin/eliminar_comercio",
            entity="comercio",
            position=(2, 0),
        )

        bulk = ttk.LabelFrame(body, text="Cambiar estado de todos los comercios", padding=10)
        bulk.grid(row=2, column=1, sticky="nsew", padx=6, pady=6)
        state = ttk.Combobox(bulk, values=("activo", "cerrado"), state="readonly", width=22)
        state.set("cerrado")
        state.pack(anchor="w", pady=(0, 6))
        reason = ttk.Entry(bulk, width=48)
        reason.pack(fill="x", pady=(0, 6))
        reason.insert(0, "")
        ttk.Label(bulk, text="Motivo obligatorio").pack(anchor="w")
        ttk.Button(
            bulk,
            text="Aplicar cambio masivo",
            command=lambda: self._submit_bulk_state(state, reason),
        ).pack(anchor="w", pady=(8, 0))

        announcement = ttk.LabelFrame(body, text="Publicar anuncio global", padding=10)
        announcement.grid(row=3, column=0, columnspan=2, sticky="nsew", padx=6, pady=6)
        self.announcement_message = ttk.Entry(announcement)
        self.announcement_message.pack(fill="x", pady=(0, 6))
        self.announcement_message.insert(0, "")
        ttk.Label(announcement, text="Mensaje").pack(anchor="w")
        self.announcement_image = ttk.Entry(announcement)
        self.announcement_image.pack(fill="x", pady=(6, 0))
        ttk.Label(announcement, text="URL de imagen (opcional)").pack(anchor="w")
        self.announcement_reason = ttk.Entry(announcement)
        self.announcement_reason.pack(fill="x", pady=(6, 0))
        ttk.Label(announcement, text="Motivo obligatorio").pack(anchor="w")
        ttk.Button(
            announcement,
            text="Publicar anuncio",
            command=self._submit_announcement,
        ).pack(anchor="w", pady=(8, 0))

    def _action_form(
        self,
        parent,
        title,
        id_label,
        state_label=None,
        endpoint="",
        entity="",
        position=(0, 0),
    ):
        box = ttk.LabelFrame(parent, text=title, padding=10)
        box.grid(row=position[0], column=position[1], sticky="nsew", padx=6, pady=6)
        ttk.Label(box, text=id_label[0]).pack(anchor="w")
        identifier = ttk.Entry(box, width=28)
        identifier.pack(anchor="w", pady=(0, 6))
        state = None
        if state_label:
            ttk.Label(box, text=state_label[0]).pack(anchor="w")
            state = ttk.Combobox(box, values=state_label[2], state="readonly", width=25)
            state.set(state_label[2][0])
            state.pack(anchor="w", pady=(0, 6))
        ttk.Label(box, text="Motivo obligatorio").pack(anchor="w")
        reason = ttk.Entry(box)
        reason.pack(fill="x", pady=(0, 8))
        ttk.Button(
            box,
            text="Ejecutar acción",
            command=lambda: self._submit_entity_action(
                endpoint, entity, identifier, reason, state
            ),
        ).pack(anchor="w")

    def _submit_entity_action(self, endpoint, entity, identifier, reason, state):
        try:
            target_id = int(identifier.get().strip())
        except ValueError:
            messagebox.showerror("Dato inválido", "El ID debe ser un entero.", parent=self.root)
            return
        audit_reason = reason.get().strip()
        if len(audit_reason) < 5:
            messagebox.showerror(
                "Motivo requerido",
                "Escribe un motivo de al menos 5 caracteres.",
                parent=self.root,
            )
            return
        if not messagebox.askyesno(
            "Confirmar operación",
            f"¿Confirmas la acción sobre {entity} ID {target_id}?\n\nMotivo: {audit_reason}",
            parent=self.root,
        ):
            return
        if endpoint == "/api/cancelar_pedido":
            payload = {"id_pedido": target_id, "motivo": audit_reason}
        else:
            payload = {"id_objetivo": target_id, "motivo": audit_reason}
            if state is not None:
                payload["nuevo_estado"] = state.get()
        self._run_operation(endpoint, payload)

    def _submit_bulk_state(self, state, reason):
        audit_reason = reason.get().strip()
        if len(audit_reason) < 5:
            messagebox.showerror(
                "Motivo requerido",
                "Escribe un motivo de al menos 5 caracteres.",
                parent=self.root,
            )
            return
        if messagebox.askyesno(
            "Confirmar cambio masivo",
            f"Se cambiará el estado de todos los comercios a {state.get()}.\n"
            f"Motivo: {audit_reason}\n\n¿Continuar?",
            parent=self.root,
        ):
            self._run_operation(
                "/api/admin/estado_masivo_comercios",
                {"estado": state.get(), "motivo": audit_reason},
            )

    def _submit_announcement(self):
        message = self.announcement_message.get().strip()
        reason = self.announcement_reason.get().strip()
        if not message or len(reason) < 5:
            messagebox.showerror(
                "Datos requeridos",
                "Indica el mensaje y un motivo de al menos 5 caracteres.",
                parent=self.root,
            )
            return
        if messagebox.askyesno(
            "Confirmar anuncio",
            "El anuncio se publicará para toda la red. ¿Continuar?",
            parent=self.root,
        ):
            self._run_operation(
                "/api/admin/publicar_anuncio",
                {
                    "mensaje": message,
                    "imagen_url": self.announcement_image.get().strip(),
                    "motivo": reason,
                },
            )

    def _run_operation(self, endpoint, payload):
        def completed(result):
            self._set_status(f"Operación completada: {self._pretty(result)}")
            messagebox.showinfo(
                "Operación completada", self._pretty(result), parent=self.root
            )
            self._load_dashboard()
            self._load_audit()
            self._load_support()

        self._run_async(
            f"operation-{endpoint}",
            lambda: self.api.post(endpoint, payload),
            completed,
            error_callback=lambda error: self._report_error(
                "La operación no se completó", error
            ),
        )

    def _build_support_tab(self):
        page = ttk.Frame(self.notebook, padding=12)
        self.notebook.add(page, text="Soporte")
        toolbar = ttk.Frame(page)
        toolbar.pack(fill="x", pady=(0, 8))
        ttk.Label(
            toolbar,
            text="CENTRO DE ATENCIÓN  /  expedientes de cliente, comercio y repartidor",
            style="Section.TLabel",
        ).pack(side="left")
        ttk.Button(toolbar, text="Actualizar", command=self._load_support).pack(
            side="right"
        )
        filters = ttk.Frame(page)
        filters.pack(fill="x", pady=(0, 8))
        ttk.Label(filters, text="Buscar pedido, código o reporte").pack(side="left")
        self.support_search = ttk.Entry(filters, width=42)
        self.support_search.pack(side="left", padx=8)
        self.support_search.bind(
            "<KeyRelease>", lambda _event: self._render_support_rows()
        )
        ttk.Label(filters, text="Estado").pack(side="left", padx=(12, 4))
        self.support_state_filter = ttk.Combobox(
            filters,
            values=("Todos", "abierto", "resuelto", "archivado"),
            state="readonly",
            width=14,
        )
        self.support_state_filter.set("Todos")
        self.support_state_filter.pack(side="left")
        self.support_state_filter.bind(
            "<<ComboboxSelected>>", lambda _event: self._render_support_rows()
        )
        self.support_table = self._tree(
            page,
            ("id_ticket", "id_pedido", "codigo_rastreo", "canal", "tipo_usuario", "estado", "fecha", "mensajes_nuevos", "queja", "archivado"),
            ("Ticket", "Pedido", "Rastreo", "Canal", "Actor", "Estado", "Actividad", "Nuevos", "Detalle", "Archivado"),
            (70, 70, 120, 150, 100, 100, 150, 65, 360, 80),
        )
        self.support_table.tag_configure("abierto", background=COLORS["amber_pale"])
        self.support_table.tag_configure("resuelto", foreground=COLORS["green"])
        self.support_table.tag_configure("archivado", foreground=COLORS["muted"])
        self.support_table.tag_configure("unread", font=("Segoe UI", 9, "bold"))
        actions = ttk.Frame(page)
        actions.pack(fill="x", pady=(8, 0))
        ttk.Button(
            actions,
            text="Abrir conversación",
            command=self._open_support_conversation,
        ).pack(side="left", padx=(0, 8))
        ttk.Button(
            actions,
            text="Ver expediente",
            command=self._show_support_detail,
        ).pack(side="left", padx=(0, 8))
        ttk.Button(
            actions,
            text="Ver pedido en mapa",
            command=self._focus_selected_support_order,
        ).pack(side="left", padx=(0, 8))
        ttk.Button(
            actions,
            text="Resolver seleccionado",
            command=lambda: self._support_action("resolver"),
        ).pack(side="left", padx=(0, 8))
        ttk.Button(
            actions,
            text="Archivar expediente",
            command=lambda: self._support_action("archivar"),
        ).pack(side="left")
        self.support_rows = {}
        self.support_table.bind("<Double-1>", self._show_support_detail)

    def _load_support(self):
        def render(rows):
            if not isinstance(rows, list) or not all(
                isinstance(row, dict) for row in rows
            ):
                raise AdminApiError(
                    "El backend devolvió un formato de tickets inválido."
                )
            self.support_rows.clear()
            for row in rows:
                ticket_id = str(row.get("id_ticket", ""))
                self.support_rows[ticket_id] = row
            self._render_support_rows()
            self._set_status(f"Tickets cargados: {len(rows)}.")

        self._fetch_async(
            "support-tickets",
            "/api/admin/tickets_soporte",
            render,
            error_callback=lambda error: self._report_error(
                "Consulta de soporte", error
            ),
        )

    def _render_support_rows(self):
        if not hasattr(self, "support_table"):
            return
        state = self.support_state_filter.get()
        search = self.support_search.get().strip().casefold()
        self._clear_tree(self.support_table)
        for ticket_id, row in self.support_rows.items():
            ticket_state = row.get("estado", "")
            if state != "Todos" and ticket_state != state:
                continue
            searchable = " ".join(
                str(row.get(field, ""))
                for field in (
                    "id_ticket",
                    "id_pedido",
                    "tipo_usuario",
                    "queja",
                    "codigo_rastreo",
                    "canal",
                    "nombre_cliente",
                    "nombre_comercio",
                    "nombre_repartidor",
                )
            ).casefold()
            if search and search not in searchable:
                continue
            self.support_table.insert(
                "",
                "end",
                iid=ticket_id or None,
                tags=tuple(
                    tag
                    for tag, enabled in (
                        (str(ticket_state), True),
                        ("unread", int(row.get("mensajes_nuevos", 0) or 0) > 0),
                    )
                    if enabled
                ),
                values=(
                    ticket_id,
                    row.get("id_pedido", ""),
                    row.get("codigo_rastreo", ""),
                    support_channel_label(row.get("canal")),
                    row.get("tipo_usuario", ""),
                    ticket_state,
                    row.get("ultima_actividad") or row.get("fecha", ""),
                    row.get("mensajes_nuevos", 0),
                    row.get("queja", ""),
                    "Sí" if row.get("archivado") else "No",
                ),
            )

    def _open_support_conversation(self):
        selected = self.support_table.selection()
        if not selected:
            messagebox.showwarning(
                "Selecciona un expediente",
                "Selecciona un ticket para abrir su conversación.",
                parent=self.root,
            )
            return
        ticket_id = int(selected[0])
        ticket = self.support_rows.get(str(ticket_id), {})
        archived = bool(ticket.get("archivado")) or ticket.get("estado") == "archivado"
        window = tk.Toplevel(self.root)
        window.title(
            f"Atención de soporte · Ticket {ticket_id} · Pedido {ticket.get('id_pedido', '')}"
        )
        window.geometry("820x700")
        window.minsize(640, 520)
        window.transient(self.root)
        window.configure(background=COLORS["canvas"])

        banner = tk.Frame(window, background=COLORS["navy"], padx=18, pady=14)
        banner.pack(fill="x")
        tk.Label(
            banner,
            text=f"CASO #{ticket_id}  ·  PEDIDO #{ticket.get('id_pedido', '')}",
            background=COLORS["navy"],
            foreground=COLORS["surface"],
            font=("Segoe UI", 13, "bold"),
        ).pack(anchor="w")
        tk.Label(
            banner,
            text=(
                f"{ticket.get('tipo_usuario', 'Usuario')}  ·  "
                f"{ticket.get('nombre_cliente', '')}  ·  "
                f"{support_channel_label(ticket.get('canal'))}  ·  "
                f"{ticket.get('codigo_rastreo', '')}  ·  "
                f"{ticket.get('telefono', '')}"
            ),
            background=COLORS["navy"],
            foreground="#C8D5E3",
            font=("Segoe UI", 9),
        ).pack(anchor="w", pady=(5, 0))
        if int(ticket.get("id_pedido") or 0) > 0:
            ttk.Button(
                banner,
                text="Ver ubicaciones del pedido en el mapa",
                command=lambda: self._focus_order_on_radar(
                    ticket.get("id_pedido")
                ),
            ).pack(anchor="w", pady=(8, 0))

        conversation = tk.Text(
            window,
            wrap="word",
            state="disabled",
            background=COLORS["surface"],
            foreground=COLORS["text"],
            relief="flat",
            padx=14,
            pady=12,
            font=("Segoe UI", 10),
        )
        conversation.pack(fill="both", expand=True, padx=14, pady=14)

        compose = ttk.LabelFrame(window, text="Respuesta de la central", padding=10)
        compose.pack(fill="x", padx=14, pady=(0, 14))
        message = tk.Text(compose, height=4, wrap="word", font=("Segoe UI", 10))
        message.pack(fill="x", pady=(0, 8))
        reason = ttk.Entry(compose)
        reason.pack(fill="x")
        ttk.Label(
            compose,
            text=(
                "Expediente archivado: conversación de solo lectura."
                if archived
                else "Motivo de auditoría requerido para enviar la respuesta."
            ),
            style="Muted.TLabel",
        ).pack(anchor="w", pady=(4, 8))
        button_row = ttk.Frame(compose)
        button_row.pack(fill="x")
        state = {
            "sending": False,
            "closed": False,
            "after_id": None,
            "message_ids": None,
        }

        def render_thread(result):
            if not window.winfo_exists() or state["closed"]:
                return
            if not isinstance(result, dict) or not isinstance(
                result.get("mensajes"), list
            ):
                self._set_status("El backend devolvió una conversación inválida.")
                return
            messages = result.get("mensajes", [])
            if not all(isinstance(item, dict) for item in messages):
                self._set_status("El backend devolvió mensajes de soporte inválidos.")
                return
            message_ids = tuple(item.get("id") for item in messages)
            if message_ids == state["message_ids"]:
                return
            was_near_bottom = conversation.yview()[1] >= 0.98
            conversation.configure(state="normal")
            conversation.delete("1.0", tk.END)
            for item in messages:
                sender = item.get("remitente", "Usuario")
                timestamp = item.get("fecha", "")
                marker = "  ·  ARCHIVADO" if item.get("archivado") else ""
                conversation.insert(
                    tk.END,
                    f"{sender}  ·  {timestamp}{marker}\n",
                    ("heading",),
                )
                conversation.insert(tk.END, f"{item.get('mensaje', '')}\n\n")
            conversation.tag_configure(
                "heading",
                foreground=COLORS["blue"],
                font=("Segoe UI", 9, "bold"),
            )
            conversation.configure(state="disabled")
            state["message_ids"] = message_ids
            if was_near_bottom or len(message_ids) <= 1:
                conversation.see(tk.END)

        def refresh_thread():
            if not window.winfo_exists() or state["closed"]:
                return
            self._fetch_async(
                f"support-thread-{ticket_id}",
                f"/api/admin/tickets_soporte/{ticket_id}/mensajes",
                render_thread,
                error_callback=lambda error: self._set_status(
                    f"No se pudo actualizar la conversación: {error}"
                ),
            )

        def poll_thread():
            state["after_id"] = None
            if not window.winfo_exists() or state["closed"]:
                return
            refresh_thread()
            state["after_id"] = window.after(3000, poll_thread)

        def close_conversation():
            state["closed"] = True
            if state["after_id"] is not None:
                window.after_cancel(state["after_id"])
                state["after_id"] = None
            window.destroy()

        window.protocol("WM_DELETE_WINDOW", close_conversation)

        def send_reply():
            content = message.get("1.0", tk.END).strip()
            audit_reason = reason.get().strip()
            if not content:
                messagebox.showerror(
                    "Respuesta vacía",
                    "Escribe el mensaje antes de enviarlo.",
                    parent=window,
                )
                return
            if len(audit_reason) < 5:
                messagebox.showerror(
                    "Motivo requerido",
                    "Escribe un motivo de auditoría de al menos 5 caracteres.",
                    parent=window,
                )
                return
            if not messagebox.askyesno(
                "Confirmar respuesta",
                "Enviar esta respuesta al usuario y registrar el motivo en auditoría?",
                parent=window,
            ):
                return
            if state["sending"]:
                return
            state["sending"] = True
            send_button.configure(state="disabled")

            def sent(_result):
                state["sending"] = False
                if window.winfo_exists():
                    send_button.configure(state="normal")
                    message.delete("1.0", tk.END)
                    reason.delete(0, tk.END)
                    refresh_thread()
                    self._load_support()

            def send_error(error):
                state["sending"] = False
                if window.winfo_exists():
                    send_button.configure(state="normal")
                    self._report_error("No se pudo enviar la respuesta", error)

            self._run_async(
                f"support-reply-{ticket_id}",
                lambda: self.api.post(
                    f"/api/admin/tickets_soporte/{ticket_id}/mensajes",
                    {"mensaje": content, "motivo": audit_reason},
                ),
                sent,
                error_callback=send_error,
            )

        send_button = ttk.Button(
            button_row,
            text="Enviar respuesta",
            style="Primary.TButton",
            command=send_reply,
        )
        send_button.pack(side="right")
        if archived:
            message.configure(state="disabled")
            reason.configure(state="disabled")
            send_button.configure(state="disabled")
        ttk.Button(
            button_row,
            text="Actualizar conversación",
            command=refresh_thread,
        ).pack(side="left")
        refresh_thread()
        state["after_id"] = window.after(3000, poll_thread)

    def _show_support_detail(self, _event=None):
        selected = self.support_table.selection()
        if not selected:
            messagebox.showwarning(
                "Selecciona un ticket",
                "Selecciona un expediente de soporte.",
                parent=self.root,
            )
            return
        item = self.support_rows.get(selected[0])
        if item:
            self._show_json_window(
                f"Expediente del ticket {selected[0]}",
                item,
            )

    def _support_action(self, action):
        selected = self.support_table.selection()
        if not selected:
            messagebox.showwarning(
                "Selecciona un ticket", "Selecciona un expediente de la lista.", parent=self.root
            )
            return
        ticket_id = int(selected[0])
        reason = simpledialog.askstring(
            "Motivo de auditoría",
            f"Motivo para {action} el ticket {ticket_id}:",
            parent=self.root,
        )
        if reason is None:
            return
        if len(reason.strip()) < 5:
            messagebox.showerror(
                "Motivo requerido",
                "Escribe un motivo de al menos 5 caracteres.",
                parent=self.root,
            )
            return
        endpoint = (
            f"/api/admin/resolver_ticket/{ticket_id}"
            if action == "resolver"
            else f"/api/admin/archivar_ticket/{ticket_id}"
        )
        self._run_operation(endpoint, {"motivo": reason.strip()})
        self._load_support()

    def _tree(self, parent, keys, labels, widths):
        wrapper = ttk.Frame(parent)
        wrapper.pack(fill="both", expand=True)
        tree = ttk.Treeview(wrapper, columns=keys, show="headings")
        yscroll = ttk.Scrollbar(wrapper, orient="vertical", command=tree.yview)
        xscroll = ttk.Scrollbar(wrapper, orient="horizontal", command=tree.xview)
        tree.configure(yscrollcommand=yscroll.set, xscrollcommand=xscroll.set)
        for key, label, width in zip(keys, labels, widths):
            tree.heading(key, text=label)
            tree.column(key, width=width, minwidth=60, stretch=key in {"reason", "queja"})
        tree.grid(row=0, column=0, sticky="nsew")
        yscroll.grid(row=0, column=1, sticky="ns")
        xscroll.grid(row=1, column=0, sticky="ew")
        wrapper.rowconfigure(0, weight=1)
        wrapper.columnconfigure(0, weight=1)
        return tree

    @staticmethod
    def _clear_tree(tree):
        for row_id in tree.get_children():
            tree.delete(row_id)

    def _show_json_window(self, title, value):
        window = tk.Toplevel(self.root)
        window.title(title)
        window.geometry("820x600")
        text = tk.Text(window, wrap="none")
        text.pack(fill="both", expand=True, padx=10, pady=10)
        text.insert("1.0", self._pretty(value))
        text.configure(state="disabled")


def main():
    root = tk.Tk()
    AdminDesktopApp(root)
    root.mainloop()


if __name__ == "__main__":
    main()
