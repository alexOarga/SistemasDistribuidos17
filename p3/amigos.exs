defmodule Amigos do
	#Devuelve la lista de todos los divisores de n, empezando con d=n-1  
	def divisores(n, d) do
		if(d > 0) do
		  if(rem(n, d) == 0) do
		    [d] ++ divisores(n, d-1)
		  else
		    divisores(n, d-1)
		  end
		else
			[]
		end
  end

	#Devuelve la suma de todos los elementos
	def sum_list([]), do: 0
	def sum_list([h|t]) do
		h + sum_list(t)
	end

	#Devuelve si son amigos los numeros a y b
	#Dos numeros son amigos si la suma de los divisores de a es igual a b, y
	#los divisores de b son igual a a.	
	def sonAmigos(a, b) do	
		(sum_list(divisores(a,a-1)) == b) && (sum_list(divisores(b,b-1)) == a)
  end




end
