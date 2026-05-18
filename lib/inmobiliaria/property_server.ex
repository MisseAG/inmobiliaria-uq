defmodule Inmobiliaria.PropertyServer do
  @moduledoc """
  GenServer global que actúa como proxy para operaciones sobre propiedades.
  Al estar registrado con {:global, ...}, es accesible desde cualquier nodo
  conectado sin necesidad de RPC ni Registry local.
  """
  use GenServer

  # ── API pública ────────────────────────────────────────────────────────────

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, nil, name: {:global, __MODULE__})
  end

  def get_info(id) do
    GenServer.call({:global, __MODULE__}, {:get_info, id})
  end

  def buy(id, cliente, propietario) do
    GenServer.call({:global, __MODULE__}, {:buy, id, cliente, propietario})
  end

  def rent(id, meses, cliente, propietario) do
    GenServer.call({:global, __MODULE__}, {:rent, id, meses, cliente, propietario})
  end

  # ── Callbacks GenServer ────────────────────────────────────────────────────

  @impl true
  def init(_), do: {:ok, nil}

  @impl true
  def handle_call({:get_info, id}, _from, state) do
    {:reply, Inmobiliaria.Property.get_info(id), state}
  end

  @impl true
  def handle_call({:buy, id, cliente, propietario}, _from, state) do
    result =
      with {:ok, _info} <- Inmobiliaria.Property.get_info(id),
           {:ok, new_state} <- Inmobiliaria.Property.buy(id) do
        Inmobiliaria.UserManager.add_score(cliente, 10)
        Inmobiliaria.UserManager.add_score(propietario, 15)
        Inmobiliaria.ResultsLogger.log_operation("compra", id, cliente, propietario)
        {:ok, new_state}
      end
    {:reply, result, state}
  end

  @impl true
  def handle_call({:rent, id, meses, cliente, propietario}, _from, state) do
    result =
      with {:ok, _info} <- Inmobiliaria.Property.get_info(id),
           {:ok, new_state} <- Inmobiliaria.Property.rent(id, meses) do
        Inmobiliaria.UserManager.add_score(cliente, 10)
        Inmobiliaria.UserManager.add_score(propietario, 15)
        Inmobiliaria.ResultsLogger.log_operation("arriendo", id, cliente, propietario)
        {:ok, new_state}
      end
    {:reply, result, state}
  end
end
