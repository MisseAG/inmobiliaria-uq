defmodule Inmobiliaria.CLI.UI do
  alias IO.ANSI

  @doc "Imprime el banner principal de bienvenida"
  def print_welcome do
  IO.puts """
  #{ANSI.cyan_background()}#{ANSI.black()}==================================================#{ANSI.reset()}
  #{ANSI.bright()}#{ANSI.cyan()}   ¡BIENVENIDO A LA INMOBILIARIA VIRTUAL! #{ANSI.reset()}
  #{ANSI.cyan_background()}#{ANSI.black()}==================================================#{ANSI.reset()}
  #{ANSI.italic()}Estado: Conectado al nodo #{ANSI.yellow()}#{node()}#{ANSI.reset()}

  #{ANSI.bright()}#{ANSI.underline()}COMANDOS DISPONIBLES:#{ANSI.reset()}

    #{ANSI.blue()}Autenticación:#{ANSI.reset()}
      #{ANSI.white()}> register <usuario> <clave> <rol>#{ANSI.reset()}
      #{ANSI.white()}> connect <usuario> <clave>#{ANSI.reset()}
      #{ANSI.white()}> online#{ANSI.reset()}
      #{ANSI.white()}> disconnect#{ANSI.reset()}

    #{ANSI.magenta()}Propiedades (Vendedor/Arrendador):#{ANSI.reset()}
      #{ANSI.white()}> publish_property <tipo> <ubicacion> <precio> <habitaciones> <area>#{ANSI.reset()}

    #{ANSI.magenta()}Propiedades (Cliente):#{ANSI.reset()}
      #{ANSI.white()}> list_properties#{ANSI.reset()}
      #{ANSI.white()}> buy_property <id>#{ANSI.reset()}
      #{ANSI.white()}> rent_property <id> <meses>#{ANSI.reset()}

    #{ANSI.yellow()}Mensajes:#{ANSI.reset()}
      #{ANSI.light_cyan()}Enviar mensaje a propiedad:#{ANSI.reset()}
      #{ANSI.white()}> send_message <prop_id> <mensaje>#{ANSI.reset()}
      #{ANSI.light_cyan()}Enviar mensaje a cliente:#{ANSI.reset()}
      #{ANSI.white()}> send_message_to <cliente> <mensaje>#{ANSI.reset()}
      #{ANSI.white()}> read_messages#{ANSI.reset()}

    #{ANSI.green()}Ranking:#{ANSI.reset()}
      #{ANSI.white()}> ranking#{ANSI.reset()}
      #{ANSI.white()}> ranking <rol>        (clientes | vendedores | arrendadores)#{ANSI.reset()}
      #{ANSI.white()}> my_score#{ANSI.reset()}

    #{ANSI.red()}Sistema:#{ANSI.reset()}
      #{ANSI.white()}> exit#{ANSI.reset()}
  #{ANSI.cyan_background()}#{ANSI.black()}--------------------------------------------------#{ANSI.reset()}
  """
end

  @doc "Formatea mensajes de éxito"
  def success(msg), do: IO.puts("#{ANSI.green()}✓ #{msg}#{ANSI.reset()}")

  @doc "Formatea mensajes de error"
  def error(msg), do: IO.puts("#{ANSI.red()}Error: #{msg}#{ANSI.reset()}")

  @doc "Formatea advertencias"
  def warn(msg), do: IO.puts("#{ANSI.yellow()}⚠ Advertencia: #{msg}#{ANSI.reset()}")

  @doc "Genera el string del prompt (input)"
  def build_prompt(nil, _), do: "#{ANSI.yellow()}invitado#{ANSI.reset()} #{ANSI.cyan()}>#{ANSI.reset()} "
  def build_prompt(user, role) do
    "#{ANSI.green()}#{user}#{ANSI.reset()}#{ANSI.faint()}(#{role})#{ANSI.reset()} #{ANSI.cyan()}>#{ANSI.reset()} "
  end
end
