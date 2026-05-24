# generar_otp.exs
Mix.start()
Mix.Task.run("compile")
Application.ensure_all_started(:inmobiliaria)

{:ok, file} = File.open("arbol_otp.dot", [:write])
IO.binwrite(file, "digraph \"OTP Tree\" {\n")
IO.binwrite(file, "  rankdir=TB;\n")
IO.binwrite(file, "  node [shape=ellipse, style=filled, fillcolor=\"#E8F5E9\", color=\"#388E3C\", fontname=\"Arial\"];\n")
IO.binwrite(file, "  edge [color=\"#2E7D32\", penwidth=1.5];\n\n")

# Nodo raíz
IO.binwrite(file, "  \"Inmobiliaria.Supervisor\" [fillcolor=\"#C8E6C9\", penwidth=2];\n")

inspect_supervisor = fn supervisor_module, parent_name, indent, fun_rec ->
  case Supervisor.which_children(supervisor_module) do
    children ->
      Enum.each(children, fn {id, pid, type, _modules} ->
        display_id = if id == :undefined, do: "DynamicWorker", else: inspect(id)
        pid_str = inspect(pid)
        node_name = "#{display_id}\\n#{pid_str}"

        IO.puts("#{indent}├── #{display_id} [#{type}] - PID: #{pid_str}")

        node_style = if type == :supervisor, do: " [fillcolor=\"#C8E6C9\"]", else: ""
        IO.binwrite(file, "  \"#{node_name}\"#{node_style};\n")
        IO.binwrite(file, "  \"#{parent_name}\" -> \"#{node_name}\";\n")

        if type == :supervisor and is_pid(pid) do
          fun_rec.(pid, node_name, indent <> "│   ", fun_rec)
        end
      end)
    _ ->
      IO.puts("#{indent}└── [Error leyendo supervisor]")
  end
end

IO.puts("\n=== Árbol en Consola ===")
inspect_supervisor.(Inmobiliaria.Supervisor, "Inmobiliaria.Supervisor", "", inspect_supervisor)

IO.binwrite(file, "}\n")
File.close(file)
IO.puts("\n=== ¡Listo! Archivo 'arbol_otp.dot' generado con tus círculos y líneas ===")
