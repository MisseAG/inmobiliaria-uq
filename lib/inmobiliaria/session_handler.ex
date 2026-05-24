defmodule Inmobiliaria.SessionHandler do
  @moduledoc """
  Despacha comandos autenticados al módulo correspondiente.
  Recibe (cmd, username, role) para todos los comandos que requieren saber
  quién ejecuta la acción (compra, arriendo, mensajes, puntos, my_score).
  """

  # ── Comandos sin autenticación (aridad 1) ─────────────────────────────────

  def execute_command(["register", username, password, role]),
    do: Inmobiliaria.UserManager.register(username, password, role)

  def execute_command(["connect", username, password]),
    do: Inmobiliaria.UserManager.login(username, password)

  def execute_command(["online"]),
    do: {:ok, Enum.join(Inmobiliaria.UserManager.online_users(), ", ")}

  def execute_command(_),
    do: {:error, "Comando no reconocido"}

  # ── Comandos autenticados (aridad 3: cmd, username, role) ─────────────────

  # ---- publish_property ----

  def execute_command(
        ["publish_property", tipo, ubicacion, precio, habitaciones, area],
        username,
        role
      ) do
    with :ok <- validate_role(role, ["vendedor", "arrendador"]),
         {:ok, pid, id} <-
           publish_property_impl(tipo, ubicacion, precio, habitaciones, area, username) do
      {:ok, "✓ Propiedad publicada. ID: #{id}, PID: #{inspect(pid)}"}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  def execute_command(["publish_property" | _], _username, role) do
    case validate_role(role, ["vendedor", "arrendador"]) do
      :ok   -> {:error, "Uso: publish_property <tipo> <ubicacion> <precio> <habitaciones> <area>"}
      error -> error
    end
  end

  # ---- list_properties ----

  def execute_command(["list_properties" | _], _username, _role) do
    propiedades = Inmobiliaria.PropertyManager.list_all()
    disponibles = Enum.filter(propiedades, &(&1.estado == :disponible))
    if Enum.empty?(disponibles) do
      {:ok, "No hay propiedades disponibles para compra en este momento."}
    else
      {:ok, format_properties_list(disponibles)}
    end
  end

  # ---- buy_property ----

  def execute_command(["buy_property", prop_id], username, role) do
    with :ok <- validate_role(role, ["cliente"]),
         {:ok, info} <- Inmobiliaria.PropertyServer.get_info(prop_id),
         {:ok, new_state} <- Inmobiliaria.PropertyServer.buy(prop_id, username, info.propietario) do
      mensaje = """
      ✓ Propiedad #{prop_id} comprada exitosamente.
        Tipo: #{new_state.tipo} | Ubicación: #{new_state.ubicacion}
        Precio: $#{new_state.precio}
        +10 puntos para ti | +15 puntos para #{info.propietario}
      """
      {:ok, String.trim(mensaje)}
    end
  end

  def execute_command(["buy_property" | _], _username, role) do
    case validate_role(role, ["cliente"]) do
      :ok   -> {:error, "Uso: buy_property <id>"}
      error -> error
    end
  end

  # ---- rent_property ----

  def execute_command(["rent_property", prop_id, meses_str], username, role) do
    with :ok <- validate_role(role, ["cliente"]),
         {meses, ""} <- Integer.parse(meses_str),
         {:ok, info} <- Inmobiliaria.PropertyServer.get_info(prop_id),
         {:ok, new_state} <- Inmobiliaria.PropertyServer.rent(prop_id, meses, username, info.propietario) do
      mensaje = """
      ✓ Propiedad #{prop_id} arrendada por #{meses} mes(es).
        Tipo: #{new_state.tipo} | Ubicación: #{new_state.ubicacion}
        Precio mensual: $#{new_state.precio}
        +10 puntos para ti | +15 puntos para #{info.propietario}
      """
      {:ok, String.trim(mensaje)}
    end
  end

  def execute_command(["rent_property" | _], _username, role) do
    case validate_role(role, ["cliente"]) do
      :ok   -> {:error, "Uso: rent_property <id> <meses>"}
      error -> error
    end
  end

  # ---- send_message ----
  # Sintaxis: send_message <prop_id> <mensaje con espacios>
  # Lógica de receptor:
  #   - Si propiedad está :disponible → envía al propietario (cliente → vendedor)
  #   - Si propiedad está :vendida → envía al cliente_comprador (vendedor → cliente)
  #   - Si propiedad está :arrendada → envía al cliente_arrendatario (vendedor → cliente)

  def execute_command(["send_message", prop_id | resto], username, _role) when resto != [] do
    mensaje = Enum.join(resto, " ")

    case Inmobiliaria.PropertyServer.get_info(prop_id) do
      {:ok, info} ->
        receptor = determine_receptor(info)
        case Inmobiliaria.MessageManager.send_message(prop_id, username, receptor, mensaje) do
          :ok ->
            {:ok, "✓ Mensaje enviado a #{receptor} sobre la propiedad #{prop_id}."}
          {:error, reason} ->
            {:error, "No se pudo enviar el mensaje: #{reason}"}
        end
      {:error, _} ->
        {:error, "Propiedad #{prop_id} no encontrada o no está activa."}
    end
  end

  def execute_command(["send_message" | _], _username, _role) do
    {:error, "Uso: send_message <prop_id> <mensaje>"}
  end

  # ---- send_message_to (mensaje directo a cliente) ----

  def execute_command(["send_message_to", cliente | resto], username, _role) when resto != [] do
    mensaje = Enum.join(resto, " ")

    case Inmobiliaria.MessageManager.send_message("DIRECT", username, cliente, mensaje) do
      :ok ->
        {:ok, "✓ Mensaje enviado directamente a #{cliente}."}
      {:error, reason} ->
        {:error, "No se pudo enviar el mensaje: #{reason}"}
    end
  end

  def execute_command(["send_message_to" | _], _username, _role) do
    {:error, "Uso: send_message_to <cliente> <mensaje>"}
  end

  def execute_command(["read_messages"], username, _role) do
    with {:ok, mensajes} <- Inmobiliaria.MessageManager.read_messages(username) do
      if Enum.empty?(mensajes) do
        {:ok, "No tienes mensajes."}
      else
        texto = Enum.join(mensajes, "\n")
        {:ok, "── Tus mensajes ──\n#{texto}"}
      end
    else
      {:error, reason} -> {:error, reason}
    end
  end

  # ---- ranking global ----

  def execute_command(["ranking"], _username, _role) do
    case Inmobiliaria.UserManager.ranking() do
      {:ok, lista} ->
        if Enum.empty?(lista) do
          {:ok, "No hay usuarios registrados."}
        else
          texto =
            lista
            |> Enum.with_index(1)
            |> Enum.map_join("\n", fn {{user, score, role}, pos} ->
              "  #{pos}. #{user} (#{role}): #{score} pts"
            end)
          {:ok, "── Ranking global ──\n#{texto}"}
        end
      {:error, reason} ->
        {:error, reason}
    end
  end

  # ---- ranking por rol ----

  def execute_command(["ranking", rol_arg], _username, _role) do
    role = case String.downcase(rol_arg) do
      "clientes"     -> "cliente"
      "vendedores"   -> "vendedor"
      "arrendadores" -> "arrendador"
      r              -> r
    end

    case Inmobiliaria.UserManager.ranking(role) do
      {:ok, lista} ->
        if Enum.empty?(lista) do
          {:ok, "No hay usuarios con rol '#{role}'."}
        else
          texto =
            lista
            |> Enum.with_index(1)
            |> Enum.map_join("\n", fn {{user, score}, pos} ->
              "  #{pos}. #{user}: #{score} pts"
            end)
          {:ok, "── Ranking #{role}s ──\n#{texto}"}
        end
      {:error, reason} ->
        {:error, reason}
    end
  end

  # ---- my_score ----

  def execute_command(["my_score"], username, _role) do
    case Inmobiliaria.UserManager.get_score(username) do
      {:ok, score}     -> {:ok, "Tu puntaje actual: #{score} pts"}
      {:error, reason} -> {:error, reason}
    end
  end

  # ---- catch-all ----

  def execute_command(_, _username, _role),
    do: {:error, "Comando no reconocido"}

  # ── Validación de rol ──────────────────────────────────────────────────────

  defp validate_role(user_role, required_roles) do
    if user_role in required_roles do
      :ok
    else
      {:error,
       "Permiso denegado. Rol requerido: #{Enum.join(required_roles, " o ")}. Tu rol: #{user_role}"}
    end
  end

  # ── Helpers ────────────────────────────────────────────────────────────────

  defp determine_receptor(info) do
    case info.estado do
      :vendida ->
        info.cliente_comprador

      :arrendada ->
        info.cliente_arrendatario

      _ ->
        info.propietario
    end
  end

  defp publish_property_impl(tipo, ubicacion, precio_str, hab_str, area_str, propietario) do
    precio       = parse_number(precio_str)
    habitaciones = parse_integer(hab_str)
    area         = parse_number(area_str)

    cond do
      is_nil(precio)       -> {:error, "Precio debe ser un número válido"}
      is_nil(habitaciones) -> {:error, "Habitaciones debe ser un entero válido"}
      is_nil(area)         -> {:error, "Área debe ser un número válido"}
      true ->
        id = "p_#{:os.system_time(:second)}_#{Enum.random(1000..9999)}"
        attrs = %{
          "id"           => id,
          "tipo"         => tipo,
          "modalidad"    => "venta",
          "ubicacion"    => ubicacion,
          "precio"       => precio,
          "habitaciones" => habitaciones,
          "area"         => area,
          "propietario"  => propietario,
          "estado"       => "disponible"
        }
        Inmobiliaria.PropertyManager.publish(attrs)
    end
  end

  defp parse_number(str) do
    case Float.parse(str) do
      {num, ""} -> num
      _         -> nil
    end
  end

  defp parse_integer(str) do
    case Integer.parse(str) do
      {num, ""} -> num
      _         -> nil
    end
  end

  defp format_properties_list([]) do
    "No hay propiedades registradas."
  end

  defp format_properties_list(propiedades) do
    filas =
      propiedades
      |> Enum.map(fn p ->
        estado_display = if p.estado == :disponible, do: "✓", else: "✗ #{p.estado}"
        "  [#{p.id}] #{p.tipo} en #{p.ubicacion} — $#{p.precio} [#{estado_display}] | dueño: #{p.propietario}"
      end)
      |> Enum.join("\n")
    "Propiedades registradas:\n#{filas}"
  end
end
