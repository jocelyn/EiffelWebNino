note
	description: "Summary description for {HTTP_CONNECTION_HANDLER}."
	author: ""
	date: "$Date$"
	revision: "$Revision$"

deferred class
	HTTP_CONNECTION_HANDLER

inherit
	HTTP_LISTENER

feature -- Execution

	receive_message_and_send_reply (user_connection: USER_CONNECTION_HANDLER)
		local
			done: BOOLEAN
--			request_agent: PROCEDURE [ANY, TUPLE]

		do
			user_connection.set_remote_info
			from
				done := False
			until
				done
			loop
				if user_connection.is_socket_handle_wrong then
					done := True
				else
					user_connection.analyze_request_message
					if not user_connection.has_error then
						if is_verbose then
							if user_connection.is_persistent then
								log (">INFO: Request for USER: " + user_connection.id.out + "." + user_connection.persistent_connection_id.out + " Serving Request")
							else
								log (">INFO: Request for USER: " + user_connection.id.out + " Serving Request")
							end
						end
						process_request (user_connection, user_connection.socket)
						if not user_connection.is_persistent then
							done := True
						end
					else
						done := True
					end
				end
			end
		end

--feature -- Request processing

--	process_request (a_handler: USER_CONNECTION_HANDLER; a_socket: TCP_STREAM_SOCKET)
--			-- Process request ...
--		require

--			a_handler_attached: a_handler /= Void
--			a_uri_attached: a_handler.uri /= Void
--			no_error: a_handler /= Void implies not a_handler.has_error
--			a_method_attached: a_handler.method /= Void
--			a_header_map_attached: a_handler.request_header_map /= Void
--			a_header_text_attached: a_handler.request_header /= Void
--			a_socket_attached: a_socket /= Void
--		deferred
--		end

note
	copyright: "2011-2013, Javier Velilla and others"
	license: "Eiffel Forum License v2 (see http://www.eiffel.com/licensing/forum.txt)"
end
