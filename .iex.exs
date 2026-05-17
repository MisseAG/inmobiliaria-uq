# Script de prueba para validar la implementación

IO.puts("Iniciando validación del módulo de propiedades...")

# Prueba 1: Verificar que los módulos existen
IO.puts("\n=== Test 1: Módulos compilados ===")
modules = [
  Inmobiliaria.Property,
  Inmobiliaria.PropertyManager,
  Inmobiliaria.PropertySupervisor,
  Inmobiliaria.FileStorage,
  Inmobiliaria.Location,
  Inmobiliaria.SessionHandler
]

Enum.each(modules, fn mod ->
  case Code.ensure_loaded(mod) do
    {:module, _} -> IO.puts("✓ #{mod} cargado")
    {:error, _} -> IO.puts("✗ Error cargando #{mod}")
  end
end)

# Prueba 2: Verificar funciones públicas
IO.puts("\n=== Test 2: Funciones públicas ===")
IO.puts("PropertyManager.publish/1: #{Kernel.function_exported?(Inmobiliaria.PropertyManager, :publish, 1)}")
IO.puts("PropertyManager.list_all/0: #{Kernel.function_exported?(Inmobiliaria.PropertyManager, :list_all, 0)}")
IO.puts("PropertyManager.filter/1: #{Kernel.function_exported?(Inmobiliaria.PropertyManager, :filter, 1)}")
IO.puts("PropertyManager.find/1: #{Kernel.function_exported?(Inmobiliaria.PropertyManager, :find, 1)}")
IO.puts("Property.get_info/1: #{Kernel.function_exported?(Inmobiliaria.Property, :get_info, 1)}")
IO.puts("Property.reserve/1: #{Kernel.function_exported?(Inmobiliaria.Property, :reserve, 1)}")
IO.puts("Property.complete_sale/2: #{Kernel.function_exported?(Inmobiliaria.Property, :complete_sale, 2)}")

# Prueba 3: Verificar ubicaciones válidas
IO.puts("\n=== Test 3: Validación de ubicaciones ===")
Enum.each(Inmobiliaria.Location.all(), fn loc ->
  result = Inmobiliaria.Location.valid?(loc)
  IO.puts("  #{loc}: #{result}")
end)

IO.puts("\n✓ Validación completada. Sistema listo para pruebas completas.")
