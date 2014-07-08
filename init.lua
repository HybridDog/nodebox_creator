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

local function take_box(tab, box)
	local z1, y1, x1, z2, y2, x2 = unpack(box)
	z1 = math.ceil(z1)
	y1 = math.ceil(y1)
	x1 = math.ceil(x1)
	for z = z1, z2-1 do
		for y = y1, y2-1 do
			for x = x1, x2-1 do
				tab[z.." "..y.." "..x] = false
			end
		end
	end
	return tab
end

local function get_fine_boxes(boxes)
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
	local old_tab = {}
	for i,_ in pairs(tab) do
		old_tab[i] = true
	end
	local big_entities,n = {},1
	for _,box in pairs(boxes) do
		local y1, y2 = box[2], box[5]
		local yscale = y2-y1
		local py = y1+yscale/2
		local z1, z2, x1, x2 = box[3], box[6], box[1], box[4]
		local xscale = x2-x1
		local zscale = z2-z1
		--[[if zscale < xscale then
			local xzdif = xscale-zscale
			local xmin = x1+xzdif
			local xmax = x2-xzdif
			tab = take_box(tab, {z1, y1, xmin, z2, y2, xmax})
			local pz = z1+zscale/2
			local px = xmin+zscale/2
			big_entities[n] = {x=px, y=py, z=pz, a=xscale, b=yscale}
			n = n+1
		elseif xscale < zscale then
			local zxdif = zscale-xscale
			local zmin = z1+zxdif
			local zmax = z2-zxdif
			tab = take_box(tab, {zmin, y1, x1, zmax, y2, x2})
			local pz = zmin+xscale/2
			local px = x1+xscale/2
			big_entities[n] = {x=px, y=py, z=pz, a=xscale, b=yscale}
			n = n+1]]
		local minscale = math.min(xscale, zscale)
		if xscale == zscale then
			tab = take_box(tab, box)
			local px = x1+xscale/2
			local pz = z1+xscale/2
			big_entities[n] = {x=px, y=py, z=pz, a=xscale, b=yscale}
			n = n+1
		elseif minscale > 1 then
			if minscale == zscale then
				local pz = z1+minscale/2
				for x = x1, x2-minscale, minscale do
					local cbox = {z1, y1, x, z2, y2, x+minscale}
					tab = take_box(tab, cbox)
					local px = x+minscale/2
					big_entities[n] = {x=px, y=py, z=pz, a=minscale, b=minscale}
					n = n+1
				end
			else
				local px = x1+minscale/2
				for z = z1, z2-minscale, minscale do
					local cbox = {z, y1, x1, z+minscale, y2, x2}
					tab = take_box(tab, cbox)
					local pz = z+minscale/2
					big_entities[n] = {x=px, y=py, z=pz, a=minscale, b=minscale}
					n = n+1
				end
			end
		end
	end
	return tab, big_entities, old_tab
end

local function get_positions(tab)
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

local function clean_tab(tab, old_tab)
	for z = -7,7 do
		for y = -7,7 do
			for x = -7,7 do
				local p = z.." "..y.." "..x
				if tab[p] then
					local visible
					for i = -1,1,2 do
						for _,p in pairs({
							{z+i, y, x},
							{z, y+i, x},
							{z, y, x+i},
						}) do
							if not old_tab[p[1].." "..p[2].." "..p[3]] then
								visible = true
								break
							end
						end
						if visible then
							break
						end
					end
					if not visible then
						tab[p] = nil
					end
				end
			end
		end
	end
	return tab
end

local function update_boxes(pos, boxes)
	remove_boxes(pos)
	local tab, big_boxes, old_tab = get_fine_boxes(boxes)
	tab = clean_tab(tab, old_tab)
	local ps = get_positions(tab)
	for _,p in pairs(ps) do
		minetest.add_entity(vector.add(pos, p), "nodebox_creator:entity")
	end
	for _,box in pairs(big_boxes) do
		local xscale, yscale = box.a, box.b
		local obj = minetest.add_entity(vector.add(pos, vector.divide(box, 16)), "nodebox_creator:entity")
		obj:set_properties({visual_size={x=xscale/16, y=yscale/16}}) 
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

