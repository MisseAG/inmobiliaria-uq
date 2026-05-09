defmodule Inmobiliaria.Location do
  @locations ["Armenia", "Bogotá", "Medellín", "Cali", "Barranquilla"]

  # Generamos una lista sin tildes y en minúsculas para facilitar la comparación
  @normalized_locations Enum.map(@locations,
  fn loc -> loc
    |> String.downcase()
    |> String.normalize(:nfd)
    |> String.replace(~r/[\p{Mn}]/u,"")
  end)

  def all, do: @locations

  def valid?(location) when is_binary(location) do
    # Limpiamos la entrada del usuario de la misma forma
    input_normalized =
      location
      |> String.trim()
      |> String.downcase()
      |> String.normalize(:nfd)
      |> String.replace(~r/[\p{Mn}]/u, "")

    # Comparación directa
    input_normalized in @normalized_locations
  end

  def valid?(_), do: false
end
