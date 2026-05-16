defmodule Inmobiliaria.Property do
  use GenServer
  require Logger

  # --- API Pública ---

  @doc """
  Inicia un GenServer para una propiedad con los atributos dados.
  """
  def start_link(attrs) do
    GenServer.start_link(__MODULE__, attrs, name: via_tuple(attrs["id"]))
  end

  @doc """
  Obtiene la información actual de la propiedad.
  """
  def get_info(id) do
    try do
      GenServer.call(via_tuple(id), :get_info)
    catch
      :exit, _ -> {:error, :not_found}
    end
  end

  @doc """
  Intenta reservar una propiedad (cambiar de :disponible a :reservada).
  """
  def reserve(id) do
    try do
      GenServer.call(via_tuple(id), :reserve)
    catch
      :exit, _ -> {:error, :not_found}
    end
  end

  @doc """
  Completa la venta o arriendo de una propiedad.
  Si modalidad es "venta", cambia a :vendida.
  Si modalidad es "arriendo", cambia a :arrendada.
  """
  def complete_sale(id, modalidad) do
    try do
      GenServer.call(via_tuple(id), {:complete_sale, modalidad})
    catch
      :exit, _ -> {:error, :not_found}
    end
  end

  # --- Callbacks GenServer ---

  @impl true
  def init(attrs) do
    state = %{
      id: attrs["id"],
      tipo: attrs["tipo"],
      modalidad: attrs["modalidad"],
      ubicacion: attrs["ubicacion"],
      precio: attrs["precio"],
      habitaciones: attrs["habitaciones"],
      area: attrs["area"],
      estado: :disponible,
      propietario: attrs["propietario"]
    }
    {:ok, state}
  end

  @impl true
  def handle_call(:get_info, _from, state) do
    {:reply, {:ok, state}, state}
  end

  @impl true
  def handle_call(:reserve, _from, state) do
    case state.estado do
      :disponible ->
        new_state = %{state | estado: :reservada}
        {:reply, {:ok, new_state}, new_state}
      _ ->
        {:reply, {:error, "No se puede reservar. Estado actual: #{state.estado}"}, state}
    end
  end

  @impl true
  def handle_call({:complete_sale, modalidad}, _from, state) do
    case state.estado do
      :reservada ->
        new_estado = case modalidad do
          "venta" -> :vendida
          "arriendo" -> :arrendada
          _ -> :reservada
        end
        new_state = %{state | estado: new_estado}
        {:reply, {:ok, new_state}, new_state}
      _ ->
        {:reply, {:error, "Solo se puede completar venta desde estado :reservada"}, state}
    end
  end

  # --- Funciones privadas ---

  defp via_tuple(id) do
    {:via, Registry, {Inmobiliaria.PropertyRegistry, id}}
  end
end
