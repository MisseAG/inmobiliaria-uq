defmodule Inmobiliaria.PropertyManager do
  require Logger

  @properties_file "properties.dat"

  # --- API Pública ---

  @doc """
  Publica una propiedad nueva.
  Valida datos, verifica ubicación, inicia proceso, persiste.
  Retorna {:ok, pid, id} o {:error, reason}
  """
  def publish(attrs) do
    with :ok <- validate_attrs(attrs),
         :ok <- validate_location(attrs["ubicacion"]),
         {:ok, pid} <- start_property(attrs),
         :ok <- persist_property(attrs) do
      {:ok, pid, attrs["id"]}
    end
  end

  @doc """
  Lista todas las propiedades registradas desde el archivo.
  Retorna lista de mapas con información de propiedades.
  """
  def list_all do
    @properties_file
    |> Inmobiliaria.FileStorage.read_lines()
    |> Enum.map(&parse_line/1)
    |> Enum.filter(&(not is_nil(&1)))
  end

  @doc """
  Filtra propiedades según criterios.
  criteria: %{
    tipo: "casa" | "apartamento" | ...,
    modalidad: "venta" | "arriendo",
    ubicacion: "Armenia" | ...,
    precio_min: number,
    precio_max: number,
    solo_disponibles: true | false
  }
  """
  def filter(criteria) do
    list_all()
    |> Enum.filter(&matches_criteria?(&1, criteria))
  end

  @doc """
  Busca una propiedad viva por id.
  Retorna {:ok, pid} o {:error, :not_found}
  """
  def find(id) do
    try do
      info = Inmobiliaria.Property.get_info(id)
      case info do
        {:ok, _} -> {:ok, id}
        {:error, _} -> {:error, :not_found}
      end
    rescue
      _ -> {:error, :not_found}
    end
  end

  @doc """
  Actualiza el estado de una propiedad en el archivo properties.dat.
  Estados válidos: :disponible, :vendida, :arrendada.
  Retorna :ok o {:error, reason}
  """
  def update_property_status(id, new_estado) do
    try do
      path = Path.join("data", @properties_file)
      content = File.read!(path)
      lines = String.split(content, "\n", trim: true)

      updated_lines = Enum.map(lines, fn line ->
        parts = String.split(line, ";", trim: true)
        case parts do
          [^id | rest] ->
            # Reemplaza el último campo (estado) con el nuevo
            [id | Enum.drop(rest, -1) ++ [to_string(new_estado)]]
            |> Enum.join(";")
          _ ->
            line
        end
      end)

      # Reescribe el archivo preservando correctamente
      new_content = Enum.join(updated_lines, "\n") <> "\n"
      File.write!(path, new_content)
      :ok
    rescue
      _ -> {:error, "No se pudo actualizar la propiedad"}
    end
  end

  # --- Funciones privadas ---

  defp validate_attrs(attrs) do
    required = ["id", "tipo", "modalidad", "ubicacion", "precio", "habitaciones", "area", "propietario"]
    missing = Enum.filter(required, &is_nil(attrs[&1]))

    if Enum.empty?(missing) do
      :ok
    else
      {:error, "Falta información: #{Enum.join(missing, ", ")}"}
    end
  end

  defp validate_location(location) do
    case Inmobiliaria.Location.valid?(location) do
      true -> :ok
      false -> {:error, "Ubicación inválida: #{location}"}
    end
  end

  defp start_property(attrs) do
    Inmobiliaria.PropertySupervisor.start_property(attrs)
  end

  defp persist_property(attrs) do
    line = format_property_line(attrs)
    Inmobiliaria.FileStorage.append_line(@properties_file, line)
  end

  defp format_property_line(attrs) do
    precio_str = attrs["precio"] |> Float.round(2) |> Float.to_string()
    [
      attrs["id"],
      attrs["propietario"],
      attrs["tipo"],
      attrs["modalidad"],
      attrs["ubicacion"],
      precio_str,
      to_string(attrs["habitaciones"]),
      to_string(attrs["area"]),
      "disponible"
    ]
    |> Enum.join(";")
  end

  defp parse_line(line) do
    parts = String.split(line, ";", trim: true)
    case parts do
      [id, propietario, tipo, modalidad, ubicacion, precio, habitaciones, area, estado] ->
        try do
          %{
            id: id,
            propietario: propietario,
            tipo: tipo,
            modalidad: modalidad,
            ubicacion: ubicacion,
            precio: String.to_float(precio),
            habitaciones: String.to_integer(habitaciones),
            area: String.to_float(area),
            estado: String.to_atom(estado)
          }
        rescue
          _ -> nil
        end
      _ ->
        nil
    end
  end

  defp matches_criteria?(property, criteria) when not is_nil(property) do
    Enum.all?(criteria, fn {key, value} ->
      case key do
        :tipo -> is_nil(value) or property.tipo == value
        :modalidad -> is_nil(value) or property.modalidad == value
        :ubicacion -> is_nil(value) or property.ubicacion == value
        :precio_min -> is_nil(value) or property.precio >= value
        :precio_max -> is_nil(value) or property.precio <= value
        :solo_disponibles -> !value or property.estado == :disponible
        _ -> true
      end
    end)
  end

  defp matches_criteria?(nil, _criteria), do: false
end
