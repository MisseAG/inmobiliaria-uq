defmodule Inmobiliaria.CLI do
  def start do
    # Imprime el banner de bienvenida
    IO.puts """
    ==================================================
    ¡BIENVENIDO A LA INMOBILIARIA VIRTUAL!
    ==================================================
    Estado: Conectado al nodo #{node()}

    COMANDOS DISPONIBLES:
      Autenticación:
        > register <usuario> <clave> <rol>
        > connect <usuario> <clave>
        > online
        > disconnect

      Propiedades (Vendedor/Arrendador):
        > publish_property <tipo> <ubicacion> <precio> <habitaciones> <area>


      Propiedades (Cliente):
        > list_properties
        > buy_property <id>
        > rent_property <id> <meses>

      Mensajes:
        > send_message <receptor> <mensaje>
        > read_messages

      Ranking:
        > ranking
        > my_score

      Sistema:
        > exit
    --------------------------------------------------
    """
    loop(nil, nil)
  end

  defp loop(username, role) do
    prompt = if username do

    "#{IO.ANSI.green()}#{username}#{IO.ANSI.reset()}#{IO.ANSI.faint()}(#{role})#{IO.ANSI.reset()} #{IO.ANSI.cyan()}>#{IO.ANSI.reset()} "
  else

    "#{IO.ANSI.yellow()}invitado#{IO.ANSI.reset()} #{IO.ANSI.cyan()}>#{IO.ANSI.reset()} "
  end

    input = IO.gets(prompt)
            |> String.trim()
            |> String.split(" ", trim: true)

    case process_input(input, username, role) do
      {:ok, :exit} ->
        IO.puts("Saliendo del sistema...")
      {:ok, :disconnect} ->
        IO.puts("Sesión cerrada. Volviendo al menú principal...")
        Process.sleep(800)
        start()
      {:ok, new_user, new_role, msg} ->
        IO.puts(msg)
        loop(new_user, new_role)
      {:error, reason} ->
        IO.puts("Error: #{reason}")
        loop(username, role)
    end
  end

  # Lógica interna del CLI

  defp process_input(["register", u, p, r], user, role) when user == nil do
    case Inmobiliaria.UserManager.register(u, p, r) do
      {:ok, msg} -> {:ok, user, role, "✓ #{msg}"}
      {:error, err} -> {:error, err}
    end
  end

  defp process_input(["connect", u, p], user, _role) when user == nil do
    case Inmobiliaria.UserManager.login(u, p) do
      {:ok, user_role} -> {:ok, u, user_role, "Bienvenido #{u}. Rol: #{user_role}"}
      {:error, err} -> {:error, err}
    end
  end

  defp process_input(["online"], user, role) do
    lista = Inmobiliaria.UserManager.online_users()
    {:ok, user, role, "Usuarios en línea: #{Enum.join(lista, ", ")}"}
  end

  defp process_input(["exit"], user, _role) do
    if user, do: Inmobiliaria.UserManager.logout(user)
    {:ok, :exit}
  end

  defp process_input(["disconnect"], user, _role) do
    if user do
      Inmobiliaria.UserManager.logout(user)
      {:ok, :disconnect}
    else
      {:error, "No hay ninguna sesión activa para desconectar."}
    end
  end

  # Comandos que requieren autenticación y validación de rol

  defp process_input(cmd, user, role) when is_list(cmd) and user != nil do
    case Inmobiliaria.SessionHandler.execute_command(cmd, role) do
      {:ok, msg} -> {:ok, user, role, msg}
      {:error, err} -> {:error, err}
    end
  end

  # Restringir otros comandos sin estar autenticado
  defp process_input(_cmd, nil, nil) do
    {:error, "Debe conectarse primero (usa 'connect <usuario> <clave>')"}
  end

  # Comando desconocido
  defp process_input(_, _user, _role) do
    {:error, "Comando desconocido"}
  end
end
