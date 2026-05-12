defmodule Inmobiliaria.SessionHandler do
  # --- Comandos base (aridad 1) ---
  # comandos que se pueden ejecutar sin pasar rol (register, connect, online)

  def execute_command(["register", username, password, role]),
    do: Inmobiliaria.UserManager.register(username, password, role)

  def execute_command(["connect", username, password]),
    do: Inmobiliaria.UserManager.login(username, password)

  def execute_command(["online"]),
    do: {:ok, Inmobiliaria.UserManager.online_users()}

  # Comando desconocido (aridad 1)
  def execute_command(_),
    do: {:error, "Comando no reconocido"}

  # --- Comandos que requieren validación de rol (aridad 2) ---

  def execute_command(["publish_property" | _args], role) do
    case validate_role(role, ["vendedor", "arrendador"]) do
      :ok -> {:ok, "[Módulo pendiente] Publicar propiedad"}
      {:error, reason} -> {:error, reason}
    end
  end

  def execute_command(["list_properties" | _args], _role) do
    {:ok, "[Módulo pendiente] Listar propiedades"}
  end

  def execute_command(["buy_property" | _args], role) do
    case validate_role(role, ["cliente"]) do
      :ok -> {:ok, "[Módulo pendiente] Comprar propiedad"}
      {:error, reason} -> {:error, reason}
    end
  end

  def execute_command(["rent_property" | _args], role) do
    case validate_role(role, ["cliente"]) do
      :ok -> {:ok, "[Módulo pendiente] Arrendar propiedad"}
      {:error, reason} -> {:error, reason}
    end
  end

  def execute_command(["send_message" | _args], _role) do
    {:ok, "[Módulo pendiente] Enviar mensaje"}
  end

  def execute_command(["read_messages" | _args], _role) do
    {:ok, "[Módulo pendiente] Leer mensajes"}
  end

  def execute_command(["ranking" | _args], _role) do
    case Inmobiliaria.UserManager.ranking() do
      {:ok, ranking_list} ->
        formatted = Enum.map_join(ranking_list, "\n", fn {user, score} -> "  #{user}: #{score} pts" end)
        {:ok, "Ranking:\n#{formatted}"}
      {:error, err} ->
        {:error, err}
    end
  end

  def execute_command(["my_score", _username], _role) do
    {:ok, "[Módulo pendiente] Mi puntuación"}
  end

  def execute_command(_, _role),
    do: {:error, "Comando no reconocido"}

  # --- Validación de rol ---

  defp validate_role(user_role, required_roles) do
    if user_role in required_roles do
      :ok
    else
      {:error, "Permiso denegado. Rol requerido: #{Enum.join(required_roles, ", ")}. Tu rol: #{user_role}"}
    end
  end
end
