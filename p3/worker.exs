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

  def loop(tipo) do
    loopI(init(), tipo)
  end

  defp loopI(worker_type, tipo) do
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
			  IO.puts(id_op)
			  send( {reg, dir} , {:res, op(tipo, natural, list)} )
			end
    end
    loopI(worker_type, tipo)
  end

  def op(m, n, list) do
		case {m,n,list} do
			{1, n, list} -> Amigos.divisores(n,n-1)
			{2, n, list} -> Amigos.sum_div(n)
			{3, n, list} -> Amigos.sum_list(list)
		end
	end

end
