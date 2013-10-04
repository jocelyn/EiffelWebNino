note
	description: "Summary description for {CONCURRENT_POOL}."
	author: ""
	date: "$Date$"
	revision: "$Revision$"

deferred class
	CONCURRENT_POOL [G -> CONCURRENT_POOL_ITEM [H], H]

feature {NONE} -- Initialization

	make (n: INTEGER)
		do
			capacity := n
			create items.make_empty (n)
--			create available_items.make_empty (n)
--			create busy_items.make_filled (False, n)
			create busy_items.make_empty (n)
			create queue.make (0)
		end

feature -- Access

	count: INTEGER

	is_full: BOOLEAN
		do
			Result := count >= capacity
		end

	capacity: INTEGER

	stop_requested: BOOLEAN

	has_queued_item: BOOLEAN
		do
			Result := not queue.is_empty
		end

	next_queued_item: detachable separate H
		do
			if queue.is_empty then
			else
				Result := queue.first
				queue.start
				queue.remove
				if Result /= Void then
					count := count + 1
				end
			end
		end

feature -- Access

	separate_item: detachable separate G
		require
			is_not_full: not is_full
		local
			i,n,pos: INTEGER
			lst: like busy_items
			l_item: detachable separate G
		do
			if not stop_requested then
				from
					lst := busy_items
					pos := -1
					i := 0
					n := lst.count - 1
				until
					i > n or l_item /= Void or pos >= 0
				loop
					if not lst [i] then -- is free (i.e not busy)
						pos := i

						if items.valid_index (pos) then
							l_item := items [pos]
							if l_item /= Void then
								busy_items [pos] := True
							end
						end
						if l_item = Void then
								-- Empty, then let's create one.
							l_item := new_separate_item
							register_item (l_item)
							items [pos] := l_item
						end
					end
					i := i + 1
				end
				if l_item = Void then
						-- Pool is FULL ...
					check overcapacity: False end
				else
					debug ("pool")
						print ("Lock pool item #" + pos.out + " (free:"+ (capacity - count).out +"))%N")
					end
					count := count + 1
					busy_items [pos] := True
					Result := l_item
				end
			end
		end

feature -- Basic operation

	process_data (a_data: separate H)
		do
			queue.force (a_data)
		end

	gracefull_stop
		do
			stop_requested := True
		end

feature {NONE} -- Internal

	items: SPECIAL [detachable separate G]

	busy_items: SPECIAL [BOOLEAN]

--	available_items: SPECIAL [INTEGER]

--	last_available_index: INTEGER

	queue: ARRAYED_LIST [separate H]

feature {CONCURRENT_POOL_ITEM} -- Change

	release_item (a_item: like new_separate_item)
			-- Unregister `a_item' from Current pool.
		require
			count > 0
		local
			i,n,pos: INTEGER
			lst: like items
		do
				-- release handler for reuse
			from
				lst := items
				i := 0
				n := lst.count - 1
			until
				i > n or lst [i] = a_item
			loop
				i := i + 1
			end
			if i <= n then
				pos := i
				busy_items [pos] := False
				count := count - 1
--reuse				items [pos] := Void
				debug ("pool")
					print ("Released pool item #" + i.out + " (free:"+ (capacity - count).out +"))%N")
				end
			else
				check known_item: False end
			end
		end

feature -- Change

	set_count (n: INTEGER)
		local
			g: detachable separate G
			i: like new_separate_item
		do
			capacity := n
			items.fill_with (g, 0, n - 1)
			busy_items.fill_with (False, 0, n - 1)
			across
				1 |..| n as ic
			loop
				i := new_separate_item
				items[ic.item - 1] := i
				register_item (i)
				busy_items[ic.item - 1] := True
			end
		end

feature {NONE} -- Implementation

	new_separate_item: separate G
		deferred
		end

	register_item (a_item: like new_separate_item)
		do
			a_item.set_pool (Current)
			a_item.pool_execute
		end

note
	copyright: "2011-2013, Javier Velilla, Jocelyn Fiat and others"
	license: "Eiffel Forum License v2 (see http://www.eiffel.com/licensing/forum.txt)"
end
