# Instrucciones ejecución

## Terminal 1 En la carpeta raíz del proyecto:
```
..\inmobiliria_uq> iex.bat --sname serv --cookie chocolate -S mix
```


## Clientes en otras terminales en la carpeta raíz del proyecto:
    \inmobiliria_uq> iex.bat --sname cli1 --cookie chocolate -S mix run --no-start

### 1. Conectar al servidor (usar el nombre que aparezca en el prompt del servidor)
    Node.connect(:"serv@nombrepc") 


### 2. Iniciar la interfaz
    Inmobiliaria.CLI.start()

### 3. Opción que agrupa las dos anteriores: Usar remote helper
    Inmobiliaria.RemoteHelper.unir(:"serv@nombrepc")
