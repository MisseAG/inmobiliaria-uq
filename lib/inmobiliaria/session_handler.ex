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

  def execute_command(["publish_property", tipo, ubicacion, precio, habitaciones, area],
                      username, role) do
    with :ok <- validate_role(role, ["vendedor", "arrendador"]),
         {:ok, pid, id} <- publish_property_impl(tipo, ubicacion, precio, habitaciones, area, username) do
      {:ok, "✓ Propiedad publicada. ID: #{id}, PID: #{inspect(pid)}"}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  def execute_command(["publish_property" | _], _username, role) do
    case validate_role(role, ["vendedor", "arrendador"]) do
      :ok    -> {:error, "Uso: publish_property <tipo> <ubicacion> <precio> <habitaciones> <area>"}
      error  -> error
    end
  end

  # ---- list_properties ----

  def execute_command(["list_properties" | _], _username, _role) do
    propiedades = Inmobiliaria.PropertyManager.list_all()
    {:ok, format_properties_list(propiedades)}
  end

  # ---- buy_property ----

  def execute_command(["buy_property", prop_id], username, role) do
    with :ok <- validate_role(role, ["cliente"]),
         {:ok, info} <- Inmobiliaria.Property.get_info(prop_id),
         {:ok, new_state} <- Inmobiliaria.Property.buy(prop_id) do

      propietario = info.propietario

      # Asignar puntos: +10 al cliente, +15 al propietario (responsable)
      Inmobiliaria.UserManager.add_score(username, 10)
      Inmobiliaria.UserManager.add_score(propietario, 15)

      # Registrar en results.log
      Inmobiliaria.ResultsLogger.log_operation("compra", prop_id, username, propietario)

      mensaje = """
      ✓ Propiedad #{prop_id} comprada exitosamente.
        Tipo: #{new_state.tipo} | Ubicación: #{new_state.ubicacion}
        Precio: $#{new_state.precio}
        +10 puntos para ti | +15 puntos para #{propietario}
      """
      {:ok, String.trim(mensaje)}
    else
      {:error, reason} -> {:error, reason}
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
         {:ok, info} <- Inmobiliaria.Property.get_info(prop_id),
         {:ok, new_state} <- Inmobiliaria.Property.rent(prop_id, meses) do

      propietario = info.propietario

      # Asignar puntos: +10 al cliente, +15 al propietario (responsable)
      Inmobiliaria.UserManager.add_score(username, 10)
      Inmobiliaria.UserManager.add_score(propietario, 15)

      # Registrar en results.log
      Inmobiliaria.ResultsLogger.log_operation("arriendo", prop_id, username, propietario)

      mensaje = """
      ✓ Propiedad #{prop_id} arrendada por #{meses} mes(es).
        Tipo: #{new_state.tipo} | Ubicación: #{new_state.ubicacion}
        Precio mensual: $#{new_state.precio}
        +10 puntos para ti | +15 puntos para #{propietario}
      """
      {:ok, String.trim(mensaje)}
    else
      :error          -> {:error, "Número de meses inválido"}
      {_, _}          -> {:error, "Número de meses inválido"}
      {:error, reason} -> {:error, reason}
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

  def execute_command(["send_message", prop_id | resto], username, _role) when resto != [] do
    mensaje = Enum.join(resto, " ")

    # Obtener el propietario de la propiedad para saber el receptor
    case Inmobiliaria.Property.get_info(prop_id) do
      {:ok, info} ->
        receptor = info.propietario
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

  # ---- read_messages ----
  # Solo el vendedor/arrendador puede leer los mensajes que le llegaron

  def execute_command(["read_messages"], username, role) do
    with :ok <- validate_role(role, ["vendedor", "arrendador"]),
         {:ok, mensajes} <- Inmobiliaria.MessageManager.read_messages(username) do
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
      {:error, reason} -> {:error, reason}
    end
  end

  # ---- ranking por rol ----
  # Uso: ranking <rol>  (clientes | vendedores | arrendadores)

  def execute_command(["ranking", rol_arg], _username, _role) do
    # Normalizar alias plurales
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
      {:error, reason} -> {:error, reason}
    end
  end

  # ---- my_score ----

  def execute_command(["my_score"], username, _role) do
    case Inmobiliaria.UserManager.get_score(username) do
      {:ok, score} -> {:ok, "Tu puntaje actual: #{score} pts"}
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

  # ── Helpers de publicación ─────────────────────────────────────────────────

  defp publish_property_impl(tipo, ubicacion, precio_str, hab_str, area_str, propietario) do
    precio       = parse_number(precio_str)
    habitaciones = parse_integer(hab_str)
    area         = parse_number(area_str)

    cond do
      is_nil(precio)       -> {:error, "Precio debe ser un número válido"}
      is_nil(habitaciones) -> {:error, "Habitaciones debe ser un entero válido"}
      is_nil(area)         -> {:error, "Área debe ser un número válido"}
      true ->
        id = "prop_#{:os.system_time(:millisecond)}"
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
        "  [#{p.id}] #{p.tipo} en #{p.ubicacion} — $#{p.precio} (#{p.estado}) | dueño: #{p.propietario}"
      end)
      |> Enum.join("\n")

    "Propiedades disponibles:\n#{filas}"
  end
end
