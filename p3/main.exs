#AUTORES: Sergio Herrero ; Alex Oarga
#NIAs:    698521 ; 718123
#FICHERO: 
#FECHA:  
#TIEMPO: 
#DESCRIPCION:


defmodule Fail do

  Code.require_file("amigos.exs")
  Code.require_file("worker.exs")

  def timestamp do
    :os.system_time(:milli_seconds)  
  end

  defp action({proxy_pid, proxy_dir} , {worker_reg, worker_dir}, {natural, m, resLista}, {timeout, retry}) when retry < 5 do
	IO.puts("I")
	IO.puts(timestamp)
	IO.puts("O")
	send({worker_reg, worker_dir}, {:req, { proxy_pid, proxy_dir, m, natural, resLista}})
	receive do
	  {:res, result} ->   
		result		
	after
	  timeout -> action({proxy_pid, proxy_dir} , {worker_reg, worker_dir}, {natural, m, resLista}, {timeout, retry + 1})
	end
  end

  defp action({proxy_pid, proxy_dir} , {worker_reg, worker_dir}, {natural, m, resLista}, {timeout, retry}) when retry == 5 do
	IO.puts("TIMEOUT")
	0
  end

  defp proxy_loop( {my_reg, my_dir}, pid_proxy_lider) do
	receive do
	  {:req_proxy, reg, dir, natural, unused} -> 
		send( pid_proxy_lider, {:request_lider, my_reg})
		receive do
		  {:res_lider, lider} -> 
		
			{worker_tipo2_reg, worker_tipo2_dir} = Enum.at(lider, 1)
			resultado = action({my_reg, my_dir} , {worker_tipo2_reg, worker_tipo2_dir}, {natural, 1, []}, {5000, 0})
			IO.puts("ENVIADO A WORKER")
			if resultado == 0 do
			  {worker_tipo1_reg, worker_tipo1_dir} = Enum.at(lider, 0)
			  resultado = action({my_reg, my_dir} , {worker_tipo1_reg, worker_tipo1_dir}, {natural, 1, []}, {5000, 0})
			  if resultado == 0 do
				IO.puts("ERROR WORKER 1 Y 2")
			  else
				{worker_tipo3_reg, worker_tipo3_dir} = Enum.at(lider, 2)
				resultado = action({my_reg, my_dir} , {worker_tipo3_reg, worker_tipo3_dir}, {natural, 1, resultado}, {5000, 0})
				if(resultado == 0) do
				  IO.puts("ERROR WORKER 1 Y 3")
				else
				  IO.puts("CORRECTO 1 Y 3")
				  send({:"master", :"master@127.0.0.1"}, {:resultado, resultado, natural, my_reg})
				end
			  end
			else
			  IO.puts("CORRECTO WORKER 2")
			  send({:"master", :"master@127.0.0.1"}, {:resultado, resultado, natural, my_reg})
			end	#if
		end #receive
	end	#receive
	proxy_loop( {my_reg, my_dir}, pid_proxy_lider)
  end

  def proxy_lider( lider ) do
	receive do
	  {:request_lider, pid_proxy} -> send(pid_proxy, {:res_lider, lider})
	  {:soy_lider, {reg_lider, dir_lider}, tipo} -> 
		IO.puts("NUEVO LIDER")
		lider = List.replace_at(lider, tipo-1, {reg_lider, dir_lider})
		IO.inspect(lider)
	end
	proxy_lider( lider )
  end

  def enviar_eleccion( {id, my_reg, my_dir}, [{id_dest, reg_dest, dir_dest}|tail] ) do
	if id_dest > id do
	  IO.puts("envio eleccion")
	  IO.puts(dir_dest)
	  send( {reg_dest, dir_dest},  {:eleccion, my_reg, my_dir} )
	end
	if List.last(tail) != nil do
	  enviar_eleccion( {id, my_reg, my_dir}, tail)
	end
  end

  def enviar_soy_lider(proxy_dir, {id, my_reg, my_dir, tipo, my_worker}, [{id_dest, reg_dest, dir_dest}|tail]) do
	if List.last(tail) != nil and id_dest != id do
	  IO.puts(reg_dest)
	  IO.puts(dir_dest)
	  send({reg_dest, dir_dest},{:soy_lider, my_reg, my_dir})
	  enviar_soy_lider(proxy_dir, {id, my_reg, my_dir, tipo, my_worker}, tail)
	else
	  IO.puts("envio a proxy")
	  send({:"proxy_rec1", proxy_dir}, {:soy_lider, {my_worker, my_dir}, tipo})
	  send({:"proxy_rec2", proxy_dir}, {:soy_lider, {my_worker, my_dir}, tipo})
	end
  end

  def recibir_eleccion(proxy_dir, {id, my_reg, my_dir, tipo, my_worker}, [{id_dest, reg_dest, dir_dest}|tail] , grupo) do
	if id_dest > id do
	  receive do
		{:"ok",pid_rec, dir_rec} -> IO.puts("recibe ok") 
			bucle_recepcion(proxy_dir, {id, my_reg, my_dir, tipo, my_worker}, grupo, {pid_rec, dir_rec})
	  after
		200 -> IO.puts("LIDER") 
		enviar_soy_lider(proxy_dir, {id, my_reg, my_dir, tipo, my_worker}, grupo)
		bucle_recepcion(proxy_dir, {id, my_reg, my_dir, tipo, my_worker}, grupo, {my_reg, my_dir})
	  end
	else
	  if List.last(tail) != nil do
	  	recibir_eleccion(proxy_dir, {id, my_reg, my_dir, tipo, my_worker}, tail , grupo)
	  else
		IO.puts("LIDER") 
		enviar_soy_lider(proxy_dir, {id, my_reg, my_dir, tipo, my_worker}, grupo)
		bucle_recepcion(proxy_dir,  {id, my_reg, my_dir, tipo, my_worker}, grupo, {my_reg, my_dir})
	  end
	end
  end

  def bucle_recepcion(proxy_dir, {id, my_reg, my_dir, tipo, my_worker}, grupo, {reg_lider, dir_lider}) do
	IO.puts("-------- recive")
	receive do
	  {:eleccion, pid_origen, dir_origen} -> IO.puts("envio ------> ok")
		send({pid_origen, dir_origen}, {:"ok", my_reg, my_dir})
		bucle_recepcion( proxy_dir, {id, my_reg, my_dir, tipo, my_worker}, grupo, {reg_lider, dir_lider})
	  {:soy_lider, pid_origen, dir_origen} ->
		IO.puts(" HAY NUEVO  LIDER")
		IO.puts(dir_origen)
		send({pid_origen, dir_origen}, {:pulso, my_reg, my_dir})
		bucle_recepcion(proxy_dir, {id, my_reg, my_dir, tipo, my_worker}, grupo, {pid_origen, dir_origen})
	  {:pulso, pid_origen, dir_origen} ->
		IO.puts("PULSO")
		send({pid_origen, dir_origen}, {:res_pulso, my_reg, my_dir})
		bucle_recepcion(proxy_dir, {id, my_reg, my_dir, tipo, my_worker}, grupo, {reg_lider, dir_lider})
	  {:res_pulso, pid_origen, dir_origen} ->
		IO.puts("RES PULSO")
		:timer.sleep(5000)
		if dir_origen == dir_lider do
		  send({pid_origen, dir_origen}, {:pulso, my_reg, my_dir})
		  bucle_recepcion(proxy_dir,  {id, my_reg, my_dir, tipo, my_worker}, grupo, {reg_lider, dir_lider})
		else
		  bucle_recepcion(proxy_dir, {id, my_reg, my_dir, tipo, my_worker}, grupo, {reg_lider, dir_lider})
		end
	after
	  10000 -> IO.puts("ELECCION")
		enviar_eleccion({id, my_reg, my_dir}, grupo)
		IO.puts("RECEPCION")
	    recibir_eleccion(proxy_dir, {id, my_reg, my_dir, tipo, my_worker}, grupo, grupo)
	end
	
  end

  def proxy_lider_init(id, lider) do
	myReg = String.to_atom("proxy_rec"<>Integer.to_string(id))
	Process.register(self(), myReg)
	proxy_lider(lider)
  end

  def proxy(id,  myDir , lider) do
	myReg = String.to_atom("proxy"<>Integer.to_string(id))
	Process.register(self(), myReg)
	pid = spawn(Fail, :proxy_lider_init, [id, lider])
	proxy_loop({myReg, myDir}, pid)
  end

  def bucle_recepcion_init(proxy_dir, {id, my_reg, my_dir, tipo, my_worker}, grupo, lider) do
	Process.register(self(), :"worker_rec")
	bucle_recepcion(proxy_dir, {id, my_reg, my_dir, tipo, my_worker}, grupo, lider)
  end

  def workerInit(id, myReg ,myDir, tipo, proxy_dir) do
	workers = [:"worker1", :"worker11", :"worker12", :"worker21", :"worker22", :"worker23", :"worker31", :"worker32", :"worker33"]
	if(tipo == 1) do
	  grupo = [{1, :"worker_rec", :"worker1@127.0.0.1"},{11, :"worker_rec", :"worker2@127.0.0.1"},{12, :"worker_rec", :"worker3@127.0.0.1"}]
      pid = spawn(Fail, :bucle_recepcion_init, [proxy_dir, {id, :"worker_rec", myDir, tipo, Enum.at(workers, id-1)}, grupo, {:"0" ,:"0"}])
      Process.register(self(), String.to_atom("worker" <> Integer.to_string(id)))
      Worker.loop(tipo)
	end
	if(tipo == 2) do
	  grupo = [{2, :"worker_rec", :"worker2@127.0.0.1"},{21, :"worker_rec", :"worker2@127.0.0.1"},{22, :"worker_rec", :"worker3@127.0.0.1"}]
      pid = spawn(Fail, :bucle_recepcion_init, [proxy_dir, {id, :"worker_rec", myDir, tipo, Enum.at(workers, id-1)}, grupo, {:"0" ,:"0"}])
      Process.register(self(), String.to_atom("worker" <> Integer.to_string(id)))
      Worker.loop(tipo)
	end
	if(tipo == 3) do
	  grupo = [{3, :"worker_rec", :"worker3@127.0.0.1"},{31, :"worker_rec", :"worker2@127.0.0.1"},{32, :"worker_rec", :"worker3@127.0.0.1"}]
      pid = spawn(Fail, :bucle_recepcion_init, [proxy_dir, {id, :"worker_rec", myDir, tipo, Enum.at(workers, id-1)}, grupo, {:"0" ,:"0"}])
      Process.register(self(), String.to_atom("worker" <> Integer.to_string(id)))
      Worker.loop(tipo)
	end
	
  end

  def recorrer(lista, n, my_dir) do
	IO.puts(timestamp())
	receive do
	  {:resultado, res, n, origen} -> IO.puts(res)
		lista = List.insert_at(lista, n, res)
		send({origen,:"master@127.0.0.1"}, {:req_proxy, :"master", my_dir, n+1, 30} )
		IO.puts(timestamp)
		if(n < 100) do
		  recorrer(lista, n, my_dir)
		end
	end
  end

  def master(my_dir) do
	pid_proxy_1 = spawn(Fail, :proxy, [1, my_dir, [{:"worker1",:"worker1@127.0.0.1"}, {:"worker2",:"worker2@127.0.0.1"}, {:"worker3",:"worker3@127.0.0.1"}]])
	pid_proxy_2 = spawn(Fail, :proxy, [2, my_dir, [{:"worker1",:"worker1@127.0.0.1"}, {:"worker2",:"worker2@127.0.0.1"}, {:"worker3",:"worker3@127.0.0.1"}]])
	Process.register(self(), :"master")
	:timer.sleep(2000)
	send({:"proxy1",:"master@127.0.0.1"}, {:req_proxy, :"master", my_dir, 3, 30} )
	send({:"proxy2",:"master@127.0.0.1"}, {:req_proxy, :"master", my_dir, 4, 30} )
	recorrer([0, 0, 0], 3, my_dir)
  end

end
