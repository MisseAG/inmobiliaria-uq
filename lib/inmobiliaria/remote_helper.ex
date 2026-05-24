defmodule Inmobiliaria.RemoteHelper do
  def unir(nodo_servidor) do
    case Node.connect(nodo_servidor) do
      true ->
        IO.puts("Conectado al servidor. Iniciando CLI...")
        Inmobiliaria.CLI.start()
      false ->
        IO.puts("Error: No se pudo conectar al nodo servidor '#{nodo_servidor}'")
        {:error, "Conexión fallida"}
    end
  end
end
