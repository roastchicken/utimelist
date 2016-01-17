--UTime List module for ULX GUI -- by roastchicken
--Based off of Bans module by Stickly Man!

xgui.prepareDataType( "bans" )

local xtimes = xlib.makepanel{ parent=xgui.null }

xtimes.timelist = xlib.makelistview{ x=5, y=30, w=572, h=310, multiselect=false, parent=xtimes }
	xtimes.timelist:AddColumn( "Name/SteamID" )
	xtimes.timelist:AddColumn( "Total Time" )
	xtimes.timelist:AddColumn( "Session Time" )
	xtimes.timelist:AddColumn( "Last Visit" )
xtimes.timelist.DoDoubleClick = function( self, LineID, line )
	xtimes.ShowBanDetailsWindow( xgui.data.bans.cache[LineID] )
end
xtimes.timelist.OnRowRightClick = function( self, LineID, line )
	local menu = DermaMenu()
	menu:AddOption( "Details...", function() xtimes.ShowBanDetailsWindow( xgui.data.bans.cache[LineID] ) end )
	menu:Open()
end
-- Change the column sorting method to hook into our own custom sort stuff.
xtimes.timelist.SortByColumn = function( self, ColumnID, Desc )
	local index =	ColumnID == 1 and 2 or	-- Sort by Name
					ColumnID == 2 and 1 or	-- Sort by Admin
					ColumnID == 3 and 4 or	-- Sort by Unban Date
					ColumnID == 4 and 5 or	-- Sort by Reason
									  1		-- Otherwise sort by Date
	xtimes.sortbox:ChooseOptionID( index )
end

local searchFilter = ""
xtimes.searchbox = xlib.maketextbox{ x=5, y=6, w=175, text="Search...", selectall=true, parent=xtimes }
local txtCol = xtimes.searchbox:GetTextColor()
xtimes.searchbox:SetTextColor( Color( txtCol.r, txtCol.g, txtCol.b, 196 ) ) -- Set initial color
xtimes.searchbox.OnChange = function( pnl )
	if pnl:GetText() == "" then
		pnl:SetText( "Search..." )
		pnl:SelectAll()
		pnl:SetTextColor( Color( txtCol.r, txtCol.g, txtCol.b, 196 ) )
	else
		pnl:SetTextColor( Color( txtCol.r, txtCol.g, txtCol.b, 255 ) )
	end
end
xtimes.searchbox.OnLoseFocus = function( pnl )
	if pnl:GetText() == "Search..." then
		searchFilter = ""
	else
		searchFilter = pnl:GetText()
	end
	xtimes.setPage( 1 )
	xtimes.retrieveBans()
	hook.Call( "OnTextEntryLoseFocus", nil, pnl )
end

local sortMode = 0
local sortAsc = false
xtimes.sortbox = xlib.makecombobox{ x=185, y=6, w=150, text="Sort: Total Time (Desc.)", choices={ "Total Time", "Name", "Steam ID", "Session Time", "Last Visit" }, parent=xtimes }
function xtimes.sortbox:OnSelect( i, v )
	if i-1 == sortMode then
		sortAsc = not sortAsc
	else
		sortMode = i-1
		sortAsc = false
	end
	self:SetValue( "Sort: " .. v .. (sortAsc and " (Asc.)" or " (Desc.)") )
	xtimes.setPage( 1 )
	xtimes.retrieveBans()
end

xtimes.infoLabel = xlib.makelabel{ x=204, y=344, label="Right-click on a ban for more options", parent=xtimes }


xtimes.resultCount = xlib.makelabel{ y=344, parent=xtimes }
function xtimes.setResultCount( count )
	local pnl = xtimes.resultCount
	pnl:SetText( count .. " results" )
	pnl:SizeToContents()

	local width = pnl:GetWide()
	local x, y = pnl:GetPos()
	pnl:SetPos( 475 - width, y )
	
	local ix, iy = xtimes.infoLabel:GetPos()
	xtimes.infoLabel:SetPos( ( 130 - width ) / 2 + 175, y )
end

local numPages = 1
local pageNumber = 1
xtimes.pgleft = xlib.makebutton{ x=480, y=340, w=20, icon="icon16/arrow_left.png", centericon=true, disabled=true, parent=xtimes }
xtimes.pgleft.DoClick = function()
	xtimes.setPage( pageNumber - 1 )
	xtimes.retrieveBans()
end
xtimes.pageSelector = xlib.makecombobox{ x=500, y=340, w=57, text="1", enableinput=true, parent=xtimes }
function xtimes.pageSelector:OnSelect( index )
	xtimes.setPage( index )
	xtimes.retrieveBans()
end
function xtimes.pageSelector.TextEntry:OnEnter()
	pg = math.Clamp( tonumber( self:GetValue() ) or 1, 1, numPages )
	xtimes.setPage( pg )
	xtimes.retrieveBans()
