defmodule Inmobiliaria.FileStorage do
  @data_dir "data"
  @users_file "users.dat"
  @properties_file "properties.dat"
  @results_file "results.log"
  @messages_file "messages.log"
  @locations_file "locations.dat"

  def init do
    File.mkdir_p!(@data_dir)

    ensure_file(@users_file)
    ensure_file(@properties_file)
    ensure_file(@results_file)
    ensure_file(@messages_file)
    ensure_file(@locations_file)

    IO.puts("Sistema de archivos inicializado")
  end

  # Funciones genéricas para lectura y escritura

  @doc """
  Agrega una línea al final de un archivo (en la carpeta data/)
  Retorna :ok o {:error, razón}
  """
  def append_line(filename, line) do
    path = Path.join(@data_dir, filename)
    case File.write(path, line <> "\n", [:append]) do
      :ok -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Lee todas las líneas de un archivo (en la carpeta data/)
  Retorna lista de strings o lista vacía si archivo no existe
  """
  def read_lines(filename) do
    path = Path.join(@data_dir, filename)
    case File.read(path) do
      {:ok, content} ->
        content
        |> String.split("\n", trim: true)
      {:error, :enoent} -> []
      {:error, reason} ->
        IO.puts("Error leyendo #{filename}: #{inspect(reason)}")
        []
    end
  end

  # Funciones privadas

  defp ensure_file(filename) do
    path = Path.join(@data_dir, filename)
    unless File.exists?(path) do
      File.write!(path, "")
    end
  end
end
