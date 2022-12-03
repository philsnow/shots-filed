--[[
TODO:
- cmd-click menu items -> copy image contents to pasteboard instead of link
]]--

local pasteboard = require("hs.pasteboard")
local fs = require("hs.fs")
local timer = require("hs.timer")

local shots_done_path = os.getenv("HOME") .. "/.shots/done"
local max_menubar_items = 10
local menubar_max_thumbnail_dimensions = {h = 100, w = 100}
local published_url_prefix = "https://snap.philsnow.io/"

local notification_params = {
   title='shots filed',
   informativeText='Link copied to clipboard',
}
	    
function make_icon(code)
   local char = hs.styledtext.new(utf8.char(code), { font = { name = "SF Pro", size = 12 } })
   local canvas = hs.canvas.new({ x = 0, y = 0, h = 0, w = 0 })
   canvas:size(canvas:minimumTextSize(char))
   canvas[#canvas + 1] = {
      type = "text",
      text = char
   }
   local image = canvas:imageFromCanvas()
   return image
end

local icon_empty_star = make_icon(0x1002C2)
local icon_half_full_star = make_icon(0x1002C4)
local icon_full_star = make_icon(0x1002C3)

local inMenuBar = true
local menu = hs.menubar.new(inMenuBar)
menu:setIcon(icon_empty_star)

-- for changing the menubar icon so that Bartender will un-hide it temporarily
local icon_emptier = timer.delayed.new(
   5,
   function()
      menu:setIcon(icon_empty_star)
   end
)

local first_run = true
function update_menu()
   print("updating menu")
   all_files = {}
   num_files = 0
   for file in fs.dir(shots_done_path) do
      local full_path = shots_done_path .. "/" .. file
      if fs.attributes(full_path).mode == "file" then
         table.insert(all_files, file)
         num_files = num_files + 1
      end
   end
   table.sort(all_files)

   local lower
   if num_files < max_menubar_items then
      lower = 1
   else
      lower = num_files - max_menubar_items
   end
   local upper = num_files
   local menu_contents = {}
   for i=upper,lower,-1 do
      local full_file_path = shots_done_path .. "/" .. all_files[i]

      --[[ I want all images (square, tall, wide) to take up the same
	 horizontal width in the dropdown, so that all the file names
	 and images are aligned vertically (it looks like they're
	 actual columns but it's just because we've contrived the
	 thumbnails to be a certain size+shape).

	 1. load image, scale proportionally to max_dim -> thumb
	 2. make a canvas with full alpha that's max_dim.w wide and thumb.h tall
	 3. include the thumb as the only (image) element of the canvas
	 4. render a hs.image from the thumb canvas
	 5. use that uncropped_thumb as the menubar item image
      --]]
      local full_image = hs.image.imageFromPath(full_file_path)
      local thumb = full_image:copy():size(menubar_max_thumbnail_dimensions)
      local thumb_canvas = hs.canvas.new(
         {
            w = menubar_max_thumbnail_dimensions.w,
            h = thumb:size().h
         }
      )
      thumb_canvas:alpha(1.0)
      thumb_canvas[1] = {
         type = "image",
         image = thumb,
      }
      local uncropped_thumb = thumb_canvas:imageFromCanvas()

      table.insert(
         menu_contents,
         {
            title = string.gsub(all_files[i], "%..*$", ""),
            image = uncropped_thumb,
            fn = function()
               local url = published_url_prefix..all_files[i]
               pasteboard.setContents(url)
	       hs.notify.new(notification_params)
		  :contentImage(hs.image.imageFromPath(full_file_path))
		  :send()
            end,
         }
      )
   end
   menu:setMenu(menu_contents)

   if first_run then
      -- don't hijack the pasteboard when starting/restarting hammerspoon
      first_run = false
   else
      local latest_filename = all_files[num_files]
      local url = published_url_prefix..latest_filename
      pasteboard.setContents(url)
      print("sending notification...")
      hs.notify.new(notification_params)
	 :contentImage(hs.image.imageFromPath(shots_done_path .. "/" .. latest_filename))
	 :send()
      print("notification sent")

      menu:setIcon(icon_full_star)
      icon_emptier:start()
   end
end

local pw = hs.pathwatcher.new(shots_done_path, update_menu)
pw:start()

update_menu()