end
xtimes.pgright = xlib.makebutton{ x=557, y=340, w=20, icon="icon16/arrow_right.png", centericon=true, disabled=true, parent=xtimes }
xtimes.pgright.DoClick = function()
	xtimes.setPage( pageNumber + 1 )
	xtimes.retrieveBans()
end

xtimes.setPage = function( newPage )
	pageNumber = newPage
	xtimes.pgleft:SetDisabled( pageNumber <= 1 )
	xtimes.pgright:SetDisabled( pageNumber >= numPages )
	xtimes.pageSelector.TextEntry:SetText( pageNumber )
end


function xtimes.RemoveBan( ID, bandata )
	local tempstr = "<Unknown>"
	if bandata then tempstr = bandata.name or "<Unknown>" end
	Derma_Query( "Are you sure you would like to unban " .. tempstr .. " - " .. ID .. "?", "XGUI WARNING", 
		"Remove",	function()
						RunConsoleCommand( "ulx", "unban", ID ) 
						xtimes.RemoveBanDetailsWindow( ID )
					end,
		"Cancel", 	function() end )
end

xtimes.openWindows = {}
function xtimes.RemoveBanDetailsWindow( ID )
	if xtimes.openWindows[ID] then
		xtimes.openWindows[ID]:Remove()
		xtimes.openWindows[ID] = nil
	end
end

function xtimes.ShowBanDetailsWindow( bandata )
	local wx, wy
	if xtimes.openWindows[bandata.steamID] then
		wx, wy = xtimes.openWindows[bandata.steamID]:GetPos()
		xtimes.openWindows[bandata.steamID]:Remove()
	end
	xtimes.openWindows[bandata.steamID] = xlib.makeframe{ label="Ban Details", x=wx, y=wy, w=285, h=295, skin=xgui.settings.skin }

	local panel = xtimes.openWindows[bandata.steamID]
	local name = xlib.makelabel{ x=50, y=30, label="Name:", parent=panel }
	xlib.makelabel{ x=90, y=30, w=190, label=( bandata.name or "<Unknown>" ), parent=panel, tooltip=bandata.name }
	xlib.makelabel{ x=36, y=50, label="SteamID:", parent=panel }
	xlib.makelabel{ x=90, y=50, label=bandata.steamID, parent=panel }
	xlib.makelabel{ x=33, y=70, label="Ban Date:", parent=panel }
	xlib.makelabel{ x=90, y=70, label=bandata.time and ( os.date( "%b %d, %Y - %I:%M:%S %p", tonumber( bandata.time ) ) ) or "<This ban has no metadata>", parent=panel }
	xlib.makelabel{ x=20, y=90, label="Unban Date:", parent=panel }
	xlib.makelabel{ x=90, y=90, label=( tonumber( bandata.unban ) == 0 and "Never" or os.date( "%b %d, %Y - %I:%M:%S %p", math.min(  tonumber( bandata.unban ), 4294967295 ) ) ), parent=panel }
	xlib.makelabel{ x=10, y=110, label="Length of Ban:", parent=panel }
	xlib.makelabel{ x=90, y=110, label=( tonumber( bandata.unban ) == 0 and "Permanent" or xgui.ConvertTime( tonumber( bandata.unban ) - bandata.time ) ), parent=panel }
	xlib.makelabel{ x=33, y=130, label="Time Left:", parent=panel }
	local timeleft = xlib.makelabel{ x=90, y=130, label=( tonumber( bandata.unban ) == 0 and "N/A" or xgui.ConvertTime( tonumber( bandata.unban ) - os.time() ) ), parent=panel }
	xlib.makelabel{ x=26, y=150, label="Banned By:", parent=panel }
	if bandata.admin then xlib.makelabel{ x=90, y=150, label=string.gsub( bandata.admin, "%(STEAM_%w:%w:%w*%)", "" ), parent=panel } end
	if bandata.admin then xlib.makelabel{ x=90, y=165, label=string.match( bandata.admin, "%(STEAM_%w:%w:%w*%)" ), parent=panel } end
	xlib.makelabel{ x=41, y=185, label="Reason:", parent=panel }
	xlib.makelabel{ x=90, y=185, w=190, label=bandata.reason, parent=panel, tooltip=bandata.reason ~= "" and bandata.reason or nil }
	xlib.makelabel{ x=13, y=205, label="Last Updated:", parent=panel }
	xlib.makelabel{ x=90, y=205, label=( ( bandata.modified_time == nil ) and "Never" or os.date( "%b %d, %Y - %I:%M:%S %p", tonumber( bandata.modified_time ) ) ), parent=panel }
	xlib.makelabel{ x=21, y=225, label="Updated by:", parent=panel }
	if bandata.modified_admin then xlib.makelabel{ x=90, y=225, label=string.gsub( bandata.modified_admin, "%(STEAM_%w:%w:%w*%)", "" ), parent=panel } end
	if bandata.modified_admin then xlib.makelabel{ x=90, y=240, label=string.match( bandata.modified_admin, "%(STEAM_%w:%w:%w*%)" ), parent=panel } end

	panel.data = bandata	-- Store data on panel for future reference.

	panel.btnClose.DoClick = function ( button )
		xtimes.RemoveBanDetailsWindow( panel.data.steamID )
	end

	if timeleft:GetValue() ~= "N/A" then
		function panel.OnTimer()
			if panel:IsVisible() then
				local bantime = tonumber( panel.data.unban ) - os.time()
				if bantime <= 0 then
					xtimes.RemoveBanDetailsWindow( panel.data.steamID )
					return
				else
					timeleft:SetText( xgui.ConvertTime( bantime ) )
				end
				timeleft:SizeToContents()
				timer.Simple( 1, panel.OnTimer )
			end
		end
		panel.OnTimer()
	end
