--sv_timelist -- by roastchicken
--Based off of sv_bans by Stickly Man!

local times = {}
function times.init()
  ULib.ucl.registerAccess( "xgui_utimelist", "superadmin", "Allows viewing of player times in XGUI.", "XGUI" )
  
  xgui.addDataType( "times", function() return { count=table.Count( ULib.bans ) } end, "xgui_managebans", 30, 30 )
  
    --Misc functions
  function times.processTimes()
    times.clearSortCache()
    xgui.sendDataTable( {}, "times" ) --Only sends the ban count, and triggers the client to clear their cache.
  end

  function times.clearSortCache()
    xgui.timesbyid = {}
    xgui.timesbyname = {}
    xgui.timesbytotaltime = {}
    xgui.timesbysessiontime = {}
    xgui.timesbylastvisit = {}
  end
  
  function times.getSortTable( sortType )
    -- Retrieve the sorted table of bans. If type hasn't been sorted, then sort and cache.
    if sortType == 1 then
      -- Bans by Name
      if next( xgui.bansbyname ) == nil then
        for k, v in pairs( ULib.bans ) do
          table.insert( xgui.bansbyname, { k, v.name and string.upper( v.name ) or nil } )
        end
        table.sort( xgui.bansbyname, function( a, b ) return (a[2] or "\255" .. a[1]) < (b[2] or "\255" .. b[1]) end )
      end
      return xgui.bansbyname

    elseif sortType == 2 then
      -- Bans by SteamID
      if next( xgui.bansbyid ) == nil then
        for k, v in pairs( ULib.bans ) do
          table.insert( xgui.bansbyid, { k } )
        end
        table.sort( xgui.bansbyid, function( a, b ) return a[1] < b[1] end )
      end
      return xgui.bansbyid

    elseif sortType == 3 then
      -- Bans by Admin
      if next( xgui.bansbyadmin ) == nil then
        for k, v in pairs( ULib.bans ) do
          table.insert( xgui.bansbyadmin, { k, v.admin or "" } )
        end
        table.sort( xgui.bansbyadmin, function( a, b ) return a[2] < b[2] end )
      end
      return xgui.bansbyadmin

    elseif sortType == 4 then
      -- Bans by Reason
      if next( xgui.bansbyreason ) == nil then
        for k, v in pairs( ULib.bans ) do
          table.insert( xgui.bansbyreason, { k, v.reason or "" } )
        end
        table.sort( xgui.bansbyreason, function( a, b ) return a[2] < b[2] end )
      end
      return xgui.bansbyreason

    elseif sortType == 5 then
      -- Bans by Unban Date
      if next( xgui.bansbyunban ) == nil then
        for k, v in pairs( ULib.bans ) do
          table.insert( xgui.bansbyunban, { k, v.unban or 0 } )
        end
        table.sort( xgui.bansbyunban, function( a, b ) return a[2] < b[2] end )
      end
      return xgui.bansbyunban

    elseif sortType == 6 then
      -- Bans by Ban Length
      if next( xgui.bansbybanlength ) == nil then
        for k, v in pairs( ULib.bans ) do
          table.insert( xgui.bansbybanlength, { k, (tonumber(v.unban) ~= 0) and (v.unban - v.time) or nil } )
        end
        table.sort( xgui.bansbybanlength, function( a, b ) return (a[2] or math.huge) < (b[2] or math.huge) end )
      end
      return xgui.bansbybanlength

    else
      if next( xgui.bansbydate ) == nil then
        for k, v in pairs( ULib.bans ) do
          table.insert( xgui.bansbydate, { k, v.time or 0 } )
        end
        table.sort( xgui.bansbydate, function( a, b ) return tonumber( a[2] ) > tonumber( b[2] ) end )
      end
      return xgui.bansbydate
    end
  end

  function times.sendTimesToUser( ply, args )
    if not ply then return end

    --local perfTimer = os.clock() --Debug

    -- Default params
    sortType = tonumber( args[1] ) or 0
    filterString = args[2] ~= "" and string.lower( args[2] ) or nil
    page = tonumber( args[3] ) or 1
    ascending = tonumber( args[4] ) == 1 or false

    -- Get cached sort table to use to reference the real data.
    sortTable = times.getSortTable( sortType )

    local bansToSend = {}

    -- Handle ascending or descending
    local startValue = ascending and #sortTable or 1
    local endValue = ascending and 1 or #sortTable
    local firstEntry = (page - 1) * 17
    local currentEntry = 0

    local noFilter = ( filterPermaBan == 0 and filterIncomplete == 0 and filterString == nil )

    for i = startValue, endValue, ascending and -1 or 1 do
      local steamID = sortTable[i][1]
      local bandata = ULib.bans[steamID]

      -- Handle filters. This is confusing, but essentially 0 means skip check, 1 means restrict if condition IS true, 2+ means restrict if condition IS NOT true. 
      if not ( filterPermaBan > 0 and ( ( tonumber( bandata.unban ) == 0 ) == ( filterPermaBan == 1 ) ) ) then
        if not ( filterIncomplete > 0 and ( ( bandata.time == nil ) == ( filterIncomplete == 1 ) ) ) then

          -- Handle string filter
          if not ( filterString and
            not ( steamID and string.find( string.lower( steamID ), filterString ) or
              bandata.name and string.find( string.lower( bandata.name ), filterString ) or
              bandata.reason and string.find( string.lower( bandata.reason ), filterString ) or
              bandata.admin and string.find( string.lower( bandata.admin ), filterString ) or
              bandata.modified_admin and string.find( string.lower( bandata.modified_admin ), filterString ) )) then

            --We found a valid one! .. Now for the pagination.
            if #bansToSend < 17 and currentEntry >= firstEntry then
              table.insert( bansToSend, bandata )
              bansToSend[#bansToSend].steamID = steamID
              if noFilter and #bansToSend >= 17 then break end  -- If there is a filter, then don't stop the loop so we can get a "result" count.
            end
            currentEntry = currentEntry + 1
          end
        end
      end
    end
    if not noFilter then bansToSend.count = currentEntry end

    --print( "XGUI: Ban request took " .. os.clock() - perfTimer ) --Debug

    -- Send bans to client via custom handling.
    xgui.sendDataEvent( ply, 7, "times", bansToSend )
  end
  xgui.addCmd( "gettimes", times.sendTimesToUser )
end

function times.postinit()
  times.processTimes()
end

xgui.addSVModule( "times", times.init, times.postinit )