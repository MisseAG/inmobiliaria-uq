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

  def execute_command(["publish_property", tipo, ubicacion, precio, habitaciones, area], role) do
    case validate_role(role, ["vendedor", "arrendador"]) do
      :ok ->
        case publish_property_impl(tipo, ubicacion, precio, habitaciones, area) do
          {:ok, pid, id} ->
            {:ok, "✓ Propiedad publicada. ID: #{id}, PID: #{inspect(pid)}"}
          {:error, reason} ->
            {:error, "Error publicando propiedad: #{reason}"}
        end
      {:error, reason} -> {:error, reason}
    end
  end

  def execute_command(["publish_property" | _args], role) do
    case validate_role(role, ["vendedor", "arrendador"]) do
      :ok ->
        {:error, "Uso: publish_property <tipo> <ubicacion> <precio> <habitaciones> <area>"}
      {:error, reason} -> {:error, reason}
    end
  end

  def execute_command(["list_properties" | _args], _role) do
    case list_properties_impl() do
      {:ok, properties} ->
        formatted = format_properties_list(properties)
        {:ok, formatted}
      {:error, reason} ->
        {:error, "Error listando propiedades: #{reason}"}
    end
  end

  def execute_command(["buy_property", id], role) do
    case validate_role(role, ["cliente"]) do
      :ok ->
        case Inmobiliaria.Property.reserve(id) do
          {:ok, info} ->
            {:ok, "✓ Propiedad #{id} reservada para compra.\n#{format_property_info(info)}"}
          {:error, reason} ->
            {:error, "No se pudo reservar: #{reason}"}
        end
      {:error, reason} -> {:error, reason}
    end
  end

  def execute_command(["rent_property", id, _meses], role) do
    case validate_role(role, ["cliente"]) do
      :ok ->
        case Inmobiliaria.Property.reserve(id) do
          {:ok, info} ->
            {:ok, "✓ Propiedad #{id} reservada para arriendo.\n#{format_property_info(info)}"}
          {:error, reason} ->
            {:error, "No se pudo reservar: #{reason}"}
        end
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

  # --- Implementaciones de comandos ---

  defp publish_property_impl(tipo, ubicacion, precio_str, hab_str, area_str) do
    precio = parse_number(precio_str)
    habitaciones = parse_integer(hab_str)
    area = parse_number(area_str)

    cond do
      is_nil(precio) -> {:error, "Precio debe ser un número válido"}
      is_nil(habitaciones) -> {:error, "Habitaciones debe ser un número entero válido"}
      is_nil(area) -> {:error, "Área debe ser un número válido"}
      true ->
        id = generate_property_id()
        attrs = %{
          "id" => id,
          "tipo" => tipo,
          "modalidad" => "venta",
          "ubicacion" => ubicacion,
          "precio" => precio,
          "habitaciones" => habitaciones,
          "area" => area,
          "propietario" => "admin",
          "estado" => "disponible"
        }
        Inmobiliaria.PropertyManager.publish(attrs)
    end
  end

  defp list_properties_impl do
    properties = Inmobiliaria.PropertyManager.list_all()
    {:ok, properties}
  end

  defp generate_property_id do
    "prop_#{:os.system_time(:millisecond)}"
  end

  defp parse_number(str) do
    case Float.parse(str) do
      {num, ""} -> num
      _ -> nil
    end
  end

  defp parse_integer(str) do
    case Integer.parse(str) do
      {num, ""} -> num
      _ -> nil
    end
  end

  defp format_properties_list(properties) when is_list(properties) and length(properties) > 0 do
    formatted = Enum.map_join(properties, "\n", &format_property/1)
    "Propiedades disponibles:\n#{formatted}"
  end

  defp format_properties_list(_) do
    "No hay propiedades registradas."
  end

  defp format_property(prop) do
    "  [#{prop.id}] #{prop.tipo} en #{prop.ubicacion} - $#{prop.precio} (#{prop.estado})"
  end

  defp format_property_info(info) do
    "Tipo: #{info.tipo}\nModalidad: #{info.modalidad}\nUbicación: #{info.ubicacion}\nPrecio: $#{info.precio}"
  end
end
