defmodule Inmobiliaria.FileStorage do
  @data_dir "data"
  @users_file "users.dat"

  def init do
    File.mkdir_p!(@data_dir)
    users_path = Path.join(@data_dir, @users_file)
    unless File.exists?(users_path) do
      File.write!(users_path, "")
    end
    IO.puts("Sistema de archivos inicializado")
  end

  def load_users do
    path = Path.join(@data_dir, @users_file)
    case File.read(path) do
      {:ok, content} ->
        content
        |> String.split("\n", trim: true)
        |> Enum.map(&parse_user/1)
        |> Enum.into(%{})
      {:error, _} ->
        %{}
    end
  end

  def save_user(username, password, role) do
    users = load_users()
    users = Map.put(users, username, %{
      password: password,
      role: role,
      score: 0
    })

    content = Enum.map(users, fn {user, data} ->
      "#{user};#{data.password};#{data.role};#{data.score}"
    end)
    |> Enum.join("\n")

    path = Path.join(@data_dir, @users_file)
    File.write!(path, content)

    :ok
  end

  def user_exists?(username) do
    load_users() |> Map.has_key?(username)
  end

  def get_user(username) do
    load_users() |> Map.get(username)
  end

  def update_score(username, new_score) do
    users = load_users()
    if Map.has_key?(users, username) do
      user = users[username]
      updated_user = %{user | score: new_score}
      users = Map.put(users, username, updated_user)

      content = Enum.map(users, fn {u, data} ->
        "#{u};#{data.password};#{data.role};#{data.score}"
      end)
      |> Enum.join("\n")

      path = Path.join(@data_dir, @users_file)
      File.write!(path, content)
    end
    :ok
  end

  defp parse_user(line) do
    [username, password, role, score] = String.split(line, ";")
    {username, %{
      password: password,
      role: role,
      score: String.to_integer(score)
    }}
  end
end
