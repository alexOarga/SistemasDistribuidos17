#AUTORES: Sergio Herrero ; Alex Oarga
#NIAs:    698521 ; 718123
#FICHERO: chat.exs
#FECHA:   Noviembre 2017
#TIEMPO:  6 horas
#DESCRIPCION: Programa que implementa un chat
#	                             distribuido entre un grupo de
#                                  usuarios definidos (3). Lo que
#                                  uno escribe aparece inmediatamente
#                                  en las pantallas de los demas.
#EJECUCIÓN: El nombre de los nodos debe ser nodo0, nodo1, nodo2.
#			En el nodo x ejecutar la funcion init con los parametros:
#				init(x, "nodox@direccion")

defmodule Chat do

  # Proceso que contiene las variables compartidas
  def shared_database(ourSequenceNumber, highestSequenceNumber, requestingCriticalSection, replyDeferred, counter, waiting, defer_it) do
	receive do
	  {pid, :shared_vars} -> if counter == 0 do
						   waiting = waiting ++ [pid]
	  					 else
						   send(pid, {:shared_vars, ourSequenceNumber, highestSequenceNumber, requestingCriticalSection, replyDeferred, defer_it})
	  					   counter = counter - 1
	  					 end
						 shared_database(ourSequenceNumber, highestSequenceNumber, requestingCriticalSection, replyDeferred, counter, waiting, defer_it)
	  {:shared_vars_ME, ourSequenceNumber_2, requestingCriticalSection_2} -> counter = counter + 1
						if List.last(waiting) != nil do
						  send(List.first(waiting), {ourSequenceNumber_2, highestSequenceNumber, requestingCriticalSection_2, replyDeferred, defer_it} )
						  waiting = List.delete(waiting, 0)
						  shared_database(ourSequenceNumber_2, highestSequenceNumber, requestingCriticalSection_2, replyDeferred, counter, waiting, defer_it)
						else
						  counter = counter + 1
						  shared_database(ourSequenceNumber_2, highestSequenceNumber, requestingCriticalSection_2, replyDeferred, counter, waiting, defer_it)				
						end
	 {:shared_vars_RR, defer_it_2} -> counter = counter + 1
						if List.last(waiting) != nil do
						  send(List.first(waiting), {ourSequenceNumber, highestSequenceNumber, requestingCriticalSection, replyDeferred, defer_it_2} )
						  waiting = List.delete(waiting, 0)
						  shared_database(ourSequenceNumber, highestSequenceNumber, requestingCriticalSection, replyDeferred, counter, waiting, defer_it_2)
						else
						  counter = counter + 1
						  shared_database(ourSequenceNumber, highestSequenceNumber, requestingCriticalSection, replyDeferred, counter, waiting, defer_it_2)				
						end
	  {:set, :requestingCriticalSection, newValue} -> shared_database(ourSequenceNumber, highestSequenceNumber,newValue, replyDeferred, counter, waiting, defer_it)
      {pid, :get, :replyDeferred} -> send(pid, {:replyDeferred, replyDeferred})
									  shared_database(ourSequenceNumber, highestSequenceNumber, requestingCriticalSection, replyDeferred, counter, waiting, defer_it)
	  {:set, :replyDeferred, newValue, position} -> shared_database(ourSequenceNumber, highestSequenceNumber, requestingCriticalSection, List.replace_at(replyDeferred,position, newValue), counter, waiting, defer_it)
	  {:set, :highestSequenceNumber, k} -> shared_database(ourSequenceNumber, max(highestSequenceNumber, k),requestingCriticalSection, replyDeferred, counter, waiting, defer_it)    
	end
  end

  # Envia request a todos los nodos excepto a si mismo
  def send_request([{dest, dir} | tail], me, id, ourSequenceNumber, meDir) do
	if String.to_atom(dest) != me do
	  send({:"receive_request", String.to_atom(dir)}, {:request, ourSequenceNumber ,id,me, meDir})
    end
	if List.last(tail) != nil do
	  send_request(tail, me, id, ourSequenceNumber, meDir)
	end
  end

  # Espera reply de todos los nodos excepto de si mismo
  def wait_for_reply([{dest, dir} | tail], me) do
	if String.to_atom(dest) != me do   
	  receive do
		{:reply} -> nada = 1
	  end
    end
	if List.last(tail) != nil do
	  wait_for_reply(tail, me)
	end
  end

  # Envia reply a todos los nodos en deferred
  def send_reply_deferred([deferred | tail], [{dest, dir} | tailDest], pid, pos) do
	if deferred do
	  send(pid, {:set, :replyDeferred, false, pos})
	  send({String.to_atom(dest),String.to_atom(dir)}, {:reply})
	end
	if List.last(tail) != nil do
	  send_reply_deferred(tail, tailDest, pid, pos+1)
	end
  end
	
  # Envia el mensaje al chat de todos los nodos
  def send_chat_msg([{dest, dir} | tailDest], me, msg) do
	send( {:"receive_chat", String.to_atom(dir)}, {:msg, me, msg} )
	if List.last(tailDest) != nil do
	  send_chat_msg(tailDest, me, msg)
	end
  end

  # Pre-Protocol de la Seccion Critica
  def pre_protocol(pid, nodes, me, id, meDir) do
	send(pid, {self(), :shared_vars})
	receive do
	  {:shared_vars, ourSequenceNumber, highestSequenceNumber, requestingCriticalSection, replyDeferred, defer_it} ->
	  send(pid, {:shared_vars_ME, highestSequenceNumber + 1, true})
	  send_request(nodes, me, id, highestSequenceNumber + 1, meDir)
	end
	wait_for_reply(nodes, me)
  end

  # Post-Protocol de la Seccion Critica
  def post_protocol(pid, nodes, me, id, meDir) do
	send(pid, {:set, :requestingCriticalSection, false})
	send(pid, {self(), :get, :replyDeferred})
	receive do
	  {:replyDeferred, replyDeferred} -> send_reply_deferred(replyDeferred, nodes, pid, 0)
	end
  end

  # Proceso que lee de pantalla y solicita SC para enviarlo
  def mutual_exclusion(pid, nodes, me, id, meDir) do
	msg = IO.gets"->:"
	pre_protocol(pid, nodes, me, id, meDir)
	send_chat_msg(nodes, me, msg)
	post_protocol(pid, nodes, me, id, meDir)
	mutual_exclusion(pid, nodes, me, id, meDir)
  end

  # Receptor de los request
  def receives_request(pid, me) do
	receive do
	  {:request, k, j, origin, originDir} -> 
	  send(pid, {:set, :highestSequenceNumber, k})
	  send(pid, {self(), :shared_vars})
	  receive do
		{:shared_vars, ourSequenceNumber, highestSequenceNumber, requestingCriticalSection, replyDeferred, defer_it} ->
		deferIt = requestingCriticalSection and ((k > ourSequenceNumber) or (k==ourSequenceNumber and j>me))
		send(pid, {:shared_vars_RR, deferIt })
		if deferIt do
		  send(pid,  {:set, :replyDeferred, true, j})
		else
		  send({origin,String.to_atom(originDir)}, {:reply})
		end
	  end
	end
	receives_request(pid, me)
  end

  def receives_request_init(pid, me) do
	Process.register(self(), :"receive_request")
	receives_request(pid, me)
  end


  def receives_chat_messages_init do
	Process.register(self(), :"receive_chat")
	receives_chat_messages()
  end

  #Proceso que muestra por pantalla los mensajes
  def receives_chat_messages do
	receive do
	  {:msg, origin, msg} -> IO.puts("--->" <> Atom.to_string(origin) <> ": " <> msg)
	end
	receives_chat_messages()
  end

  def init(id, meDir) do
	meReg = String.to_atom("nodo" <> Integer.to_string(id))
	Process.register(self(), meReg)
	pid = spawn(Chat, :shared_database, [id, 0, false, [false, false, false], 1, [], false] )
	pid2 = spawn(Chat, :receives_request_init, [pid, id] )
	pid3 = spawn(Chat, :receives_chat_messages_init, [])
	nodos = [{"nodo0", "nodo0@127.0.0.1"},{"nodo1", "nodo1@127.0.0.1"},{"nodo2", "nodo2@127.0.0.1"}]
	mutual_exclusion(pid, nodos, meReg, id, meDir)
  end


end

