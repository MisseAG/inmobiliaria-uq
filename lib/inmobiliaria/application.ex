defmodule Inmobiliaria.Application do
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      Inmobiliaria.UserManager
    ]

    opts = [strategy: :one_for_one, name: Inmobiliaria.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
