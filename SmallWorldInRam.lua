-- SmallWorldInRam.lua

-- Implements the entire plugin logic





--- The configuration, contains the configured size of the loaded world
-- Has MinX, MaxX, MinZ, MaxZ members, plus enything else read from SmallWorldInRAM.conf
local gConf

--- Pull out math.floor for faster access
local floor = math.floor




--- Loads the configuration from SmallWorldInRam.conf
-- Assigns gWorldSize from the configuration
-- Creates an example config file and raises an error on problems
local function loadConfig()
	local confFn, err = loadfile("SmallWorldInRam.conf")
	if (
		not(confFn) or
		not(type(confFn) == "function")
	) then
		-- Write an example config to SmallWorldInRam.example.conf and bail out
		local f = assert(io.open("SmallWorldInRam.example.conf", "w"))
		f:write("This is an example configuration for the SmallWorldInRam plugin.\n")
		f:write("MinX = -100\n")
		f:write("MaxX = 200\n")
		f:write("MinZ = -300\n")
		f:write("MaxZ = 400\n")
		f:close()
		error("Cannot read configuration in SmallWorldInRam.conf (" .. tostring(err) .. ")\nAn example configuration file SmallWorldInRam.example.conf has been created as a sample configuration.")
	end

	local conf = {}
	setfenv(confFn, conf)
	confFn()
	if (
		not(tonumber(conf.MinX)) or
		not(tonumber(conf.MaxX)) or
		not(tonumber(conf.MinZ)) or
		not(tonumber(conf.MaxZ))
	) then
		error("Invalid configuration in SmallWorldInRam.conf")
	end

	gConf = conf
end





--- Returns true if the specified chunk coords intersect gWorldSize in at least one block column
local function shouldLoadChunk(aChunkX, aChunkZ)
	local minBlockX = aChunkX * 16
	local maxBlockX = aChunkX * 16 + 15
	local minBlockZ = aChunkZ * 16
	local maxBlockZ = aChunkZ * 16 + 15

	return (
		(maxBlockX >= gConf.MinX) and
		(minBlockX <= gConf.MaxX) and
		(maxBlockZ >= gConf.MinZ) and
		(minBlockZ <= gConf.MaxZ)
	)
end





--- Handles the HOOK_CHUNK_GENERATING hook
-- Doesn't allow worldgen in chunks outside of the world limit
local function onChunkGenerating(aWorld, aChunkX, aChunkZ, aChunkDesc)
	if (shouldLoadChunk(aChunkX, aChunkZ)) then
		return false
	end

	-- Do not generate anything in this chunk:
	aChunkDesc:SetUseDefaultBiomes(false)
	aChunkDesc:SetUseDefaultComposition(false)
	aChunkDesc:SetUseDefaultFinish(false)
	aChunkDesc:SetUseDefaultHeight(false)
	aChunkDesc:FillBlocks(E_BLOCK_AIR, 0)
	aChunkDesc:UpdateHeightmap()
	for z = 0, 15 do
		for x = 0, 15 do
			aChunkDesc:SetBiome(x, z, biDesert)
		end
	end
	return true
end





--- Handles the HOOK_CHUNK_UNLOADING hook
-- Doesn't allow unloding chunks that are in the world limit
local function onChunkUnloading(aWorld, aChunkX, aChunkZ)
	if (shouldLoadChunk(aChunkX, aChunkZ)) then
		-- Disable unloading the chunk
		return true
	end

	-- Unload chunks outside the world limit
	return false
end





--- Starts loading the chunks for the specified world
-- Queues only up to 200 chunks at a single time
local function startLoadingWorld(aWorld)
	local minChunkX = floor(gConf.MinX / 16)
	local maxChunkX = floor(gConf.MaxX / 16)
	local minChunkZ = floor(gConf.MinZ / 16)
	local maxChunkZ = floor(gConf.MaxZ / 16)
	local numChunksZ = maxChunkZ - minChunkZ + 1
	local currentIdx = 0
	local maxIdx = (maxChunkX - minChunkX + 1) * numChunksZ
	local loadNextBatch

	-- Callback called after loading each 200 chunks:
	loadNextBatch = function()
		aWorld:QueueSaveAllChunks()
		if (currentIdx >= maxIdx) then
			LOG("World \"" .. aWorld:GetName() .. "\": complete.")
			return
		end
		local upto = currentIdx + 200
		if (upto > maxIdx) then
			upto = maxIdx
		end
		local coords = {}
		local idx = 1
		for i = currentIdx, upto - 1 do
			local chunkX = floor(i / numChunksZ) + minChunkX
			local chunkZ = i - (chunkX - minChunkX) * numChunksZ + minChunkZ
			coords[idx] = {chunkX, chunkZ}
			-- assert(shouldLoadChunk(chunkX, chunkZ))
			idx = idx + 1
		end
		LOG("World \"" .. aWorld:GetName() .. "\": queueing chunks " .. currentIdx .. " out of " .. maxIdx .. ", reports " .. aWorld:GetNumChunks())
		currentIdx = upto
		aWorld:ChunkStay(coords,
			nil,
			loadNextBatch
		)
	end

	-- Start loading the first batch:
	loadNextBatch()
end





function Initialize(aPlugin)
	loadConfig()
	cPluginManager:AddHook(cPluginManager.HOOK_CHUNK_GENERATING, onChunkGenerating)
	cPluginManager:AddHook(cPluginManager.HOOK_CHUNK_UNLOADING,  onChunkUnloading)

	-- Load / generate all chunks inside the world limit:
	cRoot:Get():ForEachWorld(startLoadingWorld)
	LOG("SmallWorldInRam is active")
	return true
end
