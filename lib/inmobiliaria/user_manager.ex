defmodule Inmobiliaria.UserManager do
  @moduledoc """
  GenServer que mantiene el mapa de usuarios registrados y los conectados (online).
  Persistencia en data/users.dat.
  Formato: username;password;role;score
  """

  use GenServer

  @data_file "users.dat"

  # ── API pública ────────────────────────────────────────────────────────────

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: {:global, __MODULE__})
  end

  def register(username, password, role) do
    GenServer.call({:global, __MODULE__}, {:register, username, password, role})
  end

  def login(username, password) do
    GenServer.call({:global, __MODULE__}, {:login, username, password})
  end

  def logout(username) do
    GenServer.cast({:global, __MODULE__}, {:logout, username})
  end

  def online_users do
    GenServer.call({:global, __MODULE__}, :online_users)
  end

  @doc "Suma `points` al score de `username`. Retorna {:ok, nuevo_score} o {:error, reason}."
  def add_score(username, points) do
    GenServer.call({:global, __MODULE__}, {:add_score, username, points})
  end

  @doc "Devuelve el score individual de `username`. Retorna {:ok, score} o {:error, reason}."
  def get_score(username) do
    GenServer.call({:global, __MODULE__}, {:get_score, username})
  end

  @doc """
  Ranking global: todos los usuarios ordenados por score descendente.
  Retorna {:ok, [{username, score, role}]}.
  """
  def ranking do
    GenServer.call({:global, __MODULE__}, :ranking)
  end

  @doc """
  Ranking filtrado por rol: "cliente" | "vendedor" | "arrendador".
  Retorna {:ok, [{username, score}]}.
  """
  def ranking(role) do
    GenServer.call({:global, __MODULE__}, {:ranking_by_role, role})
  end

  # ── Callbacks del servidor ─────────────────────────────────────────────────

  @impl true
  def init(_) do
    users = load_users()
    {:ok, %{users: users, online: %{}}}
  end

  @impl true
  def handle_call({:register, username, password, role}, _from, state) do
    valid_roles = ["cliente", "vendedor", "arrendador"]
    cond do
      role not in valid_roles ->
        {:reply, {:error, "Rol inválido: #{role}"}, state}
      Map.has_key?(state.users, username) ->
        {:reply, {:error, "Usuario ya existe"}, state}
      true ->
        new_user = %{password: password, role: role, score: 0}
        new_users = Map.put(state.users, username, new_user)
        save_users(new_users)
        {:reply, {:ok, "Usuario #{username} registrado como #{role}"},
         %{state | users: new_users}}
    end
  end

  @impl true
  def handle_call({:login, username, password}, _from, state) do
    cond do
      Map.has_key?(state.online, username) ->
        {:reply, {:error, "Ya está conectado"}, state}
      not Map.has_key?(state.users, username) ->
        {:reply, {:error, "Usuario no existe"}, state}
      true ->
        user = state.users[username]
        if user.password == password do
          {:reply, {:ok, user.role},
           %{state | online: Map.put(state.online, username, true)}}
        else
          {:reply, {:error, "Contraseña incorrecta"}, state}
        end
    end
  end

  @impl true
  def handle_call(:online_users, _from, state) do
    {:reply, Map.keys(state.online), state}
  end

  @impl true
  def handle_call({:add_score, username, points}, _from, state) do
    case Map.fetch(state.users, username) do
      {:ok, user} ->
        new_score = user.score + points
        updated_user = %{user | score: new_score}
        new_users = Map.put(state.users, username, updated_user)
        save_users(new_users)
        {:reply, {:ok, new_score}, %{state | users: new_users}}
      :error ->
        {:reply, {:error, "Usuario no existe"}, state}
    end
  end

  @impl true
  def handle_call({:get_score, username}, _from, state) do
    case Map.fetch(state.users, username) do
      {:ok, user} -> {:reply, {:ok, user.score}, state}
      :error      -> {:reply, {:error, "Usuario no existe"}, state}
    end
  end

  @impl true
  def handle_call(:ranking, _from, state) do
    # Ranking global: compradores, vendedores y arrendadores ordenados por score
    lista =
      state.users
      |> Enum.map(fn {uname, data} -> {uname, data.score, data.role} end)
      |> Enum.sort_by(fn {_, score, _} -> score end, :desc)

    {:reply, {:ok, lista}, state}
  end

  @impl true
  def handle_call({:ranking_by_role, role}, _from, state) do
    lista =
      state.users
      |> Enum.filter(fn {_uname, data} -> data.role == role end)
      |> Enum.map(fn {uname, data} -> {uname, data.score} end)
      |> Enum.sort_by(fn {_, score} -> score end, :desc)

    {:reply, {:ok, lista}, state}
  end

  @impl true
  def handle_cast({:logout, username}, state) do
    new_online = Map.delete(state.online, username)
    {:noreply, %{state | online: new_online}}
  end

  # ── Persistencia ──────────────────────────────────────────────────────────

  defp load_users do
    File.mkdir_p!("data")
    if File.exists?(Path.join("data", @data_file)) do
      @data_file
      |> Inmobiliaria.FileStorage.read_lines()
      |> Enum.map(&parse_line/1)
      |> Enum.filter(&(not is_nil(&1)))
      |> Enum.into(%{})
    else
      %{}
    end
  end

  defp save_users(users) do
    content =
      Enum.map(users, fn {uname, data} ->
        "#{uname};#{data.password};#{data.role};#{data.score}"
      end)
      |> Enum.join("\n")

    Inmobiliaria.FileStorage.append_line(@data_file, "")
    path = Path.join("data", @data_file)
    File.write!(path, content)
  end

  defp parse_line(line) do
    case String.split(String.trim(line), ";") do
      [uname, pass, role, score] ->
        {uname, %{password: pass, role: role, score: String.to_integer(score)}}
      _ ->
        nil
    end
  end
end
