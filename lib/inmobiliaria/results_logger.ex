defmodule Inmobiliaria.ResultsLogger do
  @moduledoc """
  Registra operaciones de compra y arriendo en data/results.log.
  Formato de cada línea:
    timestamp;tipo_operacion;propiedad_id;cliente;propietario;puntos_cliente;puntos_propietario
  """

  @log_file "results.log"

  @doc """
  Registra una operación exitosa.
  - tipo: "compra" | "arriendo"
  - prop_id: id de la propiedad
  - cliente: username del comprador/arrendatario
  - propietario: username del dueño de la propiedad
  """
  def log_operation(tipo, prop_id, cliente, propietario) do
    timestamp = DateTime.utc_now() |> DateTime.to_string()
    {pts_cliente, pts_propietario} = puntos(tipo)

    linea =
      Enum.join(
        [timestamp, tipo, prop_id, cliente, propietario,
         to_string(pts_cliente), to_string(pts_propietario)],
        ";"
      )

    Inmobiliaria.FileStorage.append_line(@log_file, linea)
  end

  # Puntos asignados según enunciado: +10 cliente, +15 responsable
  defp puntos(_tipo), do: {10, 15}
end
