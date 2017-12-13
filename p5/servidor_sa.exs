Code.require_file("#{__DIR__}/cliente_gv.exs")

defmodule ServidorSA do

    # estado del servidor
    defstruct   num_vista: 0, 	#El numero de vista del servidor
				        datos: %{}, 	#Los datos almacenados
				        primario: :undefined,	# nodo primario de la vista
				        copia: :undefined,		# nodo copia de la vista
                esValida: false #Para saber si dar el servicio o no



    @intervalo_latido 50


    @doc """
        Obtener el hash de un string Elixir
            - Necesario pasar, previamente,  a formato string Erlang
         - Devuelve entero
    """
    def hash(string_concatenado) do
        String.to_charlist(string_concatenado) |> :erlang.phash2
    end

    @doc """
        Poner en marcha el servidor para gestión de vistas
        Devolver atomo que referencia al nuevo nodo Elixir
    """
    @spec startNodo(String.t, String.t) :: node
    def startNodo(nombre, maquina) do
                                         # fichero en curso
        NodoRemoto.start(nombre, maquina, __ENV__.file)
    end

    @doc """
        Poner en marcha servicio trás esperar al pleno funcionamiento del nodo
    """
    @spec startService(node, node) :: pid
    def startService(nodoSA, nodo_servidor_gv) do
        NodoRemoto.esperaNodoOperativo(nodoSA, __MODULE__)

        # Poner en marcha el código del gestor de vistas
        Node.spawn(nodoSA, __MODULE__, :init_sa, [nodo_servidor_gv])
   end

    #------------------- Funciones privadas -----------------------------

    def init_sa(nodo_servidor_gv) do
        Process.register(self(), :servidor_sa)
        # Process.register(self(), :cliente_gv)
        spawn(__MODULE__, :init_monitor, [self()]) #Crear proceso de latidos
        spawn(__MODULE__, :init_lectores, [0]) #Concurrencia lectura
        spawn(__MODULE__, :init_mutex, []) #Concurrencia lectura


    #------------- VUESTRO CODIGO DE INICIALIZACION AQUI..........
    atributos = %ServidorSA{num_vista: 0, 	#El numero de vista del servidor
				                    datos: %{}, 	#Los datos almacenados
				                    primario: :undefined,	# nodo primario de la vista
				                    copia: :undefined,		# nodo copia de la vista
                            esValida: false} #Para saber si dar el servicio o no


         # Poner estado inicial
        bucle_recepcion_principal(atributos, nodo_servidor_gv)
    end

    # Para enviar latidos cada @intervalo_latidos
    def init_monitor(pid_principal) do
        send(pid_principal, :envia_latido)
        Process.sleep(@intervalo_latido)
        init_monitor(pid_principal)
    end

    # Para lectura y escritura en ex.mutua del valor de los lectores
    def init_lectores(num_lectores) do
        numero = receive do
          {:read, pid_c} -> send(pid_c, num_lectores) #Peticion lectura
                            num_lectores
          {:write, :suma, pid_c} -> num_lectores + 1 #Peticion escritura + 1
          {:write, :resta, pid_c} -> num_lectores - 1#peticion escritura - 1
        end
        init_lectores(numero)
    end

    def init_mutex() do
      Process.register(self(), :servicio_mutex) #Me registro
      servicio_mutex(1, [])
    end

    #Patron mutex, el counter representa la cuenta de los que llevan el mutex y q
    #es la lista de espera a que reciban el mutex
    def servicio_mutex(counter, q) do
      {n_coun, n_q} = receive do
        {:wait, pid_c} -> if(counter == 0) do #Si el mutex esta siendo usado
                              q = q ++ [pid_c]
                          else #Si no, se envia el mutex
                            send(pid_c, :ok)
                            counter = counter - 1
                          end
                          {counter, q}
        {_, pid_c} -> counter = counter + 1
                      if(q != []) do
                        send(hd(q), :ok)
                        counter = counter - 1
                        q = tl(q)
                      end
                      {counter,q}

      end
      servicio_mutex(n_coun, n_q)
    end


    defp bucle_recepcion_principal(atributos, nodo_servidor_gv) do
        new_atributos = receive do

                    # Solicitudes de lectura y escritura
                    # de clientes del servicio alm.
                  {:lee, clave, nodo_origen}  -> #Lectura de la base de datos
                      if(atributos.primario == Node.self()) do
                        send({:servicio_mutex,Node.self()},{:wait, self()}) #Pido el mutex
                        receive do
                          :ok -> IO.puts("")
                        end
                        send({:servicio_mutex,Node.self()},{:signal, self()}) #Devuelvo el mutex
                        valor = Map.get(atributos.datos, String.to_atom(clave))#Obtengo el valor
                        if(valor != nil) do #Tiene valor asociado
                          send({:cliente_sa, nodo_origen},{:resultado, valor})
                        else
                          send({:cliente_sa, nodo_origen},{:resultado, ""})
                        end
                      else #No soy el primario
                        send({:cliente_sa, nodo_origen},{:resultado, :no_soy_primario_valido})
                      end


                      atributos

                  {:escribe_generico, {clave, nuevo_valor, es_hash}, nodo_origen}  -> #Escritura de la base de datos
                      if(atributos.primario == Node.self()) do ##Solo escribo si soy nodo primario
                        #Pido el mutex
                        send({:servicio_mutex,Node.self()},{:wait, self()})
                        receive do
                          :ok -> IO.puts("->ACCESO A ESCRITURA")
                        end
                        #Pido el valor asociado, para saber si existe o no
                        valorAsociado = Map.get(atributos.datos, String.to_atom(clave))
                        if(valorAsociado != nil) do #Tiene un valor asociado
                          if(es_hash == false) do
                            datos_actualizados = Map.update(atributos.datos, String.to_atom(clave),
                                                            valorAsociado, fn valorAsociado -> nuevo_valor end)
                            atributos = %{atributos|datos: datos_actualizados}
                            #Copio los datos a la copia
                            copiar_datos(atributos.copia, atributos.datos)
                            #Envio el resultado
                            send({:cliente_sa, nodo_origen},{:resultado, nuevo_valor})
                          else ##Es escritura hash y ademas, tiene un valor asociado
                            val_aux = valorAsociado ##Esto es para enviar el antiguo valor, el hash si no, lo modifica
                            datos_actualizados = Map.update(atributos.datos, String.to_atom(clave),
                                                            valorAsociado, fn valorAsociado ->hash(valorAsociado <> nuevo_valor) end)
                            atributos = %{atributos|datos: datos_actualizados}
                            #Copio los datos a la copia
                            copiar_datos(atributos.copia, atributos.datos)
                            #Envio el resultado
                            send({:cliente_sa, nodo_origen},{:resultado, val_aux})
                          end
                        else #No tiene un valor asociado
                          if(es_hash == false) do
                            nuevos_datos = Map.merge(atributos.datos, Map.new([{String.to_atom(clave), nuevo_valor}]))
                            atributos = %{atributos|datos: nuevos_datos}
                            ##Copio los datos a la copia
                            copiar_datos(atributos.copia, atributos.datos)
                            #Envio el resultado
                            send({:cliente_sa, nodo_origen},{:resultado, nuevo_valor})
                          else ##Es escritura hash y ademas, NO tiene un valor asociado
                            nuevos_datos = Map.merge(atributos.datos, Map.new([{String.to_atom(clave), hash("" <> nuevo_valor)}]))
                            atributos = %{atributos|datos: nuevos_datos}
                            ##Copio los datos a la copia
                            copiar_datos(atributos.copia, atributos.datos)
                            #Envio el resultado
                            send({:cliente_sa, nodo_origen},{:resultado, ""})
                          end
                        end
                        send({:servicio_mutex,Node.self()},{:signal, self()}) #Devuelvo el mutex
                      else
                          send({:cliente_sa, nodo_origen},{:resultado, :no_soy_primario_valido})
                      end
                      atributos


                  {:copia_datos, nuevos_datos} -> ##Llega si soy nodo copia, y es para copiar los datos que me envian
                      atributos = %{atributos|datos: nuevos_datos}
                      atributos


                        # ----------------- vuestro código


                  # --------------- OTROS MENSAJES QUE NECESITEIS
                  :envia_latido -> {:vista_tentativa, vista_recibida, validado} = ClienteGV.latido(nodo_servidor_gv, atributos.num_vista)
                              if(validado == true) do ##Es una vista validada
                                atributos = %{ atributos | num_vista: vista_recibida.num_vista} #Actualiza el numero de vista
                                ClienteGV.latido(nodo_servidor_gv, atributos.num_vista) #Se envia latido
                              else #Es una vista no validada
                                if(vista_recibida.num_vista == 1 && vista_recibida.primario == Node.self()) do #CASO INICIAL
                                  atributos = %{atributos| num_vista: atributos.num_vista + 1}
                                  ClienteGV.latido(nodo_servidor_gv, -1)
                                else
                                  if(vista_recibida.num_vista != atributos.num_vista) do #los numeros de vista no coinciden
                                    atributos = %{ atributos | num_vista: vista_recibida.num_vista,
                                                               primario: vista_recibida.primario,
                                                               copia: vista_recibida.copia} #Actualiza vista completa
                                    if(vista_recibida.primario == Node.self()) do #SI soy el primario, confirmo vista
                                              #COPIAR LOS DATOS A LA COPIA!
                                              send({:servicio_mutex,Node.self()},{:wait, self()})
                                              receive do
                                                :ok -> copiar_datos(atributos.copia, atributos.datos)
                                                       IO.puts("COPIA HECHA: SERVICIO OK!")
                                              end
                                              send({:servicio_mutex,Node.self()},{:signal, self()})
                                    end
                                  end
                                  ClienteGV.latido(nodo_servidor_gv, atributos.num_vista)
                                end
                              end

                              atributos

               end ##END-RECEIVE

        bucle_recepcion_principal(new_atributos, nodo_servidor_gv)
    end

    #--------- Otras funciones privadas que necesiteis .......


    #Envia los datos almacenados al nodo copia
    def copiar_datos(nodo_copia, datos) do
      if(nodo_copia != :undefined) do
        send({:servidor_sa, nodo_copia},{:copia_datos, datos})
      end
    end
end
