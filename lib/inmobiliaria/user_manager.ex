#gestión de usuarios, cada usuario es un genserver
defmodule Inmobiliaria.UserManager do
  use GenServer

  # CLIENT API

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def connect(username, password) do
    GenServer.call(__MODULE__, {:connect, username, password})
  end

  def register(username, password, role) do
    GenServer.call(__MODULE__, {:register, username, password, role})
  end

  def disconnect(username) do
    GenServer.cast(__MODULE__, {:disconnect, username})
  end

  def get_online_users do
    GenServer.call(__MODULE__, :get_online_users)
  end

  # SERVER CALLBACKS

  @impl true
  def init(_) do
    {:ok, %{online_users: %{}}}
  end

  @impl true
  def handle_call({:connect, username, password}, _from, state) do
    if Map.has_key?(state.online_users, username) do
      {:reply, {:error, "Usuario ya está conectado"}, state}
    else
      case Inmobiliaria.FileStorage.get_user(username) do
        nil ->
          {:reply, {:error, "Usuario no existe. Use 'register' primero"}, state}

        user_data ->
          if user_data.password == password do
            new_state = put_in(state.online_users[username], user_data)
            {:reply, {:ok, "Bienvenido #{username} (#{user_data.role})"}, new_state}
          else
            {:reply, {:error, "Contraseña incorrecta"}, state}
          end
      end
    end
  end

  @impl true
  def handle_call({:register, username, password, role}, _from, state) do
    if Inmobiliaria.FileStorage.user_exists?(username) do
      {:reply, {:error, "Usuario ya existe. Use 'connect'"}, state}
    else
      Inmobiliaria.FileStorage.save_user(username, password, role)
      {:reply, {:ok, "Usuario #{username} registrado como #{role}"}, state}
    end
  end

  @impl true
  def handle_call(:get_online_users, _from, state) do
    online = Map.keys(state.online_users)
    {:reply, online, state}
  end

  @impl true
  def handle_cast({:disconnect, username}, state) do
    new_state = %{state | online_users: Map.delete(state.online_users, username)}
    {:noreply, new_state}
  end
end
