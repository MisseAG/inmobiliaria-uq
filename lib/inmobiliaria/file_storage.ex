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

  
end
