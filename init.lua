
local time_speed = tonumber(minetest.settings:get"time_speed") or 72
-- At least one update each hour in minetest time
local light_update_delay = math.min(math.floor(3600.0 / time_speed), 5.0)

-- Remember the previous lighting until some time elapsed
local previous_textures
local function change_tex_tab(tab)
	previous_textures = tab
	minetest.after(light_update_delay * 0.5, function()
		previous_textures = nil
	end)
	return tab
end

local tiles_normals = {
	{x=0, y=1, z=0},
	{x=0, y=-1, z=0},
	{x=1, y=0, z=0},
	{x=-1, y=0, z=0},
	{x=0, y=0, z=1},
	{x=0, y=0, z=-1},
}
local ambient_lights = {0.4, 0.1, 0.2, 0.2, 0.3, 0.3}
local function get_textures()
	if previous_textures then
		-- get_textures may be called for lots of cuboids
		return previous_textures
	end
	-- Calculate diffuse lights
	local diffuse_lights = {}
	local sun_dir = vector.sun_dir()
	if sun_dir then
		for i = 1,#tiles_normals do
			local normal = tiles_normals[i]
			diffuse_lights[i] = math.max(vector.dot(normal, sun_dir), 0.0)
		end
	else
		-- It is night now, moonlight is not (yet) supported
		-- Set the final light to ambient light scaled to [0, 1]
		local ambient_light_max = ambient_lights[1]
		local f = 1.0 / ambient_light_max - 1.0
		for i = 1,#ambient_lights do
			diffuse_lights[i] = ambient_lights[i] * f
		end
	end
	-- Create texture strings
	local textures = {}
	for i = 1,#ambient_lights do
		local light_strength = ambient_lights[i] + diffuse_lights[i]
		local srgb_gray = math.floor(light_strength ^ (1.0 / 2.2) * 255.0 + 0.5)
		srgb_gray = math.min(srgb_gray, 255)
		textures[i] = string.format(
			"nodebox_creator_ff.png^[colorize:#%02x%02x%02x",
			srgb_gray, srgb_gray, srgb_gray)
	end
	return change_tex_tab(textures)
end

minetest.register_entity("nodebox_creator:entity",{
	hp_max = 1,
	visual="cube",
	visual_size={x=1/16, y=1/16},
	collisionbox = {0,0,0,0,0,0},
	physical=false,
	textures=tex,
	timer = 0,
	timerb = light_update_delay,
	on_step = function(self, dtime)
		self.timer = self.timer+dtime
		if self.timer >= 5 then
			self.timer = 0
			local pos = vector.round(self.object:get_pos())
			pos.y = pos.y-1
			if minetest.get_node(pos).name ~= "nodebox_creator:block" then
				self.object:remove()
				return
			end
		end
		self.timerb = self.timerb+dtime
		if self.timerb >= light_update_delay then
			self.timerb = 0
			self.object:set_properties{textures = get_textures()}
		end
	end
})

-- should remove old entities
local function remove_boxes(pos)
	for _,obj in pairs(minetest.get_objects_inside_radius(pos, 1)) do
		if not obj:is_player() then
			obj:remove()
		end
	end
end

-- This helper function is to index a 3D cartesian grid
local function hash_position(x, y, z)
	return minetest.hash_node_position{x=x, y=y, z=z}
end

-- removes a box from tab
local function take_box(grid, box)
	local z1, y1, x1, z2, y2, x2 = unpack(box)
	z1 = math.ceil(z1)
	y1 = math.ceil(y1)
	x1 = math.ceil(x1)
	for z = z1, z2-1 do
		for y = y1, y2-1 do
			local vi = hash_position(x1, y, z)
			for x = x1, x2-1 do
				grid[vi] = false
				vi = vi+1
			end
		end
	end
end

-- checks if a box is needed to be added
local function box_visible(grid, x1, y1, z1, x2, y2, z2)
	-- Coarse test first
	if grid[hash_position(x1, y1, z1)]
	or grid[hash_position(x2, y2, z2)] then
		return true
	end
	-- Test every grid position
	for i = z1, z2-1 do
		for j = y1, y2-1 do
			local vi = hash_position(x1, j, i)
			for k = x1, x2-1 do
				if grid[vi] then
					return true
				end
				vi = vi+1
			end
		end
	end
	return false
end

