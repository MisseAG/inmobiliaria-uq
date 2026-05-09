defmodule Inmobiliaria.CLI do
  def start do
    # Imprime el banner de bienvenida
    IO.puts """
    ==================================================
    ¡BIENVENIDO A LA INMOBILIARIA VIRTUAL!
    ==================================================
    Estado: Conectado al nodo #{node()}
    Comandos:
      > register <usuario> <clave> <rol>
      > connect <usuario> <clave>
      > online
      > exit
    --------------------------------------------------
    """
    loop(nil)
  end

  defp loop(username) do
    prompt = if username, do: "#{username}> ", else: "> "

    input = IO.gets(prompt)
            |> String.trim()
            |> String.split(" ", trim: true)

    case process_input(input, username) do
      {:ok, :exit} ->
        IO.puts("Saliendo del sistema...")
      {:ok, new_user, msg} ->
        IO.puts(msg)
        loop(new_user)
      {:error, reason} ->
        IO.puts("Error: #{reason}")
        loop(username)
    end
  end

  # Lógica interna del CLI
  defp process_input(["register", u, p, r], user) do
    case Inmobiliaria.UserManager.register(u, p, r) do
      {:ok, msg} -> {:ok, user, "✓ #{msg}"}
      {:error, err} -> {:error, err}
    end
  end

  defp process_input(["connect", u, p], _user) do
    case Inmobiliaria.UserManager.login(u, p) do
      {:ok, role} -> {:ok, u, "✓ Bienvenido #{u}. Rol: #{role}"}
      {:error, err} -> {:error, err}
    end
  end

  defp process_input(["online"], user) do
    lista = Inmobiliaria.UserManager.online_users()
    {:ok, user, "Usuarios en línea: #{Enum.join(lista, ", ")}"}
  end

  defp process_input(["exit"], user) do
    if user, do: Inmobiliaria.UserManager.logout(user)
    {:ok, :exit}
  end

  defp process_input(_, _user), do: {:error, "Comando desconocido"}
end
