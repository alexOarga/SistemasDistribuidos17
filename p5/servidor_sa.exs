Code.require_file("#{__DIR__}/cliente_gv.exs")

defmodule ServidorSA do
    
    # estado del servidor            
    defstruct   numVista: 0, 	# nose
				map: %{}, 		# map
				mutex: false,	# acceso secuencial a la escritura
				primario: :undefined,	# nodo primario, para saber si el mismo es primario
				copia: :undefined		# para saber quien es la copia


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
 

   		 #------------- VUESTRO CODIGO DE INICIALIZACION AQUI..........


         # Poner estado inicial
		atributos = %ServidorSA{numVista: 0, map: %{}, mutex: false, 
							primario: :undefined, copia: :undefined}

        bucle_recepcion_principal(atributos, nodo_servidor_gv) 
    end

	def init_monitor(pid_principal) do
        send(pid_principal, :envia_latido)
        Process.sleep(@intervalo_latidos)
        init_monitor(pid_principal)
	end

    defp bucle_recepcion_principal(atributos, nodo_servidor_gv) do
        atributos = receive do

                    # Solicitudes de lectura y escritura
                    # de clientes del servicio alm.
                  {op, param, nodo_origen}  -> IO.puts("")
											   atributos


                        # ----------------- vuestro código
                  :envia_latido ->
				      handle_result = ClienteGV.latido(nodo_servidor_gv, atributos.numVista )
					    {vista_inicial, false} -> IO.puts("SE HA CAIDO EL SERVIDOR") 
						{:vista_tentativa, vista_recibida, validado} ->
						  if(validado) do	
							# si la vista esta validada
							# envias un latido con el mismo numero de vista
							atributos = %{ atributos | numVista: vista_recibida.num_vista }
							ClienteGV.latido(nodo_servidor_gv, vista.numVista)
						  else
							# if( vista_recibida.num_vista == 1 ) do
								# CASO INICIAL
								ClienteGV.latido(nodo_servidor_gv, -1)
							  else
								if( atributos.numVista != vista_recibida.num_vista ) do
								  # numero de vista es diferente
								  # se actualiza la vista
								  atributos = %{ atributos | numVista: vista_recibida.num_vista,
															 primario: vista_recibida.primario,
															 copia: vista_recibida.copia }
								  if( soy_primario(atributos) ) do
									copiar_datos()	# copia datos en la copia
								  end
								end
								ClienteGV.latido(nodo_servidor_gv, atributos.numVista)
							  end
						 end



                  # --------------- OTROS MENSAJES QUE NECESITEIS
               end

        bucle_recepcion_principal( atributos, nodo_servidor_gv )
    end
    
    #--------- Otras funciones privadas que necesiteis .......
end