-- returns the tables needed for showing nodeboxes with entities
local function get_fine_boxes(boxes)
	local grid = {}	-- fills a table of coordinates
	for _,i in pairs(boxes) do
		for z = i[3], i[6]-1 do
			for y = i[2], i[5]-1 do
				local vi = hash_position(i[1], y, z)
				for x = i[1], i[4]-1 do
					grid[vi] = true
					vi = vi+1
				end
			end
		end
	end
	local old_grid = {}	-- copy this table of coordinates
	for i in pairs(grid) do
		old_grid[i] = true
	end
	local big_entities,n = {},1
	for _,box in pairs(boxes) do	-- checks if single big entities can be used
		local y1, y2 = box[2], box[5]
		local yscale = y2-y1
		local py = y1+yscale/2
		local z1, z2, x1, x2 = box[3], box[6], box[1], box[4]
		local xscale = x2-x1
		local zscale = z2-z1
		if xscale == zscale then
			take_box(grid, box)
			local px = x1+xscale/2
			local pz = z1+xscale/2
			big_entities[n] = {x=px, y=py, z=pz, a=xscale, b=yscale}
			n = n+1
		end
	end
	for _,box in pairs(boxes) do	-- checks if a row big entities can be used
		local y1, y2 = box[2], box[5]
		local yscale = y2-y1
		local py = y1+yscale/2
		local z1, z2, x1, x2 = box[3], box[6], box[1], box[4]
		local xscale = x2-x1
		local zscale = z2-z1
		local minscale = math.min(xscale, zscale)
		if xscale ~= zscale
		and minscale > 1 then
			if minscale == zscale then
				local pz = z1+minscale/2
				for x = x1, x2-minscale, minscale do
					if box_visible(grid, x, y1, z1, x+minscale, y2, z2) then
						local cbox = {z1, y1, x, z2, y2, x+minscale}
						take_box(grid, cbox)
						local px = x+minscale/2
						big_entities[n] = {x=px, y=py, z=pz, a=minscale, b=yscale}
						n = n+1
					end
				end
			else
				local px = x1+minscale/2
				for z = z1, z2-minscale, minscale do
					if box_visible(grid, x1, y1, z, x2, y2, z+minscale) then
						local cbox = {z, y1, x1, z+minscale, y2, x2}
						take_box(grid, cbox)
						local pz = z+minscale/2
						big_entities[n] = {x=px, y=py, z=pz, a=minscale, b=yscale}
						n = n+1
					end
				end
			end
		end
	end
	for z = -8,8 do	-- checks if small entities can be higher to fill more space
		for x = -8,8 do
			local p1, lastp
			for y = -8,9 do
				if grid[hash_position(x, y, z)] then
					if not p1 then
						p1 = y
						lastp = y
					elseif y == lastp+1
					and y ~= 8 then
						lastp = y
					end
				else
					if p1
					and lastp ~= p1 then
						take_box(grid, {z, p1, x, z+1, y, x+1})
						local dist = y-p1
						big_entities[n] = {x=x+0.5, y=p1+dist/2, z=z+0.5, a=1, b=dist}
						n = n+1
						p1 = nil
					end
				end
			end
		end
	end
	return grid, big_entities, old_grid
end

-- changes nodebox creator text to nodebox tables
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

-- removes coordinates from tab which aren't needed
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

-- removes the old enitities and adds new ones at pos
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
		obj:set_properties{visual_size={x=xscale/16, y=yscale/16}}
	end
end

-- returns nodebox boxes from the nodebox_creator box string
local size_tab = {[0]=0, "1/16", "1/8", "3/16", "1/4", "5/16", "3/8", "7/16", "0.5"}
local function get_nodebox_string(boxes)
	local count = #boxes
	local st = ""
	for m,box in pairs(boxes) do
		st = st.."{"
		for n,i in pairs(box) do
			i = tonumber(i)
			if i < 0 then
				i = "-"..size_tab[-i]
			else
				i = size_tab[i]
			end
			st = st..i
			if n ~= 6 then
				st = st..", "
			end
		end
		st = st.."}"
		if m ~= count then
			st = st..",\n"
		end
	end
	return st
end

-- returns a string for the nodebox_creator from nodebox boxes
local function get_box_string(ps, pname)
	ps = string.trim(ps)
	local st = ""
	for _,box in ipairs(string.split(ps, "{")) do
		local coords = string.split(box, ",")
		for n = 1,6 do
			local coord = string.trim(coords[n])
			if not coord then
				minetest.chat_send_player(pname, "problem at coordinate "..n)
				return
			end
			local ad
			if n == 6 then
				coord = string.split(coord, "}")[1]
				ad = "\n"
			else
				ad = " "
			end
			if not coord
			or coord == "" then
				minetest.chat_send_player(pname, "6 coordinates required, problem at "..n)
				return
			end
			local nums = string.split(coord, "/")
			if nums[2] then
				local a = tonumber(nums[1])
				local b = tonumber(nums[2])
				if not a
				or not b then
					minetest.chat_send_player(pname, "coordinate "..n.." can't be used")
					return
				end
				coord = a/b
			else
				coord = tonumber(coord)
				if not coord then
					minetest.chat_send_player(pname, "coordinate "..n.." needs to be a number")
					return
				end
			end
			coord = tonumber(coord)*16
			st = st..coord..ad
		end
	end
	return st
