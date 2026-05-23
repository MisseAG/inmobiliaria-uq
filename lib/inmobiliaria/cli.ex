defmodule Inmobiliaria.CLI do
  alias Inmobiliaria.CLI.UI
  def start do
    UI.print_welcome()
    loop(nil, nil)
  end

  defp loop(username, role) do
    input =
      username
      |> UI.build_prompt(role)
      |> IO.gets()
      |> String.trim()
      |> String.split(" ", trim: true)

    case process_input(input, username, role) do
      {:ok, :exit} ->
        UI.warn("Saliendo del sistema...")

      {:ok, :disconnect} ->
        UI.success("Sesión cerrada. Volviendo al menú principal...")
        Process.sleep(800)
        start()

      {:ok, new_user, new_role, msg} ->
        UI.success(msg)
        loop(new_user, new_role)

      {:error, reason} ->
        UI.error(reason)
        loop(username, role)
    end
  end

  # ── Comandos sin sesión ────────────────────────────────────────────────────

  defp process_input(["register", u, p, r], nil, nil) do
    case Inmobiliaria.UserManager.register(u, p, r) do
      {:ok, msg}    -> {:ok, nil, nil, "✓ #{msg}"}
      {:error, err} -> {:error, err}
    end
  end

  defp process_input(["connect", u, p], nil, _role) do
    case Inmobiliaria.UserManager.login(u, p) do
      {:ok, user_role} -> {:ok, u, user_role, "Bienvenido #{u}. Rol: #{user_role}"}
      {:error, err}    -> {:error, err}
    end
  end

  defp process_input(["online"], username, role) do
    lista = Inmobiliaria.UserManager.online_users()
    {:ok, username, role, "Usuarios en línea: #{Enum.join(lista, ", ")}"}
  end

  defp process_input(["exit"], username, _role) do
    if username, do: Inmobiliaria.UserManager.logout(username)
    {:ok, :exit}
  end

  defp process_input(["disconnect"], username, _role) do
    if username do
      Inmobiliaria.UserManager.logout(username)
      {:ok, :disconnect}
    else
      {:error, "No hay ninguna sesión activa para desconectar."}
    end
  end

  # ── Comandos autenticados ──────────────────────────────────────────────────
  # Se pasa username y role a SessionHandler para que pueda asignar puntos,
  # registrar operaciones y consultar el score del usuario actual.

  defp process_input(input, username, role) when username != nil do
    cleaned_input = Enum.map(input, &String.replace(&1, ~r/[<>]/, ""))
    case Inmobiliaria.SessionHandler.execute_command(cleaned_input, username, role) do
      {:ok, msg}    -> {:ok, username, role, msg}
      {:error, err} -> {:error, err}
    end
  end

  # ── Sin sesión activa ──────────────────────────────────────────────────────

  defp process_input(cmd, nil, nil) do
    if is_known_command?(cmd) do
      {:error, "Debe conectarse primero (usa 'connect <usuario> <clave>')"}
    else
      {:error, "Comando desconocido"}
    end
  end

  # ── Validación de comandos conocidos ───────────────────────────────────────

  defp is_known_command?([cmd | _]) do
    cmd in [
      # Comandos que requieren sesión
      "publish_property", "list_properties", "buy_property", "rent_property",
      "send_message", "read_messages", "ranking", "my_score"
    ]
  end

  defp is_known_command?(_), do: false
end
