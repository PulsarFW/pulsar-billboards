CreateThread(function()
	FetchBillboardsData()

	plsr.Chat:RegisterAdminCommand("setbillboard", function(source, args, rawCommand)
		local billboardId, billboardUrl = args[1], args[2]

		if #billboardUrl <= 10 then
			billboardUrl = false
		end

		plsr.Billboards:Set(billboardId, billboardUrl)
	end, {
		help = "Set a Billboard URL",
		params = {
			{
				name = "ID",
				help = "Billboard ID",
			},
			{
				name = "URL",
				help = "Billboard URL",
			},
		},
	}, 2)

	plsr.Callbacks:RegisterServerCallback("Billboards:UpdateURL", function(source, data, cb)
		local billboardData = _billboardConfig[data?.id]
		if billboardData and billboardData.job and plsr.State:Player(source).onDuty == billboardData.job then
			local billboardUrl = data.link
			if #billboardUrl <= 5 then
				billboardUrl = false
			end

			if not billboardUrl or plsr.Regex:Test(_billboardRegex, billboardUrl, "gim") then
				cb(plsr.Billboards:Set(data.id, billboardUrl))
			else
				cb(false, true)
			end
		else
			cb(false)
		end
	end)
end)

_BILLBOARDS = {
    Set = function(self, id, url)
        if id and _billboardConfig[id] then
            local updated = SetBillboardURL(id, url)
            if updated then
                GlobalState[string.format("Billboards:%s", id)] = url

                TriggerClientEvent('Billboards:Client:UpdateBoardURL', -1, id, url)

                return true
            end
        end
        return false
    end,
    Get = function(self, id)
        return GlobalState[string.format("Billboards:%s", id)]
    end,
    GetCategory = function(self, cat)
        local cIds = {}

        for k,v in pairs(_billboardConfig) do
            if v.category == cat then
                table.insert(cIds, k)
            end
        end

        return cIds
    end,
}

AddEventHandler("Proxy:Shared:RegisterReady", function(component)
    exports["pulsar_core"]:RegisterComponent("Billboards", _BILLBOARDS)
end)

local _billboardsTableReady = false
local function ensureBillboardsTable(callback)
    if _billboardsTableReady then
        if callback then
            callback()
        end
        return
    end
    plsr.Database:Query(
        "CREATE TABLE IF NOT EXISTS `billboards` (`id` BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY, `billboard_id` VARCHAR(191) NOT NULL, `billboard_url` TEXT, UNIQUE INDEX `idx_billboard_id` (`billboard_id`))",
        nil,
        function()
            _billboardsTableReady = true
            if callback then
                callback()
            end
        end
    )
end

local started = false
function FetchBillboardsData()
    if started then return; end

    started = true

    local fetchedBillboards = {}
    local billboardIds = {}

    ensureBillboardsTable(function()
        plsr.Database:Query("SELECT `billboard_id`, `billboard_url` FROM `billboards`", nil, function(success, results)
            if success and #results > 0 then
                for k, v in ipairs(results) do
                    if v.billboard_id and v.billboard_url then
                        fetchedBillboards[v.billboard_id] = v.billboard_url
                    end
                end
            end

            for k,v in pairs(_billboardConfig) do
                GlobalState[string.format("Billboards:%s", k)] = fetchedBillboards[k]

                table.insert(billboardIds, k)
            end
        end)
    end)
end

function SetBillboardURL(billboardId, url)
    local p = promise.new()

    ensureBillboardsTable(function()
        plsr.Database:Update(
            "INSERT INTO `billboards` (`billboard_id`, `billboard_url`) VALUES (?, ?) ON DUPLICATE KEY UPDATE `billboard_url` = VALUES(`billboard_url`)",
            { billboardId, url },
            function(success)
                p:resolve(success)
            end
        )
    end)

    local res = Citizen.Await(p)
    return res
end
