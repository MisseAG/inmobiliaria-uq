defmodule Inmobiliaria.Property do
  use GenServer
  require Logger

  # ── API Pública ────────────────────────────────────────────────────────────

  def start_link(attrs) when is_map(attrs) do
    GenServer.start_link(__MODULE__, attrs, name: via_tuple(attrs["id"]))
  end

  def start_link(args_list) when is_list(args_list) do
    attrs = List.first(args_list)
    GenServer.start_link(__MODULE__, attrs, name: via_tuple(attrs["id"]))
  end

  @doc "Obtiene la información actual de la propiedad."
  def get_info(id) do
    case find_pid(id) do
      {:ok, pid} -> GenServer.call(pid, :get_info)
      error -> error
    end
  end

  @doc "Reserva temporalmente la propiedad (disponible → reservada)."
  def reserve(id) do
    case find_pid(id) do
      {:ok, pid} -> GenServer.call(pid, :reserve)
      error -> error
    end
  end

  @doc "Ejecuta la compra de la propiedad. Cambia estado: disponible → vendida."
  def buy(id) do
    case find_pid(id) do
      {:ok, pid} -> GenServer.call(pid, :buy)
      error -> error
    end
  end

  @doc "Ejecuta el arriendo de la propiedad por `meses` meses. Cambia estado: disponible → arrendada."
  def rent(id, meses) do
    case find_pid(id) do
      {:ok, pid} -> GenServer.call(pid, {:rent, meses})
      error -> error
    end
  end

  @doc "Completa una operación desde estado :reservada."
  def complete_sale(id, modalidad) do
    case find_pid(id) do
      {:ok, pid} -> GenServer.call(pid, {:complete_sale, modalidad})
      error -> error
    end
  end

  # ── Callbacks GenServer ────────────────────────────────────────────────────

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
  def handle_call(:get_id, _from, state) do
    {:reply, state.id, state}
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
    case state.estado do
      :disponible ->
        new_state = state |> Map.put(:estado, :arrendada) |> Map.put(:meses, meses)
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
        new_estado =
          case modalidad do
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

  # ── Funciones privadas ─────────────────────────────────────────────────────

  # Busca el PID recorriendo los hijos del DynamicSupervisor.
  # No depende del Registry por nombre, por lo que funciona correctamente
  # tanto en llamadas locales como en llamadas remotas via :rpc.call.
  defp find_pid(id) do
    # Buscar el PID del supervisor — funciona tanto local como via RPC
    sup_pid =
      case Process.whereis(Inmobiliaria.PropertySupervisor) do
        nil ->
          # Si no está registrado localmente, buscarlo entre todos los procesos
          Process.list()
          |> Enum.find(fn pid ->
            case Process.info(pid, :registered_name) do
              {:registered_name, Inmobiliaria.PropertySupervisor} -> true
              _ -> false
            end
          end)

        pid ->
          pid
      end

    if is_nil(sup_pid) do
      {:error, :not_found}
    else
      resultado =
        DynamicSupervisor.which_children(sup_pid)
        |> Enum.find_value(fn {_, pid, _, _} ->
          if is_pid(pid) and Process.alive?(pid) do
            case GenServer.call(pid, :get_id) do
              ^id -> pid
              _ -> nil
            end
          end
        end)

      case resultado do
        nil -> {:error, :not_found}
        pid -> {:ok, pid}
      end
    end
  end

  defp via_tuple(id) do
    {:via, Registry, {Inmobiliaria.PropertyRegistry, id}}
  end
end