end

-- unnecessary extra
local function play_sounds(boxes, pos)
	local timer = 0
	for _,i in pairs(boxes) do
		for _,j in ipairs(i) do
			minetest.after(timer, function(j, pos)
				minetest.sound_play(math.abs(j), {pos=pos, gain=math.random()})
			end, j, pos)
			timer = timer+0.1
		end
	end
end

local last_punch = tonumber(os.clock())
minetest.register_node("nodebox_creator:block", {
	description = "Nodebox Creator",
	tiles = {"nodebox_creator_node_top.png", "nodebox_creator_node_bottom.png", "nodebox_creator_node_side.png"},
	groups = {cracky=3},
	use_texture_alpha = true,
	paramtype = "light",
	drawtype = "nodebox",
	node_box = {	-- nodebox created with nodebox_creator
		type = "fixed",
		fixed = {
			{-7/16, -0.5, -0.5, 7/16, -7/16, 0.5},
			{-0.5, -0.5, -7/16, 0.5, -7/16, 7/16},
			{-7/16, -7/16, -7/16, 7/16, -5/16, 7/16},
			{-3/8, -5/16, -3/8, 3/8, -1/4, 3/8},
			{-5/16, -1/4, -5/16, 5/16, 1/4, 5/16},
			{-3/8, 1/4, -3/8, 3/8, 5/16, 3/8},
			{-7/16, 5/16, -3/8, 7/16, 7/16, 3/8},
			{-3/8, 5/16, -7/16, 3/8, 7/16, 7/16},
			{-0.5, 7/16, -0.5, 0.5, 0.5, 0.5},
			{-0.5, 0, -0.5, -7/16, 7/16, -7/16},
			{-0.5, -1/8, 7/16, -7/16, 7/16, 0.5},
			{7/16, -3/16, -0.5, 0.5, 7/16, -7/16},
			{7/16, 1/16, 7/16, 0.5, 7/16, 0.5}
		},
	},
	on_construct = function(pos)
		local meta = minetest.get_meta(pos)
		meta:set_string("formspec", "size[5,8]"..
			"textarea[0.3,0;5,9;ps;;${ps}]"..
			"button[0.3,7.1;2,2;s;save]"..
			"button[2.6,7.1;2,2;show;save and show box]"
		)
		meta:set_string("infotext", "Nodebox Creator")
		meta:set_string("ps", "")
	end,
	after_destruct = function(pos)
		pos.y = pos.y+1
		remove_boxes(pos)
	end,
	on_punch = function(pos)	-- removes entities if the node is punched (useful against lag problems)
		local time = tonumber(os.clock())
		if time-last_punch > 3 then
			last_punch = time
			pos.y = pos.y+1
			remove_boxes(pos)
		end
	end,
	on_receive_fields = function(pos, formname, fields, sender)
		local ps = fields.ps
		if not ps
		or ps == "" then
			return
		end
		local pname = sender:get_player_name()

		-- converts usual nodeboxes to simple nodebox strings
		if string.find(ps, "{") then
			ps = get_box_string(ps, pname)
			if not ps then
				return
			end
		end

		local boxess = string.split(ps, "\n")
		local boxes = {}
		for _,i in pairs(boxess) do
			local tab = {}
			for n,j in pairs(string.split(i, " ")) do
				local coord = tonumber(j)
				if not coord then
					minetest.chat_send_player(pname,
						"Could not convert \"" .. n .. "\" to a number.")
					return
				end
				if math.abs(coord) > 8 then
					minetest.chat_send_player(pname,
						"Each coordinate has to be within [-8, 8].")
					return
				end
				tab[n] = j
			end
			if #tab ~= 6 then
				minetest.chat_send_player(pname,
					#tab .. " coordinates were passed, but 6 are needed.")
				return
			end
			table.insert(boxes, tab)
		end
		local meta = minetest.get_meta(pos)
		meta:set_string("ps", ps)

		local nodebox_string = get_nodebox_string(boxes)
		local f = io.open(minetest.get_worldpath()..'/tmp.txt', "w")
		f:write(nodebox_string)
		io.close(f)
		if fields.show then
			minetest.show_formspec(pname, "nodebox", "size[5,6]"..
				"label[1,0;ctrl a\nctrl c]"..
				"label[2.5,0.1;<worldpath>/tmp.txt]"..
				"textarea[0.3,1;5,6;ps;;"..nodebox_string.."]")
		end

		pos.y = pos.y+1
		update_boxes(pos, boxes)
		play_sounds(boxes, pos)
	end,
})

