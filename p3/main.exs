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

  defp action({proxy_pid, proxy_dir} , {reg, dir}, {natural, m}, {timeout, retry}) when retry < 5 do
	send({:"worker1", :"worker1@127.0.0.1"}, {:req, { proxy_pid, proxy_dir, 1, natural, []}})
	IO.puts("proxy envia a worker")	
	receive do
	  {:res, result} -> send( {reg, dir}, {:res_master, result})
		IO.puts("proxy envia a master")
	after
	  timeout -> action({proxy_pid, proxy_dir} , {reg, dir}, {natural, m}, {timeout, retry + 1})
	end
  end
  defp action({proxy_pid, proxy_dir} , {reg, dir}, {natural, m}, {timeout, retry}) when retry == 5 do
	send( {reg, dir}, {:res_master, "T I M E O U T"})
  end

  defp proxy_loop( my_dir) do
	receive do
	  {:req_proxy, reg, dir, 20, 30} -> IO.puts("proxy recibe")
		action({:"proxy", my_dir} , {reg, dir}, {20, 1}, {100, 0})
	end
  end

  def proxy( myDir ) do
	Process.register(self(), :"proxy")
	proxy_loop( myDir )
  end

  def worker1(myDir) do
    Process.register(self(), :"worker1")
    Worker.loop()
  end
	
  def worker2(myDir) do
    Process.register(self(), :"worker2")
    Worker.loop()
  end
	
  def worker3(myDir) do
    Process.register(self(), :"worker3")
    Worker.loop()
  end

end
