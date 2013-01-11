note
	description: "Summary description for {USER_CONNECTION_HANDLER}."
	author: ""
	date: "$Date$"
	revision: "$Revision$"

class
	USER_CONNECTION_HANDLER

create
	make

feature -- Initialization

    make (a_id: NATURAL_64; socket_descriptor: INTEGER;  verbose : BOOLEAN)
	    -- create with an ID and a file descriptor
    	do

        	create socket.create_from_descriptor (socket_descriptor)
        	connection_id := a_id
        	persistent_connection_id := 0
        	is_verbose := verbose
        	reset
        rescue
        	if is_verbose then
        		log("Error creating user connection handler")
        	end
    	end

	reset
		do
			has_error := False
			is_persistent := False
			keep_alive_time := 30 -- seconds
			create method.make_empty
			create uri.make_empty
			create request_header.make_empty
			create request_header_map.make (10)
			remote_info := Void
			done := False
		end

 feature -- Access

	done : BOOLEAN
		-- is the current connection finished?

	request_header: STRING
			-- Header' source

	request_header_map : HASH_TABLE [STRING,STRING]
			-- Contains key:value of the header

	has_error: BOOLEAN
			-- Error occurred during `analyze_request_message'

	method: STRING
			-- http verb

	uri: STRING
			--  http endpoint

	is_persistent: BOOLEAN
			-- is a persistent connection present?

	keep_alive_time: INTEGER
			-- Keep-alive time (default: 30sec)

	version: detachable STRING
			--  http_version
			--| unused for now

	remote_info: detachable TUPLE [addr: STRING; hostname: STRING; port: INTEGER]
			-- Information related to remote client


	is_socket_handle_wrong : BOOLEAN
		do
           if socket = Void or socket.bad_socket_handle then
                -- this means something has gone wrong. quit.
                Result := true

                if is_verbose then
                	if is_persistent then
	                    log("INFO: Request for user:"+ id.out + "Error while serving: invalidated socket")
	                else
	                	log("INFO: Request for user:"+ id.out + "." + persistent_connection_id.out + "Error while serving: invalidated socket")
                	end
                end
           end
         end

feature -- info

	set_remote_info
		local
			l_remote_info :like remote_info
		do
			create l_remote_info
			if attached socket.peer_address as l_addr then
				l_remote_info.addr := l_addr.host_address.host_address
				l_remote_info.hostname := l_addr.host_address.host_name
				l_remote_info.port := l_addr.port
				remote_info := l_remote_info
				log(l_remote_info.out)
			end
		end

	set_done
		do
			done := True
		end

feature -- Parsing

	analyze_request_message
	    require
            input_readable: socket /= Void and then socket.is_open_read
        local
        	end_of_stream : BOOLEAN
        	pos,n : INTEGER
        	line : detachable STRING
			k, val: STRING
        	txt: STRING
			l_is_verbose: BOOLEAN
        do
            create txt.make (64)
			request_header := txt

			persistent_connection_id := persistent_connection_id + 1


			if attached next_line (socket) as l_request_line and then not l_request_line.is_empty then
				txt.append (l_request_line)
				txt.append_character ('%N')
				analyze_request_line (l_request_line)
			else
				has_error := True
			end

			l_is_verbose := is_verbose

			if not has_error or l_is_verbose then
					-- if `is_verbose' we can try to print the request, even if it is a bad HTTP request
				from
					line := next_line (socket)
				until
					line = Void or end_of_stream
				loop
					n := line.count
					if l_is_verbose then
						log (line)
					end
					pos := line.index_of (':',1)
					if pos > 0 then
						k := line.substring (1, pos-1)
						if line [pos+1].is_space then
							pos := pos + 1
						end
						if line [n] = '%R' then
							n := n - 1
						end
						val := line.substring (pos + 1, n)
						request_header_map.put (val, k)
					end
					txt.append (line)
					txt.append_character ('%N')
					if line.is_empty or else line [1] = '%R' then
						end_of_stream := True
					else
						line := next_line (socket)
					end
				end
			end
			if
				attached request_header_map.item ("Connection") as l_connection_header and then
				l_connection_header.is_case_insensitive_equal ("keep-alive")
			then
				is_persistent := True
				if
					attached request_header_map.item ("Keep-Alive") as l_keep_alive_header and then
					l_keep_alive_header.is_integer
				then
					keep_alive_time := l_keep_alive_header.to_integer
				else
					keep_alive_time := 30 -- default
				end
			else
				is_persistent := False
				keep_alive_time := 0
				persistent_connection_id := 0
			end
		end

	analyze_request_line (line: STRING)
			-- Analyze `line' as a HTTP request line
		require
			valid_line: line /= Void and then not line.is_empty
		local
			pos, next_pos: INTEGER
		do
			if is_verbose then
				log ("%N## Parse HTTP request line ##")
				log (line)
			end
			pos := line.index_of (' ', 1)
			method := line.substring (1, pos - 1)
			next_pos := line.index_of (' ', pos + 1)
			uri := line.substring (pos + 1, next_pos - 1)
			version := line.substring (next_pos + 1, line.count)
			has_error := method.is_empty
		end

	next_line (a_socket: TCP_STREAM_SOCKET): detachable STRING
			-- Next line fetched from `a_socket' is available.
		require
			is_readable: a_socket.is_open_read
		local
--			current_retries: INTEGER
		do
			if a_socket.socket_ok and not a_socket.bad_socket_handle  then
				a_socket.read_line_thread_aware
				Result := a_socket.last_string
			end
		rescue
			if is_verbose then
				log (a_socket.error)
			end
		end

 feature -- Implementation

 	socket: TCP_STREAM_SOCKET
    connection_id: NATURAL_64

    persistent_connection_id: NATURAL_32
    		-- when `is_persistent' is True

    id: INTEGER
    	obsolete "use `connection_id' [2013-jan]"
    	do
    		Result := connection_id.to_integer_32
    	end

    is_verbose : BOOLEAN


feature -- Close
	close
		do
			socket.close
		end

feature -- Output

	log (a_message: READABLE_STRING_8)
			-- Log `a_message'
		do
			if persistent_connection_id > 0 then
				io.put_string ("#" + connection_id.out + "." + persistent_connection_id.out + " " + a_message + "%N")
			else
				io.put_string ("#" + connection_id.out + " " + a_message + "%N")
			end
		end

invariant
	request_header_attached: request_header /= Void


;note
	copyright: "2011-2013, Javier Velilla and others"
	license: "Eiffel Forum License v2 (see http://www.eiffel.com/licensing/forum.txt)"
end
