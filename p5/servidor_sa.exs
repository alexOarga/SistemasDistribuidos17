Code.require_file("#{__DIR__}/cliente_gv.exs")

defmodule ServidorSA do

    # estado del servidor
    defstruct   num_vista: 0, 	#El numero de vista del servidor
				        datos: %{}, 	#Los datos almacenados
				        mutex: false,	#Acceso en ex. mutua de la escritura
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


    #------------- VUESTRO CODIGO DE INICIALIZACION AQUI..........
    atributos = %ServidorSA{num_vista: 0, 	#El numero de vista del servidor
				                    datos: %{}, 	#Los datos almacenados
				                    mutex: false,	#Acceso en ex. mutua de la escritura
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


    defp bucle_recepcion_principal(atributos, nodo_servidor_gv) do
        new_atributos = receive do

                    # Solicitudes de lectura y escritura
                    # de clientes del servicio alm.
                  {op, param, nodo_origen}  -> atributos


                        # ----------------- vuestro código


                  # --------------- OTROS MENSAJES QUE NECESITEIS
                  :envia_latido -> {:vista_tentativa, vista_recibida, validado} = ClienteGV.latido(nodo_servidor_gv, atributos.num_vista)
                                     #{vista_inicial, false} -> IO.puts("SE HA CAIDO EL SERVIDOR")
                                     #{:vista_tentativa, vista_recibida, validado} ->
                                        if(validado == true) do ##Es una vista validada
                                          atributos = %{ atributos | num_vista: vista_recibida.num_vista} #Actualiza el numero de vista
                                          ClienteGV.latido(nodo_servidor_gv, atributos.num_vista) #Se envia latido
                                        else #Es una vista no validada
                                          if(vista_recibida.num_vista == 1) do #CASO INICIAL
                                            ClienteGV.latido(nodo_servidor_gv, -1)
                                          else
                                            if(vista_recibida.num_vista != atributos.num_vista) do #los numeros de vista no coinciden
                                            atributos = %{ atributos | num_vista: vista_recibida.num_vista,
                                                                       primario: vista_recibida.primario,
                                                                       copia: vista_recibida.copia} #Actualiza vista completa
                                            if(vista_recibida.primario == self()) do #SI soy el primario, confirmo vista
                                              #COPIAR LOS DATOS A LA COPIA!
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

    #Devuelve si y solo si el nodo coincide con el primario de la vista
    def soy_primario(vista) do
      if (Node.self() == vista.primario) do
        :true
      else
        :false
      end
    end

    #Envia los datos almacenados al nodo copia
    def copiar_datos(nodo_copia) do
      if(nodo_copia != :undefined) do
        #Enviar datos a nodo copia, pero como sabes la direccion de nodo copia??????????????????????????????
        #Ademas, nodo copia tiene que tener un receive para recibir datos???????????????????????????????????
      end
    end
end
