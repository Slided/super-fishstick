-- scans the shit

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local outputLines = {}

local function serialize(val, indent, visited)
	indent = indent or 0
	visited = visited or {}
	
	local t = type(val)
	if t == "table" then
		if visited[val] then
			return "\"{Circular Reference}\""
		end
		visited[val] = true
		
		local formatting = string.rep("  ", indent)
		local result = "{\n"
		for k, v in pairs(val) do
			local keyStr = tostring(k)
			if type(k) == "string" then
				keyStr = string.format("%q", k)
			end
			local success, res = pcall(function()
				return serialize(v, indent + 1, visited)
			end)
			if success then
				result = result .. formatting .. "  [" .. keyStr .. "] = " .. res .. ",\n"
			else
				result = result .. formatting .. "  [" .. keyStr .. "] = \"{Serialization Error}\",\n"
			end
		end
		result = result .. formatting .. "}"
		return result
	elseif t == "string" then
		return string.format("%q", val)
	elseif t == "number" or t == "boolean" then
		return tostring(val)
	else
		return string.format("%q", tostring(val))
	end
end

local function scanInstance(instance)
	table.insert(outputLines, "=== Instance: " .. instance:GetFullName() .. " (" .. instance.ClassName .. ") ===")
	
	local attributes = instance:GetAttributes()
	if next(attributes) then
		table.insert(outputLines, "  Attributes:")
		for attrName, attrVal in pairs(attributes) do
			table.insert(outputLines, "    " .. attrName .. " = " .. tostring(attrVal))
		end
	end

	if instance:IsA("ModuleScript") then
		local success, data = pcall(require, instance)
		if success then
			table.insert(outputLines, "  Module Return Data:")
			local sSuccess, serializedData = pcall(function()
				return serialize(data)
			end)
			if sSuccess then
				table.insert(outputLines, "    " .. serializedData)
			else
				table.insert(outputLines, "    [Failed to serialize table structure]")
			end
		else
			table.insert(outputLines, "  Module Require Error: " .. tostring(data))
		end
	elseif instance:IsA("ValueBase") then
		table.insert(outputLines, "  Value: " .. tostring(instance.Value))
	end

	table.insert(outputLines, "")

	for _, child in ipairs(instance:GetChildren()) do
		scanInstance(child)
	end
end

print("Starting deep scan of ReplicatedStorage and Player data...")
scanInstance(ReplicatedStorage)

if LocalPlayer then
	table.insert(outputLines, "=== PLAYER CONTAINERS & INVENTORY ===")
	for _, child in ipairs(LocalPlayer:GetChildren()) do
		if child:IsA("Folder") or child:IsA("Model") or child:IsA("Configuration") or child:IsA("IntValue") or child:IsA("StringValue") then
			scanInstance(child)
		end
	end
end

-- Attempt to hunt for any Remotes that might fetch inventory, favorites, or items
table.insert(outputLines, "=== HUNTING FOR INVENTORY / FAVORITE REMOTES ===")
for _, desc in ipairs(ReplicatedStorage:GetDescendants()) do
	if desc:IsA("RemoteFunction") or desc:IsA("RemoteEvent") then
		local nameLower = desc.Name:lower()
		if nameLower:find("inventory") or nameLower:find("favorite") or nameLower:find("item") or nameLower:find("storage") or nameLower:find("load") or nameLower:find("get") then
			table.insert(outputLines, "Found target remote: " .. desc:GetFullName())
			
			-- If it's a RemoteFunction, try invoking common payload patterns safely to dump data
			if desc:IsA("RemoteFunction") then
				for _, testArg in ipairs({"", "inventory", "favorites", "all", LocalPlayer.UserId, 1, true}) do
					local success, res = pcall(function()
						return desc:InvokeServer(testArg)
					end)
					if success and res then
						table.insert(outputLines, "  -> InvokeServer(\"" .. tostring(testArg) .. "\") Success! Result:")
						local sSuccess, sRes = pcall(function() return serialize(res) end)
						if sSuccess then
							table.insert(outputLines, "    " .. sRes)
						else
							table.insert(outputLines, "    " .. tostring(res))
						end
					end
				end
			end
		end
	end
end

local finalOutput = table.concat(outputLines, "\n")
print("Full scan & ID dump complete!")

if setclipboard then
	setclipboard(finalOutput)
	print("Successfully copied all data, inventories, items, and remote outputs to clipboard!")
else
	warn("setclipboard is not supported by your current executor.")
end
