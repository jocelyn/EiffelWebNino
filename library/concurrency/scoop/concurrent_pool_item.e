note
	description: "Summary description for {CONCURRENT_POOL_ITEM}."
	author: ""
	date: "$Date$"
	revision: "$Revision$"

deferred class
	CONCURRENT_POOL_ITEM [H]

feature	{NONE} -- Access

	pool: detachable separate CONCURRENT_POOL [CONCURRENT_POOL_ITEM [H], H]

	next_data (p: attached like pool): detachable separate H
		require
			p.has_queued_item or is_pool_stopping (p)
		do
			Result := p.next_queued_item
		end

	is_pool_stopping (p: attached like pool): BOOLEAN
		do
			Result := p.stop_requested
		end

feature {CONCURRENT_POOL} -- Execution

	pool_execute
		local
			done: BOOLEAN
		do
			from
			until
				done
			loop
				if attached pool as p then
					if attached next_data (p) as d then
						set_pool_data (d)
						execute
					end
					done := is_pool_stopping (p)
				else
					done := True
				end
			end
		end

	set_pool_data (d: separate H)
		deferred
		end

	execute
		deferred
		end

feature {CONCURRENT_POOL} -- Change

	set_pool (p: like pool)
		do
			pool := p
		end

feature {CONCURRENT_POOL, HTTP_HANDLER} -- Basic operation

	release
		do
			if attached pool as p then
				pool_release (p)
			end
		end

feature {NONE} -- Implementation

	pool_release (p: separate CONCURRENT_POOL [CONCURRENT_POOL_ITEM [H], H])
		do
			p.release_item (Current)
		end

note
	copyright: "2011-2013, Javier Velilla, Jocelyn Fiat and others"
	license: "Eiffel Forum License v2 (see http://www.eiffel.com/licensing/forum.txt)"
end
