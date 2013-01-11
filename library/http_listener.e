note
	description: "Summary description for {HTTP_LISTENER}."
	date: "$Date$"
	revision: "$Revision$"

deferred class
	HTTP_LISTENER

inherit
	ANY

	HTTP_CONSTANTS

	THREAD
    	rename
			make as thread_make
		end

feature {NONE} -- Initialization

	make (a_server: like server)
			-- Creates a {HTTP_LISTENER}, assigns the server and initialize various values
			--
			-- `a_server': The main server object
		require
			a_server_attached: a_server /= Void
		do
			thread_make
			server := a_server
			is_stop_requested := False
				--store client sockets
				--|TODO figure out the best value		
			create pool.make (10)--max_tcp_clients.to_natural_32)
				-- Create a pool of threads
		ensure
			server_set: a_server ~ server
		end

feature -- Output

	log (a_message: READABLE_STRING_8)
			-- Log `a_message'
		do
			io.error.put_string (a_message + "%N")
		end

feature -- Inherited Features

	execute
			-- <Precursor>
			-- Creates a socket and connects to the http server.
			-- TODO refactor this method is too complex
		local
			l_listening_socket: detachable TCP_STREAM_SOCKET
			l_http_port: INTEGER
			connection_id : NATURAL_64
		do
			connection_id := 0
			launched := False
			port := 0
			is_stop_requested := False
			l_http_port := http_server_port

			--create the server socket
			if
				attached http_server_name as l_servername and then
				attached (create {INET_ADDRESS_FACTORY}).create_from_name (l_servername) as l_addr
			then
				create l_listening_socket.make_server_by_address_and_port (l_addr, l_http_port)
			else
				create l_listening_socket.make_server_by_port (l_http_port)
			end

			-- listen for connections
			if not l_listening_socket.is_bound then
				if is_verbose then
					log ("Socket could not be bound on port " + l_http_port.out)
				end
			else
				l_http_port := l_listening_socket.port
				from
					l_listening_socket.listen (max_tcp_clients)
					if is_verbose then
						log ("%NHTTP Connection Server ready on port " + l_http_port.out +" : http://localhost:" + l_http_port.out + "/")
					end
					on_launched (l_http_port)
				until
					is_stop_requested
				loop
					l_listening_socket.accept
					if not is_stop_requested then
						if attached l_listening_socket.accepted as l_incoming_connection_socket then
							-- Incoming connection
							connection_id := connection_id + 1
							process_connection (l_incoming_connection_socket, connection_id)
						end
					end
					is_stop_requested := stop_requested_on_server
				end
				pool.wait_for_completion
				pool.terminate
				l_listening_socket.cleanup
				check
					socket_is_closed: l_listening_socket.is_closed
				end
			end
			if launched then
				on_stopped
			end
			if is_verbose then
				log ("HTTP Connection Server ends.")
			end
		rescue
			log ("HTTP Connection Server shutdown due to exception. Please relaunch manually.")

			if l_listening_socket /= Void then
				l_listening_socket.cleanup
				check
					socket_is_closed: l_listening_socket.is_closed
				end
			end
			if launched then
				on_stopped
			end
			is_stop_requested := True
			retry
		end

	new_connection (a_socket: TCP_STREAM_SOCKET; a_connection_id : NATURAL_64): HTTP_CONNECTION
		do
			create Result.make (a_socket, a_connection_id, agent process_request)
		end

	process_connection (a_socket: TCP_STREAM_SOCKET; a_connection_id: NATURAL_64)
		local
			conn: HTTP_CONNECTION
		do
			if is_verbose then
				log ("------------------------------")
				log ("#" + a_connection_id.out + " Incoming connection...(socket:" + a_socket.descriptor.out + ")")
			end

			conn := new_connection (a_socket, a_connection_id)
			conn.set_is_verbose (is_verbose)

			pool.add_work (agent conn.execute)
		end

feature -- Request processing

	process_request (a_handler: USER_CONNECTION_HANDLER; a_socket: TCP_STREAM_SOCKET)
			-- Process request ...
		require
			a_handler_attached: a_handler /= Void
			a_uri_attached: a_handler.uri /= Void
			no_error: a_handler /= Void implies not a_handler.has_error
			a_method_attached: a_handler.method /= Void
			a_header_map_attached: a_handler.request_header_map /= Void
			a_header_text_attached: a_handler.request_header /= Void
			a_socket_attached: a_socket /= Void
		deferred
		end

feature -- Event

	on_launched (a_port: INTEGER)
			-- Server launched using port `a_port'
		require
			not_launched: not launched
		do
			launched := True
			port := a_port
		ensure
			launched: launched
		end

	on_stopped
			-- Server stopped
		require
			launched: launched
		do
			launched := False
		ensure
			stopped: not launched
		end

feature -- Access

	is_stop_requested: BOOLEAN
			-- Set true to stop accept loop

	launched: BOOLEAN
			-- Server launched and listening on `port'

	port: INTEGER
			-- Listening port.
			--| 0: not launched

feature -- Access: configuration

	is_verbose: BOOLEAN
			-- Is verbose for output messages.
		do
			Result := server_configuration.is_verbose
		end

	force_single_threaded: BOOLEAN
		do
			Result := server_configuration.force_single_threaded
		end

	http_server_name: detachable STRING
		do
			Result := server_configuration.http_server_name
		end

	http_server_port: INTEGER
		do
			Result := server_configuration.http_server_port
		end

	max_tcp_clients: INTEGER
		do
			Result := server_configuration.max_tcp_clients
		end

feature {NONE} -- Access: server	

	server: HTTP_SERVER
			-- The main server object

	stop_requested_on_server: BOOLEAN
			-- Stop requested on `server' object
		do
			Result := server.stop_requested
		end

feature {NONE} -- Access: configuration

	server_configuration:  HTTP_SERVER_CONFIGURATION
			-- The main server's configuration
		do
			Result := server.configuration
		end

feature -- Status setting

	shutdown
			-- Stops the thread
		do
			is_stop_requested := True
		end

feature -- Execution

--	receive_message_and_send_reply (client_socket: TCP_STREAM_SOCKET)
--		require
--			socket_attached: client_socket /= Void
----			socket_valid: client_socket.is_open_read and then client_socket.is_open_write
--			a_http_socket: not client_socket.is_closed
--		deferred
--		end

--	receive_message_and_send_reply (client_socket: TCP_STREAM_SOCKET; id : INTEGER)
--		require
--			socket_attached: client_socket /= Void
--			a_http_socket: not client_socket.is_closed
--		deferred
--		end

--	receive_message_and_send_reply (user_connection: USER_CONNECTION_HANDLER)
--		deferred
--		end

feature -- Connection Pool

    pool : THREAD_POOL [ANY]

invariant
	server_attached: server /= Void

note
	copyright: "2011-2013, Javier Velilla and others"
	license: "Eiffel Forum License v2 (see http://www.eiffel.com/licensing/forum.txt)"
end