end

function xgui.ConvertTime( seconds )
	--Convert number of seconds remaining to something more legible (Thanks JamminR!)
	local years = math.floor( seconds / 31536000 )
	seconds = seconds - ( years * 31536000 )
	local weeks = math.floor( seconds / 604800 )
	seconds = seconds - ( weeks * 604800 )
	local days = math.floor( seconds / 86400 )
	seconds = seconds - ( days * 86400 )
	local hours = math.floor( seconds/3600 )
	seconds = seconds - ( hours * 3600 )
	local minutes = math.floor( seconds/60 )
	seconds = seconds - ( minutes * 60 )
	local curtime = ""
	if years ~= 0 then curtime = curtime .. years .. " year" .. ( ( years > 1 ) and "s, " or ", " ) end
	if weeks ~= 0 then curtime = curtime .. weeks .. " week" .. ( ( weeks > 1 ) and "s, " or ", " ) end
	if days ~= 0 then curtime = curtime .. days .. " day" .. ( ( days > 1 ) and "s, " or ", " ) end
	curtime = curtime .. ( ( hours < 10 ) and "0" or "" ) .. hours .. ":"
	curtime = curtime .. ( ( minutes < 10 ) and "0" or "" ) .. minutes .. ":"
	return curtime .. ( ( seconds < 10 and "0" or "" ) .. seconds )
end

---Update stuff
function xtimes.bansRefreshed()
	xgui.data.bans.cache = {} -- Clear the bans cache

	-- Retrieve bans if XGUI is open, otherwise it will be loaded later.
	if xgui.anchor:IsVisible() then
		xtimes.retrieveBans()
	end
end
xgui.hookEvent( "bans", "process", xtimes.bansRefreshed )

function xtimes.banPageRecieved( data )
	xgui.data.bans.cache = data
	xtimes.cleartimes()
	xtimes.populateTimes()
end
xgui.hookEvent( "bans", "data", xtimes.banPageRecieved )

function xtimes.checkCache()
	if xgui.data.bans.cache and xgui.data.bans.count ~= 0 and table.Count(xgui.data.bans.cache) == 0 then
		xtimes.retrieveBans()
	end
end
xgui.hookEvent( "onOpen", nil, xtimes.checkCache )

function xtimes.cleartimes()
	xtimes.timelist:Clear()
end

function xtimes.retrieveBans()
	RunConsoleCommand( "xgui", "getbans",
		sortMode,			-- Sort Type
		searchFilter,		-- Filter String
		0,			-- Hide permabans?
		0,		-- Hide bans that don't have full ULX metadata?
		pageNumber,			-- Page number
		sortAsc and 1 or 0)	-- Ascending/Descending
end

function xtimes.populateTimes()
	local cache = xgui.data.bans.cache
	local count = cache.count or xgui.data.bans.count
	numPages = math.max( 1, math.ceil( count / 17 ) )

	xtimes.setResultCount( count )
	xtimes.pageSelector:SetDisabled( numPages == 1 )
	xtimes.pageSelector:Clear()
	for i=1, numPages do
		xtimes.pageSelector:AddChoice(i)
	end
	xtimes.setPage( math.Clamp( pageNumber, 1, numPages ) )

	cache.count = nil

	for _, baninfo in pairs( cache ) do
		xtimes.timelist:AddLine( baninfo.name or baninfo.steamID,
					( baninfo.admin ) and string.gsub( baninfo.admin, "%(STEAM_%w:%w:%w*%)", "" ) or "",
					(( tonumber( baninfo.unban ) ~= 0 ) and os.date( "%c", math.min( tonumber( baninfo.unban ), 4294967295 ) )) or "Never",
					baninfo.reason,
					baninfo.steamID,
					tonumber( baninfo.unban ) )
	end
end

function xtimes.fban( ply, cmd, args )
	xtimes.xban( ply, cmd, args, true )
end
ULib.cmds.addCommandClient( "xgui fban", xtimes.fban )

xgui.addModule( "Play Times", xtimes, "icon16/clock.png", "xgui_utimelist" )
