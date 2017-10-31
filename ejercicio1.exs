defmodule Chat do
  def shared_database(OurSequenceNumber, HighestSequenceNumber, RequestingCriticalSection, ReplyDeferred, counter, waiting) do
	receive do
	  {pid, :request} -> if counter == 0 do
						   waiting ++ [pid]
	  					 else
						   send(pid, {OurSequenceNumber, HighestSequenceNumber, RequestingCriticalSection, ReplyDeferred})
	  					   counter = counter - 1
	  					 end
						 shared_database(OurSequenceNumber, HighestSequenceNumber, RequestingCriticalSection, ReplyDeferred, counter, waiting)
	  {OurSequenceNumber_2, HighestSequenceNumber_2, RequestingCriticalSection_2, ReplyDeferred_2} -> counter = counter + 1
						if List.first(waiting) != nil do
						  send(List.first(waiting), {OurSequenceNumber_2, HighestSequenceNumber_2, RequestingCriticalSection_2, ReplyDeferred_2} )
						  shared_database(OurSequenceNumber_2, HighestSequenceNumber_2, RequestingCriticalSection_2, ReplyDeferred_2, counter, List.tail(waiting) )
						else
						  shared_database(OurSequenceNumber_2, HighestSequenceNumber_2, RequestingCriticalSection_2, ReplyDeferred_2, counter, waiting)
						end
    end
  end

end

