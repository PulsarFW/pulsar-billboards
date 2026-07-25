-- Nothing in this file actually touches a fetched component (the old RetrieveComponents list
-- below was 25 names, none referenced anywhere in this resource) — StartUp() only reads
-- _billboardConfig (this resource's own shared config) and GlobalState, so it doesn't need to
-- wait on plsr at all. CreateThread alone gives the same "run exactly once at resource start"
-- guarantee the old Core:Shared:Ready+RequestDependencies dance was providing.
CreateThread(function()
	StartUp()
end)

local started = false
local _billboardDUIs = {}

function StartUp()
	if started then
		return
	end

	started = true

	for k, v in pairs(_billboardConfig) do
		v.url = GlobalState[string.format("Billboards:%s", k)]
	end
end

AddEventHandler("Characters:Client:Spawn", function()
	CreateThread(function()
		Wait(5000)

		while plsr.State.flags.loggedIn do
			for k, v in pairs(_billboardConfig) do
				local dist = #(GetEntityCoords(PlayerPedId()) - v.coords)
				if dist <= v.range then
					if not _billboardDUIs[k] and v.url then
						local createdDui = CreateBillboardDUI(v.url, v.width, v.height)
						AddReplaceTexture(
							v.originalDictionary,
							v.originalTexture,
							createdDui.dictionary,
							createdDui.texture
						)

						_billboardDUIs[k] = createdDui
					end
				elseif _billboardDUIs[k] then
					ReleaseBillboardDUI(_billboardDUIs[k].id)
					RemoveReplaceTexture(v.originalDictionary, v.originalTexture)
					_billboardDUIs[k] = nil
				end
			end
			Wait(1500)
		end
	end)
end)

RegisterNetEvent("Characters:Client:Logout")
AddEventHandler("Characters:Client:Logout", function()
	for k, v in pairs(_billboardConfig) do
		if _billboardDUIs[k] then
			ReleaseBillboardDUI(_billboardDUIs[k].id)
			RemoveReplaceTexture(v.originalDictionary, v.originalTexture)
			_billboardDUIs[k] = nil
		end
	end
end)

RegisterNetEvent("Billboards:Client:UpdateBoardURL", function(id, url)
	if not _billboardConfig[id] then
		return
	end

	if _billboardDUIs[id] then
		if url then
			UpdateBillboardDUI(_billboardDUIs[id].id, url)
			AddReplaceTexture(
				_billboardConfig[id].originalDictionary,
				_billboardConfig[id].originalTexture,
				_billboardDUIs[id].dictionary,
				_billboardDUIs[id].texture
			)
		else
			ReleaseBillboardDUI(_billboardDUIs[id].id)
			RemoveReplaceTexture(_billboardConfig[id].originalDictionary, _billboardConfig[id].originalTexture)
			_billboardDUIs[id] = nil
		end
	end

	_billboardConfig[id].url = url
end)
