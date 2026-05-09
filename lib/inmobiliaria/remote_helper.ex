defmodule Inmobiliaria.RemoteHelper do
  def unir(nodo_servidor) do
    Node.connect(nodo_servidor)
    IO.puts("Conectado al servidor. Iniciando CLI...")
    Inmobiliaria.CLI.start()
  end
end