note
	description : "nino application root class"
	date        : "$Date$"
	revision    : "$Revision$"

class
	APPLICATION

inherit
	ARGUMENTS

create
	make

feature {NONE} -- Initialization

	make
			-- Run application.
		local
			l_server : HTTP_SERVER
			l_cfg: separate HTTP_SERVER_CONFIGURATION
			l_http_handler : separate HTTP_HANDLER
		do
			create l_cfg.make
			set (l_cfg)

			create l_server.make (l_cfg)
			create {separate APPLICATION_CONNECTION_HANDLER} l_http_handler.make (l_server)
			l_server.setup (l_http_handler)
		end

	set (l_cfg: separate HTTP_SERVER_CONFIGURATION)
		do
			l_cfg.http_server_port := 9_000
			l_cfg.document_root := default_document_root
		end

feature -- Access

	default_document_root: STRING = "../webroot"

end
