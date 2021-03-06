if not SERVER then return end

if not sql.TableExists( "utimelist_steamids" ) then
	sql.Query( "CREATE TABLE IF NOT EXISTS utimelist_steamids ( steamid64 INTEGER NOT NULL PRIMARY KEY, uniqueid INTEGER NOT NULL, lastname TEXT NOT NULL );" )
	sql.Query( "CREATE INDEX IDX_UTIMELIST_UNIQUEID ON utimelist_steamids ( uniqueid DESC );" )
end

function onNameChange( ply, oldNick, newNick )
  sql.Query( "UPDATE utimelist_steamids SET lastname = " .. sql.SQLStr( newNick ) .. " WHERE steamid64 = " .. ply:SteamID64() .. ";" )
end

function onJoin( ply )
  local sid64 = ply:SteamID64()
  local nick = ply:Nick()
  
  local row = sql.QueryRow( "SELECT lastname FROM utimelist_steamids WHERE steamid64 = " .. sid64 .. ";" )
  
  if row and nick ~= row.lastname then
    onNameChange( ply, row.lastname, nick )
  elseif not row then
    sql.Query( "INSERT into utimelist_steamids ( steamid64, uniqueid, lastname ) VALUES ( " .. sid64 .. ", " .. ply:UniqueID() .. ", " .. sql.SQLStr( nick ) .. " );" )
  end
end

hook.Add( "PlayerInitialSpawn", "UTimeList_PlayerInitialSpawn", onJoin )
hook.Add( "ULibPlayerNameChanged", "UTimeList_ULibPlayerNameChanged", onNameChange )