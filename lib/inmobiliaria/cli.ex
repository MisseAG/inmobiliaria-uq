defmodule Inmobiliaria.CLI do
  def start do
    IO.puts("\n ===== INMOBILIARIA UQ =====")
    IO.puts("Comandos disponibles:")
    IO.puts("  register <usuario> <contraseña> <rol>")
    IO.puts("  connect <usuario> <contraseña>")
    IO.puts("  disconnect")
    IO.puts("  online")
    IO.puts("  exit")
    IO.puts("================================\n")

    loop(%{current_user: nil})
  end

  defp loop(state) do
    prompt = if state.current_user do
      "#{state.current_user}> "
    else
      "> "
    end

    IO.write(prompt)
    input = IO.gets("") |> String.trim()

    case String.split(input) do
      ["register", username, password, role] ->
        handle_register(username, password, role)
        loop(state)

      ["connect", username, password] ->
        new_state = handle_connect(username, password, state)
        loop(new_state)

      ["disconnect"] ->
        new_state = handle_disconnect(state)
        loop(new_state)

      ["online"] ->
        handle_online()
        loop(state)

      ["exit"] ->
        if state.current_user do
          Inmobiliaria.UserManager.disconnect(state.current_user)
        end
        IO.puts("¡Hasta luego!")

      [""] ->
        loop(state)

      _ ->
        IO.puts("Comando no reconocido")
        loop(state)
    end
  end

  defp handle_register(username, password, role) do
    # Validar rol
    valid_roles = ["cliente", "vendedor", "arrendador"]
    if role in valid_roles do
      case Inmobiliaria.UserManager.register(username, password, role) do
        {:ok, msg} -> IO.puts(" #{msg}")
        {:error, msg} -> IO.puts(" #{msg}")
      end
    else
      IO.puts("Rol inválido. Use: cliente, vendedor o arrendador")
    end
  end

  defp handle_connect(username, password, state) do
    case Inmobiliaria.UserManager.connect(username, password) do
      {:ok, msg} ->
        IO.puts("#{msg}")
        %{state | current_user: username}

      {:error, msg} ->
        IO.puts("#{msg}")
        state
    end
  end

  defp handle_disconnect(state) do
    if state.current_user do
      Inmobiliaria.UserManager.disconnect(state.current_user)
      IO.puts("Desconectado")
      %{state | current_user: nil}
    else
      IO.puts("No hay usuario conectado")
      state
    end
  end

  defp handle_online do
    online_users = Inmobiliaria.UserManager.get_online_users()
    if online_users == [] do
      IO.puts("No hay usuarios conectados")
    else
      IO.puts("Usuarios conectados:")
      Enum.each(online_users, fn user -> IO.puts("  - #{user}") end)
    end
  end
end
