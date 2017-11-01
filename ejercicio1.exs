defmodule Chat do

  # Proceso que contiene las variables compratidas
  def shared_database(ourSequenceNumber, highestSequenceNumber, requestingCriticalSection, replyDeferred, counter, waiting, defer_it) do
	IO.puts("shared")	
	receive do
	  {pid, :shared_vars} -> if counter == 0 do
						   IO.puts("wauting")
						   waiting = waiting ++ [pid]
	  					 else
						   IO.puts("if eslse")
						   send(pid, {ourSequenceNumber, highestSequenceNumber, requestingCriticalSection, replyDeferred, defer_it})
	  					   counter = counter - 1
	  					 end
						 shared_database(ourSequenceNumber, highestSequenceNumber, requestingCriticalSection, replyDeferred, counter, waiting, defer_it)
	  {:shared_vars_ME, ourSequenceNumber_2, requestingCriticalSection_2} -> counter = counter + 1
						if List.last(waiting) != nil do
						  IO.puts("desspiera")
						  send(List.first(waiting), {ourSequenceNumber_2, highestSequenceNumber, requestingCriticalSection_2, replyDeferred, defer_it} )
						  waiting = List.delete(waiting, 0)
						  shared_database(ourSequenceNumber_2, highestSequenceNumber, requestingCriticalSection_2, replyDeferred, counter, waiting, defer_it)
						else
						  counter = counter + 1
						  shared_database(ourSequenceNumber_2, highestSequenceNumber, requestingCriticalSection_2, replyDeferred, counter, waiting, defer_it)				
						end
	 {:shared_vars_RR, defer_it_2} -> counter = counter + 1
						if List.last(waiting) != nil do
						  IO.puts("desspiera")
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
	  IO.puts("enviadno request a " <> dest <> "+++" <> dir)
	  send({:"receive_request", String.to_atom(dir)}, {:request, ourSequenceNumber ,id,me, meDir})
    end
	if List.last(tail) != nil do
	  send_request(tail, me, id, ourSequenceNumber, meDir)
	end
  end

  # Espera reply de todos los nodos excepto de si mismo
  def wait_for_reply([{dest, dir} | tail], me) do
	if String.to_atom(dest) != me do   
	  IO.puts("esperando reply de " <> dir)
	  receive do
		{:reply} -> IO.puts("reply")
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
	  send({dest,String.to_atom(dir)}, {:reply})
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

  def pre_protocol(pid, nodes, me, id, meDir) do
	send(pid, {self(), :shared_vars})
	receive do
	  {ourSequenceNumber, highestSequenceNumber, requestingCriticalSection, replyDeferred, defer_it} ->
	  send(pid, {:shared_vars_ME, highestSequenceNumber + 1, true})
	  send_request(nodes, me, id, highestSequenceNumber + 1, meDir)
	end
	wait_for_reply(nodes, me)
  end

  def post_protocol(pid, nodes, me, id, meDir) do
	send(pid, {:set, :requestingCriticalSection, false})
	send(pid, {self(), :get, :replyDeferred})
	receive do
	  {:replyDeferred, replyDeferred} -> send_reply_deferred(replyDeferred, nodes, pid, 0)
	end
  end

  # Mutual exclusion process
  def mutual_exclusion(pid, nodes, me, id, meDir) do
	msg = IO.gets" Escribe mensaje:"
	pre_protocol(pid, nodes, me, id, meDir)
	IO.puts("----------SC")
	send_chat_msg(nodes, me, msg)
	post_protocol(pid, nodes, me, id, meDir)
	mutual_exclusion(pid, nodes, me, id, meDir)
  end

  # Receive request process
  def receives_request(pid, me) do
	IO.puts("recibiendo reqest....")
	receive do
	  {:request, k, j, origin, originDir} -> IO.puts("enviado reply a " <> originDir)
	  
	  send(pid, {:set, :highestSequenceNumber, k})
	  send(pid, {self(), :shared_vars})
	  IO.puts("debug")
	  receive do
		{ourSequenceNumber, highestSequenceNumber, requestingCriticalSection, replyDeferred, defer_it} -> IO.puts("V(SHARED)")
		deferIt = requestingCriticalSection and ((k > ourSequenceNumber) or (k==ourSequenceNumber and j>me))
		send(pid, {:shared_vars_RR, deferIt })
		if deferIt do
		  IO.puts("añade defered")
		  send(pid,  {:set, :replyDeferred, true, j})
		else
		  IO.puts("enviamos reply a "  <> originDir)
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

  def receives_chat_messages do
	receive do
	  {:msg, origin, msg} -> IO.puts("----------->" <> Atom.to_string(origin) <> ": " <> msg)
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

