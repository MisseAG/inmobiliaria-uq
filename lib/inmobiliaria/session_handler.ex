defmodule Inmobiliaria.SessionHandler do
  def execute_command(["register", username, password, role]), do: Inmobiliaria.UserManager.register(username, password, role)

  def execute_command(["connect", username, password]), do: Inmobiliaria.UserManager.login(username, password)

  def execute_command(["online"]), do: { :ok, Inmobiliaria.UserManager.online_users() }

  def execute_command(_), do: {:error, "Comando no reconocido"}
end
