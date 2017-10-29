#AUTORES: Sergio Herrero ; Alex Oarga
#NIAs:    698521 ; 718123
#FICHERO: chat.exs
#FECHA:   Noviembre 2017
#TIEMPO:  3 horas
#DESCRIPCION: Programa que implementa un chat
#	      distribuido entre un grupo de
#             usuarios definidos (3). Lo que
#             uno escribe aparece inmediatamente
#             en las pantallas de los demas.

defmodule Chat do
  
  #Para hacer una variable constante donde estan definidos todos los clientes
  def usuarios do
    [{:client1, :"c1@127.0.0.1"}, {:client2, :"c2@127.0.0.1"}]
  end

  def timestamp do
    :os.system_time(:milli_seconds)
  end

  def cliente(registro) do
    pid = spawn(fn -> mostrar() end) #Un hilo que se va a dedicar a mostrar
    Process.register(pid, registro) #Se registra el hilo
    IO.puts "Bienvenido al Chat"
    spawn(fn -> lectura() end) #Un hilo que se va a dedicar a leer de pantalla
    bucle() #Para hacer un bucle while true
  end

  def bucle do
    bucle()
  end

  def mostrar do
    receive do
      {c_pid, msg} -> IO.puts msg
    end
    mostrar
  end

  def lectura do
    msg = IO.gets "-> "
    prePro() #Solicita el acceso a SC para enviar mensaje
    #SECCION CRITICA
    Enum.each(usuarios, fn(p) -> send(p, {self(), msg}) end)
    #FIN SECCION CRITICA
    postPro() #POST-PROTOCOL
    lectura()
  end

  def prePro do
    Enum.each(usuarios, fn(p)-> send(p, {self(),timestamp()}) end)
    #ABRIA QUE RECIBIR TODOS LOS ACK
  end

  def postPro do
    #ENVIA ACK A TODOS LOS MENSAJES POSTERGADOS
  end

end
