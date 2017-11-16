defmodule Worker do

  Code.require_file("amigos.exs")

  def init do 
    case :random.uniform(100) do
      #random when random > 80 -> :crash
      #random when random > 50 -> :omission
      #random when random > 25 -> :timing
      _ -> :no_fault
    end
  end  

  def loop do
    loopI(init())
  end

  defp loopI(worker_type) do
    delay = case worker_type do
      :crash -> if :random.uniform(100) > 75, do: :infinity
      :timing -> :random.uniform(100)*1000
      _ ->  0
    end
    Process.sleep(delay)
    result = receive do
     {:req, { reg, dir, id_op, natural, list}} ->
			IO.puts("recibido")
            if (((worker_type == :omission) and (:random.uniform(100) < 75)) or (worker_type == :timing) or (worker_type==:no_fault)) do 
			  IO.puts(op(id_op, natural, list))
			  send( {reg, dir} , {:res, op(id_op, natural, list)} )
			end
    end
    loopI(worker_type)
  end

  defp op(m, n, list) do
	if m == 0 do
	  Amigos.divisores(n, 1)
	end
	if m == 1 do
	  Amigos.sum_list( Amigos.divisores(n, 1) )
	end
	if m == 2 do
	  Amigos.sum_list( list )
	end
  end

end
