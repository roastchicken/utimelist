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
    xgui.timesbysessiontime = {}
    xgui.timesbylastvisit = {}
    xgui.timesbytotaltime = {}
  end
  
  function times.getSortTable( sortType )
    -- Retrieve the sorted table of times. If type hasn't been sorted, then sort and cache.
    if sortType == 1 then
      -- Times by Name
      if next( xgui.timesbyname ) == nil then
        for k, v in pairs( sql.Query( "SELECT steamid, lastname FROM utimelist_steamids;" ) ) do
          table.insert( xgui.timesbyname, { v.steamid, v.lastname and string.upper( v.lastname ) or nil } )
        end
        table.sort( xgui.timesbyname, function( a, b ) return (a[2] or "\255" .. a[1]) < (b[2] or "\255" .. b[1]) end )
      end
      return xgui.timesbyname

    elseif sortType == 2 then
      -- Times by SteamID
      if next( xgui.timesbyid ) == nil then
        for k, v in pairs( ULib.bans ) do
          table.insert( xgui.timesbyid, { k } )
        end
        table.sort( xgui.timesbyid, function( a, b ) return a[1] < b[1] end )
      end
      return xgui.timesbyid

    elseif sortType == 3 then
      -- Times by Session Time
      if next( xgui.timesbysessiontime ) == nil then
        for k, v in pairs( ULib.bans ) do
          table.insert( xgui.timesbysessiontime, { k, v.admin or "" } )
        end
        table.sort( xgui.timesbysessiontime, function( a, b ) return a[2] < b[2] end )
      end
      return xgui.timesbysessiontime

    elseif sortType == 4 then
      -- Times by Last Visit
      if next( xgui.timesbylastvisit ) == nil then
        for k, v in pairs( ULib.bans ) do
          table.insert( xgui.timesbylastvisit, { k, v.reason or "" } )
        end
        table.sort( xgui.timesbylastvisit, function( a, b ) return a[2] < b[2] end )
      end
      return xgui.timesbylastvisit

    else
      if next( xgui.timesbytotaltime ) == nil then
        for k, v in pairs( ULib.bans ) do
          table.insert( xgui.timesbytotaltime, { k, v.time or 0 } )
        end
        table.sort( xgui.timesbytotaltime, function( a, b ) return tonumber( a[2] ) > tonumber( b[2] ) end )
      end
      return xgui.timesbytotaltime
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

      -- Handle string filter
      if not ( filterString and
        not ( steamID and string.find( string.lower( steamID ), filterString ) or
        bandata.name and string.find( string.lower( bandata.name ), filterString ) )) then

        --We found a valid one! .. Now for the pagination.
        if #bansToSend < 17 and currentEntry >= firstEntry then
          table.insert( bansToSend, bandata )
          bansToSend[#bansToSend].steamID = steamID
          if noFilter and #bansToSend >= 17 then break end  -- If there is a filter, then don't stop the loop so we can get a "result" count.
        end
        currentEntry = currentEntry + 1
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