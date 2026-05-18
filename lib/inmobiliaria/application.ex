defmodule Inmobiliaria.Application do
  use Application

  @impl true
  def start(_type, _args) do
    Inmobiliaria.FileStorage.init()

    children = [
      {Registry, keys: :unique, name: Inmobiliaria.PropertyRegistry},
      Inmobiliaria.UserManager,
      Inmobiliaria.MessageManager,
      Inmobiliaria.PropertyServer,
      Inmobiliaria.PropertySupervisor
    ]

    opts = [strategy: :one_for_one, name: Inmobiliaria.Supervisor]
    {:ok, pid} = Supervisor.start_link(children, opts)

    recargar_propiedades()

    {:ok, pid}
  end

  defp recargar_propiedades do
    propiedades = Inmobiliaria.PropertyManager.list_all()
    Enum.each(propiedades, fn prop ->
      attrs = %{
        "id"           => prop.id,
        "tipo"         => prop.tipo,
        "modalidad"    => prop.modalidad,
        "ubicacion"    => prop.ubicacion,
        "precio"       => prop.precio,
        "habitaciones" => prop.habitaciones,
        "area"         => prop.area,
        "propietario"  => prop.propietario,
        "estado"       => to_string(prop.estado)
      }
      case Inmobiliaria.PropertySupervisor.start_property(attrs) do
        {:ok, _pid}                  -> :ok
        {:error, {:already_started, _}} -> :ok
        _                            -> :ok
      end
    end)
    IO.puts("Propiedades recargadas: #{length(propiedades)}")
  end
end
