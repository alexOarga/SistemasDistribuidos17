require IEx # Para utilizar IEx.pry

defmodule ServidorGV do
    @moduledoc """
        modulo del servicio de vistas
    """

    # Tipo estructura de datos que guarda el estado del servidor de vistas
    # COMPLETAR  con lo campos necesarios para gestionar
    # el estado del gestor de vistas
    defstruct   num_vista: 0, primario: :undefined, copia: :undefined

    # Constantes
    @latidos_fallidos 4

    @intervalo_latidos 50


    @doc """
        Acceso externo para constante de latidos fallios
    """
    def latidos_fallidos() do
        @latidos_fallidos
    end

    @doc """
        acceso externo para constante intervalo latido
    """
   def intervalo_latidos() do
       @intervalo_latidos
   end

   @doc """
        Generar un estructura de datos vista inicial
    """
    def vista_inicial() do
        %{num_vista: 0, primario: :undefined, copia: :undefined}
    end

    @doc """
        Poner en marcha el servidor para gestión de vistas
        Devolver atomo que referencia al nuevo nodo Elixir
    """
    @spec startNodo(String.t, String.t) :: node
    def startNodo(nombre, maquina) do
                                         # fichero en curso
        NodoRemoto.start(nombre, maquina, __ENV__.file) ##Ruta fichero servidor_gv.exs
    end

    @doc """
        Poner en marcha servicio trás esperar al pleno funcionamiento del nodo
    """
    @spec startService(node) :: boolean
    def startService(nodoElixir) do
        NodoRemoto.esperaNodoOperativo(nodoElixir, __MODULE__)

        # Poner en marcha el código del gestor de vistas
        Node.spawn(nodoElixir, __MODULE__, :init_sv, [])
   end

    #------------------- FUNCIONES PRIVADAS ----------------------------------

    # Estas 2 primeras deben ser defs para llamadas tipo (MODULE, funcion,[])
    def init_sv() do
        Process.register(self(), :servidor_gv)

        spawn(__MODULE__, :init_monitor, [self()]) # otro proceso concurrente

        t_vista = %ServidorGV{num_vista: 0, primario: :undefined, copia: :undefined}
        v_vista = %ServidorGV{num_vista: 0, primario: :undefined, copia: :undefined}

        bucle_recepcion(t_vista, v_vista, [])
    end

    def init_monitor(pid_principal) do
        send(pid_principal, :procesa_situacion_servidores)
        Process.sleep(@intervalo_latidos)
        init_monitor(pid_principal)
    end


    defp bucle_recepcion(t_vista, v_vista, listaLatidos) do
        {t_vista,v_vista,listaLatidos} = receive do
                {:latido, 0, nodo_emisor} ->
                    if (t_vista.num_vista == 0) do ##Caso inicial, ningun nodo, nueva vista
                      t_vista = %{t_vista | num_vista: t_vista.num_vista + 1}##Suma numero vista + 1
                      t_vista = %{t_vista | primario: nodo_emisor} ##Nodo primario en vista
                      listaLatidos = listaLatidos ++ [{nodo_emisor,0}] ##Se añade a la lista
                      send({:servidor_sa, nodo_emisor}, {:vista_tentativa, t_vista, (t_vista == v_vista)})
                      {t_vista,v_vista,listaLatidos} ##Return
                    else ##t_vista.num_vista != 0
                      if(t_vista.copia == :undefined) do ##Si no hay copia
                        listaLatidos = listaLatidos ++ [{nodo_emisor,0}]
                        t_vista = %{t_vista | copia: nodo_emisor} ##Nodo copia en vista
                        t_vista = %{t_vista | num_vista: t_vista.num_vista + 1}##Suma numero vista + 1
                      else ##Hay primario y copia, entra en espera
                        listaLatidos = listaLatidos ++ [{nodo_emisor, 0}] ##Se añade como espera
                      end
                      send({:servidor_sa, nodo_emisor}, {:vista_tentativa, t_vista, t_vista == v_vista})
                      {t_vista,v_vista,listaLatidos} ##Return
                    end

                {:latido, -1, nodo_emisor} -> ##Situacion especial, primera contestacion
                    listaLatidos = Enum.map(listaLatidos, fn({pid, x}) -> if(pid == nodo_emisor) do
                                                                            {pid,0}
                                                                          else {pid, x}
                                                                          end end)
                      ##Se han reiniciado los latidos
                    send({:servidor_sa, nodo_emisor}, {:vista_tentativa, t_vista, t_vista == v_vista}) ##Se le envia la tentativa
                    {t_vista,v_vista,listaLatidos}

                {:latido, x, nodo_emisor} -> ##Llega el numero de visrta que tiene el cliente
                    if(x == t_vista.num_vista) do ##Mismo numero de vista que el servidor
                      listaLatidos = Enum.map(listaLatidos, fn({pid, x}) -> if(pid == nodo_emisor) do
                                                                            {pid,0}
                                                                          else {pid, x}
                                                                          end end)
                      ##Se han reiniciado los latidos
                      if(nodo_emisor == t_vista.primario) do ##El primario quiere confirmar vista valida
                        v_vista = t_vista ##Vista valida = vista tentativa
                        send({:servidor_sa, nodo_emisor}, {:vista_tentativa, t_vista, t_vista == v_vista}) ##Se le envia la valida
                      else ##Es otro nodo
                        send({:servidor_sa, nodo_emisor}, {:vista_tentativa, t_vista, t_vista == v_vista}) ##Se le envia la valida
                      end
                      {t_vista,v_vista,listaLatidos}
                    else ##La vista que llega no es igual a la tentativa
                      send({:servidor_sa, nodo_emisor}, {:vista_tentativa, t_vista, t_vista == v_vista}) ##Se le envia la tentativa
                      {t_vista,v_vista,listaLatidos}
                    end

                {:obten_vista, pid} -> send(pid, {:vista_valida, t_vista, t_vista==v_vista})
                                       {t_vista,v_vista,listaLatidos}

                :procesa_situacion_servidores ->
                    if(length(listaLatidos) > 0) do ##Solo tiene sentido si al menos, hay un nodo
                      ##Sumar 1 a todos los latidos fallidos de la lista
                      listaLatidos = Enum.map(listaLatidos, fn({x,xs}) -> {x, xs+1} end)
                      caidoPrim = comprobarPrimario(listaLatidos) ##Se comprueba si el caido es el primario
                      caidoCopi = comprobarCopia(listaLatidos)    ##Se comprueba si el caido es la copia
                      if(caidoCopi == true && caidoPrim==true) do ##ERROR CRITICO
                        IO.puts("ATENCION: ERROR CRITICO (SIN PRIMARIO Y SIN COPIA)")
                      end
                      if(caidoPrim == true && (t_vista==v_vista)) do ##El primario se ha caido
                        t_vista = %{t_vista | primario: v_vista.copia} ##Promociona copia a primario
                        t_vista = %{t_vista | num_vista: v_vista.num_vista + 1} ##Se aumenta
                        if(length(listaLatidos) >= 3) do ##Si Al menos hay uno en espera
                          t_vista = %{t_vista | copia: elem(Enum.at(listaLatidos,2),0)} ##Promociona espera a copia
                          #t_vista = %{t_vista | num_vista: v_vista.num_vista + 1} ##Se aumenta
                          listaLatidos = List.delete_at(listaLatidos,0) ##Se elimina el anterior primario
                        else ##No hay ninguno en espera, solo habra primario
                          t_vista = %{t_vista | copia: :undefined} ##Sin copia
                          listaLatidos = List.delete_at(listaLatidos,0) ##Se elimina el anterior primario
                        end
                      end
                      if(caidoCopi == true) do ##La copia se ha caido
                        if(length(listaLatidos) < 3) do ##No hay en espera, solo quedara el primario
                          IO.puts("ATENCION: ERROR (SOLO HAY NODO PRIMARIO SIN REPLICA)")
                          t_vista = %{t_vista | copia: :undefined} ##Sin copia
                          ##System.halt()
                        else
                          IO.puts("Detecto caida de copia")
                          t_vista = %{t_vista | copia: elem(Enum.at(listaLatidos,2),0)} ##Promociona espera a copia
                          t_vista = %{t_vista | num_vista: v_vista.num_vista + 1} ##Se aumenta
                          listaLatidos = List.delete_at(listaLatidos, 1) ##Se elimina de la lista la copia anterior
                        end
                      end
                      ##COMPROBAR LOS NODOS DE ESPERA
                      if(length(listaLatidos) > 2) do ##Si Al menos hay uno en espera
                          listaLatidos = Enum.drop_while(listaLatidos, fn({nodo,x}) -> ##Elimina los nodos caidos
                                              if(nodo != t_vista.primario && nodo != t_vista.copia) do ##Solo queremos los espera
                                                x >= latidos_fallidos() ##Devuelve true si tiene mas latidos fallidos
                                              else
                                                :false
                                              end end)
                      end
                    end
                    {t_vista,v_vista,listaLatidos}
        end ##RECEIVE
        bucle_recepcion(t_vista, v_vista, listaLatidos)
    end

    # OTRAS FUNCIONES PRIVADAS VUESTRAS
    ##Comprueba si la copia tiene @latidos_fallidos, solo si existe
    defp comprobarPrimario(listaLatidos) do
      if(elem(Enum.at(listaLatidos,0),1) >= latidos_fallidos()) do ##Lleva 4 fallos ya
        :true
      else
        :false
      end
    end

    ##Comprueba si la copia tiene @latidos_fallidos, solo si existe
    defp comprobarCopia(listaLatidos) do
      if(length(listaLatidos) > 1) do ##Hay copia
        if(elem(Enum.at(listaLatidos,1),1) >= latidos_fallidos()) do ##Lleva 4 fallos ya
          :true
        else
          :false
        end
      else
        :false
      end
    end
end
