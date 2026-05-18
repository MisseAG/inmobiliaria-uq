defmodule Inmobiliaria.Property do
  use GenServer
  require Logger

  # ── API Pública ────────────────────────────────────────────────────────────

  def start_link(attrs) do
    GenServer.start_link(__MODULE__, attrs, name: via_tuple(attrs["id"]))
  end

  @doc "Obtiene la información actual de la propiedad."
  def get_info(id) do
    try do
      GenServer.call(via_tuple(id), :get_info)
    catch
      :exit, _ -> {:error, :not_found}
    end
  end

  @doc "Reserva temporalmente la propiedad (disponible → reservada)."
  def reserve(id) do
    try do
      GenServer.call(via_tuple(id), :reserve)
    catch
      :exit, _ -> {:error, :not_found}
    end
  end

  @doc """
  Ejecuta la compra de la propiedad.
  Cambia estado: disponible → vendida.
  Retorna {:ok, state} con los datos de la propiedad o {:error, reason}.
  El control de concurrencia lo garantiza el GenServer: solo una llamada
  a la vez es atendida, por lo que no pueden ocurrir dos compras simultáneas.
  """
  def buy(id) do
    try do
      GenServer.call(via_tuple(id), :buy)
    catch
      :exit, _ -> {:error, :not_found}
    end
  end

  @doc """
  Ejecuta el arriendo de la propiedad por `meses` meses.
  Cambia estado: disponible → arrendada.
  Retorna {:ok, state} o {:error, reason}.
  """
  def rent(id, meses) do
    try do
      GenServer.call(via_tuple(id), {:rent, meses})
    catch
      :exit, _ -> {:error, :not_found}
    end
  end

  @doc "Completa una operación desde estado :reservada."
  def complete_sale(id, modalidad) do
    try do
      GenServer.call(via_tuple(id), {:complete_sale, modalidad})
    catch
      :exit, _ -> {:error, :not_found}
    end
  end

  # ── Callbacks GenServer ────────────────────────────────────────────────────

  @impl true
  def init(attrs) do
    state = %{
      id:           attrs["id"],
      tipo:         attrs["tipo"],
      modalidad:    attrs["modalidad"],
      ubicacion:    attrs["ubicacion"],
      precio:       attrs["precio"],
      habitaciones: attrs["habitaciones"],
      area:         attrs["area"],
      estado:       :disponible,
      propietario:  attrs["propietario"]
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
  def handle_call(:buy, _from, state) do
    # Control de acceso concurrente: el GenServer asegura exclusión mutua.
    # Solo se puede comprar si la propiedad está disponible.
    case state.estado do
      :disponible ->
        new_state = %{state | estado: :vendida}
        Logger.info("Propiedad #{state.id} vendida.")
        {:reply, {:ok, new_state}, new_state}
      :vendida ->
        {:reply, {:error, "La propiedad ya fue vendida."}, state}
      :arrendada ->
        {:reply, {:error, "La propiedad está arrendada y no puede comprarse."}, state}
      _ ->
        {:reply, {:error, "Estado actual no permite compra: #{state.estado}"}, state}
    end
  end

  @impl true
  def handle_call({:rent, meses}, _from, state) do
    # Control de acceso concurrente: el GenServer asegura exclusión mutua.
    # Solo se puede arrendar si la propiedad está disponible.
    case state.estado do
      :disponible ->
        new_state = %{state | estado: :arrendada, meses: meses}
        Logger.info("Propiedad #{state.id} arrendada por #{meses} meses.")
        {:reply, {:ok, new_state}, new_state}
      :arrendada ->
        {:reply, {:error, "La propiedad ya está arrendada."}, state}
      :vendida ->
        {:reply, {:error, "La propiedad ya fue vendida."}, state}
      _ ->
        {:reply, {:error, "Estado actual no permite arriendo: #{state.estado}"}, state}
    end
  end

  @impl true
  def handle_call({:complete_sale, modalidad}, _from, state) do
    case state.estado do
      :reservada ->
        new_estado = case modalidad do
          "venta"   -> :vendida
          "arriendo" -> :arrendada
          _          -> :reservada
        end
        new_state = %{state | estado: new_estado}
        {:reply, {:ok, new_state}, new_state}
      _ ->
        {:reply, {:error, "Solo se puede completar venta desde estado :reservada"}, state}
    end
  end

  # ── Funciones privadas ─────────────────────────────────────────────────────

  defp via_tuple(id) do
    {:via, Registry, {Inmobiliaria.PropertyRegistry, id}}
  end
end
