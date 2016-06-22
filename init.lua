-- List all of the texts stored in books/ here:
local files = {
	'princess_of_mars.txt',
}

gutenburg = {}
gutenburg.path = minetest.get_modpath(minetest.get_current_modname())
local lpp = 18 -- Lines per book's page

local function get_book_data(file)
	local f = gutenburg.book_files[file]
	if not f then
		return
	end

	local book = {}
	local text = f:read('*a')
	f:seek('set')
	text = text:gsub('\r', '')

	for tit in text:gmatch('Title: ([^\n]+)') do
		book.title = tit
	end

	for aut in text:gmatch('Author: ([^\n]+)') do
		book.author = aut
	end

	local page_max = 0
	for str in (text .. "\n"):gmatch("([^\n]*)[\n]") do
		page_max = page_max + 1
	end
	book.page_max = math.ceil(page_max / lpp)

	return book, text
end

local function book_on_use(itemstack, user)
	local player_name = user:get_player_name()
	local data = minetest.deserialize(itemstack:get_metadata())
	local item_name = itemstack:get_name()

	local file = item_name:gsub('gutenburg:book_', '')..'.txt'
	local book, text = get_book_data(file)
	if not book then
		return
	end

	local formspec = ""
	local lines, string = {}, ""

	for str in (text .. "\n"):gmatch("([^\n]*)[\n]") do
		lines[#lines+1] = str
	end

	local page = 1
	if data and data.page then
		page = data.page

		for i = ((lpp * page) - lpp) + 1, lpp * page do
			if not lines[i] then break end
			string = string .. lines[i] .. "\n"
		end
	end

	formspec = "size[9,8]" .. default.gui_bg ..
	default.gui_bg_img ..
	"label[0.5,0.5;by " .. book.author .. "]" ..
	"tablecolumns[color;text]" ..
	"tableoptions[background=#00000000;highlight=#00000000;border=false]" ..
	"table[0.4,0;7,0.5;title;#FFFF00," .. minetest.formspec_escape(book.title) .. "]" ..
	"textarea[0.5,1.5;8.5,7;;" ..
	minetest.formspec_escape(string ~= "" and string or text) .. ";]" ..
	"button[2.4,7.6;0.8,0.8;book_prev;<]" ..
	"label[3.2,7.7;Page " .. page .. " of " .. book.page_max .. "]" ..
	"button[4.9,7.6;0.8,0.8;book_next;>]"

	minetest.show_formspec(player_name, "gutenburg:book_gutenburg", formspec)
end

minetest.register_on_player_receive_fields(function(player, formname, fields)
	if formname ~= "gutenburg:book_gutenburg" then return end
	local stack = player:get_wielded_item()

	if fields.book_next or fields.book_prev then
		local book
		local data = minetest.deserialize(stack:get_metadata())
		if not data or not data.page then
			local item_name = stack:get_name()
			local file = item_name:gsub('gutenburg:book_', '')..'.txt'
			book = get_book_data(file)
			if not book then
				return
			end

			data = {}
			data.page = 1
			data.page_max = book.page_max
		end

		if fields.book_next then
			data.page = data.page + 1
			if data.page > data.page_max then
				data.page = 1
			end
		else
			data.page = data.page - 1
			if data.page == 0 then
				data.page = data.page_max
			end
		end

		local data_str = minetest.serialize(data)
		stack:set_metadata(data_str)
		book_on_use(stack, player)
	end

	player:set_wielded_item(stack)
end)

gutenburg.book_files = {}
local titles = {}
for _, file in pairs(files) do
	local f = io.open(gutenburg.path..'/books/'..file, 'r')
	if f then
		gutenburg.book_files[file] = f

		local book = get_book_data(file)
		local lower = 'gutenburg:book_'..file:gsub('%.txt', '')
		titles[#titles+1] = lower

		minetest.register_craftitem(lower, {
			description = book.title..' by '..book.author,
			inventory_image = "default_book_written.png",
			groups = {book = 1, not_in_creative_inventory = 1},
			stack_max = 1,
			on_use = book_on_use,
		})
	end
end

minetest.register_craftitem('gutenburg:book_gutenburg', {
	description = 'A Project Gutenburg book',
	inventory_image = "default_book_written.png",
	groups = {book = 1, not_in_creative_inventory = 1},
	stack_max = 1,
})

minetest.register_craft({
	output = 'gutenburg:book_gutenburg',
	recipe = {
		{'default:paper', '', ''},
		{'', 'default:paper', ''},
		{'', '', 'default:paper'},
	}
})

minetest.register_on_craft(function(itemstack, player, old_craft_grid, craft_inv)
	if #titles < 1 or itemstack:get_name() ~= "gutenburg:book_gutenburg" then
		return
	end

	itemstack:replace(titles[math.random(#titles)])
end)
