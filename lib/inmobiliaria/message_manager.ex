#gestion de mensajes
#GenServer que almacena mensajes en messages.log y permite enviar/recibir.

defmodule Inmobiliaria.MessageManager do
  @moduledoc """
  GenServer que gestiona mensajes entre usuarios.

  Persistencia en data/messages.log.
  Formato de cada línea:
    timestamp;prop_id;emisor;receptor;mensaje

  API pública:
    send_message(prop_id, emisor, receptor, mensaje) -> :ok | {:error, reason}
    read_messages(username)                          -> {:ok, [string]} | {:error, reason}
  """

  use GenServer

  @log_file "messages.log"

  # ── API pública ────────────────────────────────────────────────────────────

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: {:global, __MODULE__})
  end

  @doc """
  Envía un mensaje de `emisor` al `receptor`, referenciando la propiedad `prop_id`.
  Cualquier usuario puede enviar; el receptor suele ser el publicador de la propiedad.
  """
  def send_message(prop_id, emisor, receptor, mensaje) do
    GenServer.call({:global, __MODULE__}, {:send, prop_id, emisor, receptor, mensaje})
  end

  @doc """
  Devuelve todos los mensajes donde `username` es el receptor.
  """
  def read_messages(username) do
    GenServer.call({:global, __MODULE__}, {:read, username})
  end

  # ── Callbacks GenServer ────────────────────────────────────────────────────

  @impl true
  def init(_) do
    mensajes = load_messages()
    {:ok, mensajes}
  end

  @impl true
  def handle_call({:send, prop_id, emisor, receptor, mensaje}, _from, state) do
    timestamp = DateTime.utc_now() |> DateTime.to_string()

    entrada = %{
      timestamp: timestamp,
      prop_id:   prop_id,
      emisor:    emisor,
      receptor:  receptor,
      mensaje:   mensaje
    }

    linea = Enum.join(
      [timestamp, prop_id, emisor, receptor, mensaje],
      ";"
    )

    case Inmobiliaria.FileStorage.append_line(@log_file, linea) do
      :ok ->
        {:reply, :ok, [entrada | state]}
      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:read, username}, _from, state) do
    mis_mensajes =
      state
      |> Enum.filter(fn m -> m.receptor == username end)
      |> Enum.sort_by(fn m -> m.timestamp end)
      |> Enum.map(fn m ->
        "[#{m.timestamp}] De #{m.emisor} (prop #{m.prop_id}): #{m.mensaje}"
      end)

    {:reply, {:ok, mis_mensajes}, state}
  end

  # ── Persistencia ──────────────────────────────────────────────────────────

  defp load_messages do
    @log_file
    |> Inmobiliaria.FileStorage.read_lines()
    |> Enum.map(&parse_line/1)
    |> Enum.filter(&(not is_nil(&1)))
  end

  defp parse_line(line) do
    case String.split(line, ";", parts: 5) do
      [timestamp, prop_id, emisor, receptor, mensaje] ->
        %{
          timestamp: timestamp,
          prop_id:   prop_id,
          emisor:    emisor,
          receptor:  receptor,
          mensaje:   mensaje
        }
      _ ->
        nil
    end
  end
end
