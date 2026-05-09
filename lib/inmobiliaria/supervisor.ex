defmodule Inmobiliaria.PropertySupervisor do
  use DynamicSupervisor

  def start_link(_), do: DynamicSupervisor.start_link(__MODULE__, nil, name: __MODULE__)

  def start_property(attrs), do: DynamicSupervisor.start_child(__MODULE__, {Inmobiliaria.Property, attrs})

  @impl true
  def init(_), do: DynamicSupervisor.init(strategy: :one_for_one)
end
