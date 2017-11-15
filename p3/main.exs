#AUTORES: Sergio Herrero ; Alex Oarga
#NIAs:    698521 ; 718123
#FICHERO: 
#FECHA:  
#TIEMPO: 
#DESCRIPCION:


defmodule Fail do

  Code.require_file("amigos.exs")
  Code.require_file("worker.exs")

  def master(my_dir, proxy_dir) do
	Process.register(self(), :"master")
	send({:"proxy", proxy_dir}, {:req_proxy, :"master", my_dir, 20, 30} )
	IO.puts("enviado a proxy")
	receive do
	  {:res_master, result} -> IO.puts(result)
	end
  end

  defp action({proxy_pid, proxy_dir} , {worker_reg, worker_dir}, {natural, m, resLista}, {timeout, retry}) when retry < 5 do
	send({worker_reg, worker_dir}, {:req, { proxy_pid, proxy_dir, m, natural, resLista}})
	IO.puts("proxy envia a worker")	
	receive do
	  {:res, result} -> 
		IO.puts("proxy envia a master")	  
		result		
	after
	  timeout -> action({proxy_pid, proxy_dir} , {worker_reg, worker_dir}, {natural, m, resLista}, {timeout, retry + 1})
	end
  end

  defp action({proxy_pid, proxy_dir} , {worker_reg, worker_dir}, {natural, m, resLista}, {timeout, retry}) when retry == 5 do
	IO.puts("TIMEOUT")
	0
  end

  defp proxy_loop( my_dir, pid_proxy_lider) do
	receive do
	  {:req_proxy, reg, dir, 20, 30} -> IO.puts("proxy recibe")
		send( pid_proxy_lider, {:request_lider, self()})
		receive do
		  {:res_lider, lider} -> 
		
			{worker_tipo2_reg, worker_tipo2_dir} = Enum.at(lider, 1)
			resultado = action({:"proxy", my_dir} , {worker_tipo2_reg, worker_tipo2_dir}, {20, 1, []}, {100, 0})

			if resultado == 0 do
			  {worker_tipo1_reg, worker_tipo1_dir} = Enum.at(lider, 0)
			  resultado = action({:"proxy", my_dir} , {worker_tipo1_reg, worker_tipo1_dir}, {20, 1, []}, {100, 0})
			  if resultado == 0 do
				IO.puts("ERROR WORKER 1 Y 2")
			  else
				{worker_tipo3_reg, worker_tipo3_dir} = Enum.at(lider, 2)
				resultado = action({:"proxy", my_dir} , {worker_tipo3_reg, worker_tipo3_dir}, {20, 1, resultado}, {100, 0})
				if(resultado == 0) do
				  IO.puts("ERROR WORKER 1 Y 3")
				else
				  IO.puts("CORRECTO 1 Y 3")
				  IO.puts(resultado)
				end
			  end
			else
			  IO.puts("CORRECTO WORKER 2")
			end	#if
		end #receive
	end	#receive
  end

  def proxy_lider( param ) do
	lider = [{:"worker1",:"worker1@127.0.0.1"}, {:"worker2",:"worker2@127.0.0.1"}, {:"worker3",:"worker3@127.0.0.1"}]	
	receive do
	  {:request_lider, pid_proxy} -> send(pid_proxy, {:res_lider, lider})
	  {:soy_lider, {reg_lider, dir_lider}, tipo} -> lider = List.replace_at(lider, tipo-1, {reg_lider, dir_lider})
	end
  end

  def enviar_eleccion( {id, my_reg, my_dir}, [{id_dest, reg_dest, dir_dest}|tail] ) do
	if id_dest > id do
	  send( {reg_dest, dir_dest},  {:eleccion, my_reg, my_dir} )
	end
	if List.last(tail) != nil do
	  enviar_eleccion( {id, my_reg, my_dir}, tail)
	end
  end

  def enviar_soy_lider({id, my_reg, my_dir}, [{id_dest, reg_dest, dir_dest}|tail]) do
	if List.last(tail) != nil and id_dest != id do
	  IO.puts(reg_dest)
	  IO.puts(dir_dest)
	  send({reg_dest, dir_dest},{:soy_lider, my_reg, my_dir})
	  enviar_soy_lider({id, my_reg, my_dir}, tail)
	end
  end

  def recibir_eleccion( {id, my_reg, my_dir}, [{id_dest, reg_dest, dir_dest}|tail] , grupo) do
	if id_dest > id do
	  receive do
		{:ok, id_rec, dir_rec} -> bucle_recepcion( {id, my_reg, my_dir}, grupo, {id_rec, dir_rec})
	  after
		200 -> IO.puts("LIDER") 
		enviar_soy_lider({id, my_reg, my_dir}, grupo)
		bucle_recepcion( {id, my_reg, my_dir}, grupo, {my_reg, my_dir})
	  end
	else
	  recibir_eleccion( {id, my_reg, my_dir}, tail , grupo)
	end
  end

  def bucle_recepcion( {id, my_reg, my_dir}, grupo, lider) do
	IO.puts("-------- recive")
	receive do
	  {:eleccion, pid_origen, dir_origen} -> 
		send({my_reg, my_dir}, {:ok, my_reg, my_dir})
		bucle_recepcion( {id, my_reg, my_dir}, grupo, {my_reg, my_dir})
	  {:soy_lider, pid_origen, dir_origen} ->
		IO.puts("NUEVO  LIDER")
		send({pid_origen, dir_origen}, {:puslo, my_reg, my_dir})
		bucle_recepcion( {id, my_reg, my_dir}, grupo, {my_reg, my_dir})
	  {:pulso, pid_origen, dir_origen} ->
		IO.puts("PULSO")
		send({pid_origen, dir_origen}, {:res_puslo, my_reg, my_dir})
		bucle_recepcion( {id, my_reg, my_dir}, grupo, {my_reg, my_dir})
	  {:res_pulso, pid_origen, dir_origen} ->
		IO.puts("RES PULSO")
		send({pid_origen, dir_origen}, {:puslo, my_reg, my_dir})
		bucle_recepcion( {id, my_reg, my_dir}, grupo, {my_reg, my_dir})
	after
	  10000 -> IO.puts("ELECCION")
		enviar_eleccion({id, my_reg, my_dir}, grupo)
		IO.puts("RECEPCION")
	    recibir_eleccion({id, my_reg, my_dir}, grupo, grupo)
	end
	
  end

  def proxy( myDir ) do
	pid = spawn(Fail, :proxy_lider, [0])
	Process.register(self(), :"proxy")
	proxy_loop( myDir, pid)
  end

  def bucle_recepcion_init({id, my_reg, my_dir}, grupo, lider) do
	Process.register(self(), :"worker_rec")
	bucle_recepcion( {id, my_reg, my_dir}, grupo, lider)
  end

  def workerInit(id, myReg ,myDir, tipo, dirTipo) do
	grupo1 = [{1, :"worker_rec", :"worker1@127.0.0.1"},{2, :"worker_rec", :"worker2@127.0.0.1"},{3, :"worker_rec", :"worker3@127.0.0.1"}]
	pid = spawn(Fail, :bucle_recepcion_init, [{id, myReg, myDir}, grupo1, {id, myReg ,myDir}])
    Process.register(self(), String.to_atom("worker" <> Integer.to_string(id)))
    Worker.loop(tipo)
  end

end
