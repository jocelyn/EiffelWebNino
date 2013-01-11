note
	description: "Summary description for {HTTP_CONNECTION}."
	date: "$Date$"
	revision: "$Revision$"

class
	HTTP_CONNECTION

create
	make

feature {NONE} -- Initialization

	make (a_socket: like socket; a_connection_id: like connection_id; a_action: like action)
		do
			socket := a_socket
			connection_id := a_connection_id
			action := a_action
		end

feature -- Settings

	is_verbose: BOOLEAN

feature -- Settings change

	set_is_verbose (b: BOOLEAN)
		do
			is_verbose := b
		end

feature -- Access

	action: PROCEDURE [ANY, TUPLE [USER_CONNECTION_HANDLER, TCP_STREAM_SOCKET]]

	socket: TCP_STREAM_SOCKET

	connection_id: NATURAL_64

feature -- Change

	set_action (a: like action)
		do
			action := a
		end

feature -- Execution

	execute
		local
			user_connection: USER_CONNECTION_HANDLER
    					-- last user connection served
    		done: BOOLEAN
    		retried: BOOLEAN
		do
			if not retried then
				socket.set_receive_buf_size (5_000)
					--| FIXME jfiat [2011/11/03] : should use a Pool of Threads/Handler to process this connection
					--| also handle permanent connection...?

	            create user_connection.make (connection_id, socket.descriptor, is_verbose)
				user_connection.set_remote_info

				from
					done := False
				until
					done -- as long as connection is kept alive.
				loop
					if user_connection.is_socket_handle_wrong then
						done := True
					else
						socket.set_linger_on (100)
						user_connection.analyze_request_message
						if not user_connection.has_error then
				            if user_connection.is_persistent then
				            	socket.set_linger_on (user_connection.keep_alive_time)
				            else
								socket.set_linger_on (0)
				            end
							if is_verbose then
								if user_connection.is_persistent then
									log (">INFO: Request for USER: " + user_connection.id.out + "." + user_connection.persistent_connection_id.out + " Serving Request")
								else
									log (">INFO: Request for USER: " + user_connection.id.out + " Serving Request")
								end
							end
							process_action (user_connection, user_connection.socket)
							if user_connection.is_persistent then
								socket.set_linger_on (user_connection.keep_alive_time)
								if is_verbose then
									log ("Keep connection alive (socket:" + socket.descriptor.out + ")%N")
								end
							else
								done := True
							end
						else
							done := True
						end
					end
				end
	--			if user_connection_handler.is_persistent then
	--				if is_verbose then
	--					log ("Keep connection (socket:" + socket.descriptor.out + ")%N")
	--				end
	--			else
					if is_verbose then
						log ("Clean connection (socket:" + socket.descriptor.out + ")%N")
					end
					socket.cleanup
	--			end
			else
				if is_verbose then
					log ("Trouble with connection (socket:" + socket.descriptor.out + ")%N")
				end
				socket.cleanup
			end
		rescue
			retried := True
			retry
		end

	process_action (req: USER_CONNECTION_HANDLER; soc: like socket)
		do
			action.call ([req, soc])
		end

feature {NONE} -- Implementation

	log (a_message: READABLE_STRING_8)
			-- Log `a_message'
		do
			io.error.put_string ("#" + connection_id.out + " " + a_message + "%N")
		end

end
