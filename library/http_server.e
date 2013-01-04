note
	description: "Summary description for {HTTP_SERVER}."
	author: ""
	date: "$Date$"
	revision: "$Revision$"

class
	HTTP_SERVER

create
	make

feature -- Initialization

	make (cfg: like configuration)
		do
			configuration := cfg
		end

	setup (a_http_handler: HTTP_HANDLER)
		require
			a_http_handler_valid: a_http_handler /= Void
		do
			if configuration.is_verbose then
				log ("%N%N%N")
				log ("Starting Web Application Server (port="+ configuration.http_server_port.out +"):%N")
			end
			stop_requested := False
			a_http_handler.launch
			run
		end

	shutdown_server
		do
			stop_requested := True
		end

feature	-- Access

	configuration: HTTP_SERVER_CONFIGURATION
			-- Configuration of the server

	stop_requested: BOOLEAN
			-- Stops the server

feature -- Output

	log (a_message: READABLE_STRING_8)
			-- Log `a_message'
		do
			io.put_string (a_message)
		end

feature -- implementation

	run
			-- Start the server
		local
			l_thread: EXECUTION_ENVIRONMENT
		do
			create l_thread
			from until stop_requested	loop
				l_thread.sleep (1000000)
			end

		end


;note
	copyright: "2011-2013, Javier Velilla and others"
	license: "Eiffel Forum License v2 (see http://www.eiffel.com/licensing/forum.txt)"
end
