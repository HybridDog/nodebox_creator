minetest.register_entity("nodebox_creator:entity",{
	hp_max = 1,
	visual="cube",
	visual_size={x=1/16, y=1/16},
	collisionbox = {0,0,0,0,0,0},
	physical=false,
	textures={"nodebox_creator_top.png", "nodebox_creator_bottom.png", "nodebox_creator_side1.png",
		"nodebox_creator_side1.png", "nodebox_creator_side2.png", "nodebox_creator_side2.png"},
	timer = 0,
	on_step = function(self, dtime)
		self.timer = self.timer+dtime
		if self.timer >= 2 then
			self.timer = 0
			local pos = vector.round(self.object:getpos())
			pos.y = pos.y-1
			if minetest.get_node(pos).name ~= "nodebox_creator:block" then
				self.object:remove()
			end
		end
	end
})

local function remove_boxes(pos)
	for _,obj in pairs(minetest.get_objects_inside_radius(pos, 1)) do
		if not obj:is_player() then
			obj:remove()
		end
	end
end

local function get_positions(boxes)
	local tab = {}
	for _,i in pairs(boxes) do
		for z = i[3], i[6]-1 do
			for y = i[2], i[5]-1 do
				for x = i[1], i[4]-1 do
					tab[z.." "..y.." "..x] = true
				end
			end
		end
	end
	local tab2,n = {},1
	for i,b in pairs(tab) do
		if b then
			local coords = string.split(i, " ")
			local p = {x=coords[3], y=coords[2], z=coords[1]}
			tab2[n] = vector.divide(vector.add(p, 0.5), 16)
			n = n+1
		end
	end
	return tab2
end

local function update_boxes(pos, boxes)
	remove_boxes(pos)
	local ps = get_positions(boxes)
	for _,p in pairs(ps) do
		minetest.add_entity(vector.add(pos, p), "nodebox_creator:entity")
	end
end

minetest.register_node("nodebox_creator:block", {
	description = "Nodebox Creator",
	tiles = {"default_mese_block.png"},
	groups = {cracky=3},
	on_construct = function(pos)
		local meta = minetest.get_meta(pos)
		meta:set_string("formspec", "size[5,8]"..
			"textarea[0.3,0;5,9;ps;;${ps}]"..
			"button[1.3,7.1;2,2;s;save]"
		)
		meta:set_string("infotext", "Nodebox Creator")
		meta:set_string("ps", "")
	end,
	on_receive_fields = function(pos, formname, fields, sender)
		local ps = fields.ps
		if not ps
		or ps == "" then
			return
		end
		local pname = sender:get_player_name()
		local boxess = string.split(ps, "\n")
		local boxes = {}
		for _,i in pairs(boxess) do
			local tab = {}
			for n,j in pairs(string.split(i, " ")) do
				local coord = tonumber(j)
				if not coord then
					minetest.chat_send_player(pname, n.." ?")
					return
				end
				if math.abs(coord) > 8 then
					minetest.chat_send_player(pname, "|coordinate| needs to be <= 8")
					return
				end
				tab[n] = j
			end
			local amount = #tab
			if amount ~= 6 then
				minetest.chat_send_player(pname, "6 coordinates, not "..amount)
				return
			end
			table.insert(boxes, tab)
		end
		local meta = minetest.get_meta(pos)
		meta:set_string("ps", ps)
		pos.y = pos.y+1
		update_boxes(pos, boxes)
		--[[if pos_from_string(fields.pos_out) then
			meta:set_string("pos_out", fields.pos_out)
		end
		local r = tonumber(fields.r)
		if type(r) == "number" then
			meta:set_string("r", math.min(r, 20))
		end
		if fields.text
		and fields.text ~= "" then
			meta:set_string("text", fields.text)
		end
		local pos_in = vector.pos_to_string(pos_from_string(meta:get_string("pos_in")))
		local pos_out = vector.pos_to_string(pos_from_string(meta:get_string("pos_out")))
		local info = meta:get_string("text")
		if info then
			if info ~= "" then
				info = " \""..info.."\""
			end
		else
			info = ""
		end
		meta:set_string("infotext", "Mport"..
			info..
			" from "..pos_in..
			" to "..pos_out
		)
		minetest.log("action", (sender:get_player_name() or "somebody").." did something to Mport at "..vector.pos_to_string(pos))]]
	end,
--[[	on_rightclick = function(pos, node, clicker, itemstack)
		meta = minetest.env:get_meta(pos)
		if meta:get_string("owner") == clicker:get_player_name() then
			-- set owner
			ufos.next_owner = meta:get_string("owner")
			-- restore the fuel inside the node
			ufos.set_fuel(ufos.ufo,meta:get_int("fuel"))
			-- add the entity
			e = minetest.env:add_entity(pos, "ufos:ufo")
			-- remove the node
			minetest.env:remove_node(pos)
			-- reset owner for next ufo
			ufos.next_owner = ""
		end
	end,]]
})

