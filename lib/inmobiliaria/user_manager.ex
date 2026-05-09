#mantiene el mapa de usuarios registrados y el de online.
defmodule Inmobiliaria.UserManager do
  use GenServer

  @data_file "data/users.dat"

  # --- API pública ---

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
  # --- Callbacks del servidor ---
  @impl true
  def init(_) do
    # Cargar usuarios del disco
    users = load_users()
    {:ok, %{users: users, online: %{}}}
  end

  @impl true
  def handle_call({:register, username, password, role}, _from, state) do
    valid_roles = ["cliente", "vendedor", "arrendador"]
    cond do
      not (role in valid_roles) ->
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
          {:reply, {:ok, user.role}, %{state | online: Map.put(state.online, username, true)}}
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
  def handle_cast({:logout, username}, state) do
    new_online = Map.delete(state.online, username)
    {:noreply, %{state | online: new_online}}
  end

  # --- Persistencia simple ---
  defp load_users do
    File.mkdir_p!("data")
    if File.exists?(@data_file) do
      @data_file
      |> File.read!()
      |> String.split("\n", trim: true)
      |> Enum.map(&parse_line/1)
      |> Enum.into(%{})
    else
      File.write!(@data_file, "")
      %{}
    end
  end

  defp save_users(users) do
    content = Enum.map(users, fn {uname, data} ->
      "#{uname};#{data.password};#{data.role};#{data.score}"
    end) |> Enum.join("\n")
    File.write!(@data_file, content)
  end

  defp parse_line(line) do
    [uname, pass, role, score] = String.split(line, ";")
    {uname, %{password: pass, role: role, score: String.to_integer(score)}}
  end
end
