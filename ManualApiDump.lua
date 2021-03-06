-- ManualApiDump.lua

-- Implements the entire plugin logic






--- Serializes a simple table (no functions, no loops, simple strings as table keys)
-- a_Table is the table to serialize
-- a_Indent is the indenting to use
local function serializeSimpleTable(a_Table, a_Indent)
	-- Check params:
	assert(type(a_Table) == "table")
	local indent = a_Indent or ""
	assert(type(indent) == "string")

	-- Sort the keys alphabetically:
	local keys = {}
	local allKeysAreNumbers = true
	for k, _ in pairs(a_Table) do
		local kt = type(k)
		assert((kt == "string") or (kt == "number"), "Unsupported key type in table to serialize: " .. kt)
		if (kt ~= "number") then
			allKeysAreNumbers = false
		end
		table.insert(keys, k)
	end
	local sortFn
	if not(allKeysAreNumbers) then
		sortFn = function (a_Key1, a_Key2)
			return (tostring(a_Key1) < tostring(a_Key2))
		end
	end
	table.sort(keys, sortFn)

	-- Output the keys:
	local lines = {}
	local idx = 1
	for _, key in ipairs(keys) do
		local v = a_Table[key]
		if (type(key) == "number") then
			key = "[" .. tostring(key) .. "]"
		end
		local vt = type(v)
		if (vt == "table") then
			if not(allKeysAreNumbers) then
				lines[idx] = indent .. key .. " ="
				idx = idx + 1
			end
			lines[idx] = indent .. "{"
			lines[idx + 1] = serializeSimpleTable(v, indent .. "\t")
			lines[idx + 2] = indent .. "},"
			idx = idx + 3
		elseif (
			(vt == "number") or
			(vt == "boolean")
		) then
			-- Numbers and bools have a safe "tostring" function
			lines[idx] = string.format("%s%s = %s,", indent, key, tostring(v))
			idx = idx + 1
		elseif (vt == "string") then
			-- Use a special format for strings: %q includes the quotes and escapes as needed
			lines[idx] = string.format("%s%s = %q,", indent, key, tostring(v))
			idx = idx + 1
		else
			error("Unsupported value type in table to serialize: " .. type(v))
		end
	end
	return table.concat(lines, "\n")
end





--- Loads the AutoAPI files (from BindingsProcessor.lua) into a single API description table
-- Returns a table with Classes and Globals members, combining all the AutoAPI files into a single one
local function loadAutoApi(a_AutoApiPath)
	local autoApiPath = a_AutoApiPath or "BindingsDocs"  -- Assume a regular CI build with proper symlink setup
	local autoApi = assert(dofile(autoApiPath .. "/_files.lua"))
	local res =
	{
		Classes = {}
	}
	for _, fnam in ipairs(autoApi) do
		local api = assert(dofile(autoApiPath .. "/" .. fnam))
		for k, v in pairs(api) do
			if (k == "Globals") then
				res.Globals = v
			else
				res.Classes[k] = v
			end
		end
	end
	return res
end





--- Loads the API descriptions from the APIDump plugin
-- Returns the API description table (Classes, Globals)
local function loadApiDesc(a_ApiDumpPath)
	-- If not given, assume the default APIDump plugin's folder:
	if not(a_ApiDumpPath) then
		a_ApiDumpPath = cPluginManager:GetPluginsPath() .. "/APIDump"
	end

	-- Load all the API description files:
	local res = assert(dofile(a_ApiDumpPath .. "/APIDesc.lua"))
	local classesPath = a_ApiDumpPath .. "/Classes/"
	for _, fnam in ipairs(cFile:GetFolderContents(classesPath)) do
		if (fnam:match(".+%.lua$")) then
			local f = assert(dofile(classesPath .. fnam))
			for k, v in pairs(f) do
				res.Classes[k] = v
			end
		end
	end

	-- Move Globals into a separate namespace:
	res.Globals = res.Classes.Globals
	res.Classes.Globals = nil
	res.Globals.ClassName = "Globals"

	return res
end





--- Dictionary of known param description to type mapping
local g_KnownTypesMap =
{
	AngleDegrees = "number",
	Biome = "number",
	BlockFace = "eBlockFace",
	BlockMeta = "number",
	BlockType = "number",
	BLOCKTYPE = "number",
	BlockX = "number",
	BlockY = "number",
	BlockZ = "number",
	bool = "boolean",
	boolean = "boolean",
	IniFile = "cIniFile",
	ItemType = "number",
	max = "number",
	min = "number",
	NIBBLETYPE = "number",
	Number = "number",
	number = "number",
	self = "self",
	table = "table",
	Vector3i = "Vector3i",
	Vector3f = "Vector3f",
	Vector3d = "Vector3d",
	x = "number",
	X = "number",
	y = "number",
	Y = "number",
	z = "number",
	Z = "number",
	["{{Globals#BlockFaces|eBlockFace}}"] = "eBlockFace",
	["{{Globals#BlockFace|eBlockFace}}"] = "eBlockFace",
	["{{Globals#ClickAction|ClickAction}}"] = "eClickAction",
	["{{Globals#DamageType|DamageType}}"] = "eDamageType",
	["{{Globals#MobType|MobType}}"] = "eMobType",
}




--- Array of string match patterns, if a param contains the Pattern string, it will be considered that type
local g_KnownTypesMatchers =
{
	--[[
	Template:
	{ Pattern = "", Type = "" },
	--]]
	{ Pattern = "Are[A-Z]", Type = "boolean" },
	{ Pattern = "Block[XYZ]", Type = "number" },
	{ Pattern = "BoundingBox", Type = "cBoundingBox" },
	{ Pattern = "Coeff", Type = "number" },
	{ Pattern = "Count", Type = "number" },
	{ Pattern = "Cuboid", Type = "cCuboid" },
	{ Pattern = "Data", Type = "string" },
	{ Pattern = "Does[A-Z]", Type = "boolean" },
	{ Pattern = "Enchantments", Type = "cEnchantments" },
	{ Pattern = "End[XYZ]", Type = "number" },
	{ Pattern = "Face", Type = "eBlockFace" },
	{ Pattern = "Height", Type = "number" },
	{ Pattern = "Is[A-Z]", Type = "boolean" },
	{ Pattern = "Length", Type = "number" },
	{ Pattern = "Max", Type = "number" },
	{ Pattern = "Message", Type = "string" },
	{ Pattern = "Min", Type = "number" },
	{ Pattern = "Name", Type = "string" },
	{ Pattern = "Num", Type = "number" },
	{ Pattern = "Origin[XYZ]", Type = "number" },
	{ Pattern = "Path", Type = "string" },
	{ Pattern = "Radius", Type = "number" },
	{ Pattern = "Rel[XYZ]", Type = "number" },
	{ Pattern = "Should[A-Z]", Type = "boolean" },
	{ Pattern = "Size[XYZ]", Type = "number" },
	{ Pattern = "Start[XYZ]", Type = "number" },
	{ Pattern = "Str", Type = "string" },
	{ Pattern = "str", Type = "string" },
	{ Pattern = "Text", Type = "string" },
	{ Pattern = "Use[A-Z]", Type = "boolean" },
	{ Pattern = "UUID", Type = "string" },
	{ Pattern = "Width", Type = "number" },
	{ Pattern = "[XYZ][12]", Type = "number" },
}





--- Tries to guess a parameter type based on the string provided in the API docs
-- Returns the guessed Lua type
-- a_ParamString is the parameter's description from the API docs, such as "Command" or "{{cPlayer|Player}}
local function guessParamType(a_ParamString, a_ApiDesc)
	-- Check params:
	assert(type(a_ParamString) == "string")
	assert(type(a_ApiDesc) == "table")

	-- Try a list of known types:
	local k = g_KnownTypesMap[a_ParamString]
	if (k) then
		return k
	end

	-- If the param desc matches a class name in the API desc, use that:
	if (a_ApiDesc.Classes[a_ParamString]) then
		return a_ParamString
	end

	-- Try to match "{{ClassName}}" and "{{ClassName|ParamName}}" descriptions:
	local className = a_ParamString:match("%{%{([^|}]+)|?.*%}%}")
	if (className) then
		return className
	end

	for _, matcher in ipairs(g_KnownTypesMatchers) do
		if (a_ParamString:find(matcher.Pattern)) then
			return matcher.Type
		end
	end

	return "<unknown>"
end





--- Returns a table describing the function param types, guessed from their descriptions
-- a_Params is the APIDesc's Params or Returns value (usually a comma-separated string, could be the output format as well)
-- a_APIDesc is the complete API description (used for classname matching)
-- Returns a new table describing the param types, guessed: { {Type = "LuaType"}, {Type = "LuaType"}, ... }
local function guessParamTypes(a_Params, a_ApiDesc)
	-- Check params:
	assert(type(a_ApiDesc) == "table")

	if not(a_Params) then
		return nil
	elseif (type(a_Params) == "string") then
		-- The old style of documentation, all params are described in a single comma-separated string
		-- Split the string, try to guess param types:
		local split = StringSplitAndTrim(a_Params, ",")
		local params = {}
		for idx, v in ipairs(split) do
			local isOptional
			if (v:match("%b[]")) then
				isOptional = true
				v = string.sub(v, 2, -2)  -- Cut away the brackets at the ends
			end
			params[idx] = { Type = guessParamType(v, a_ApiDesc), IsOptional = isOptional}
			if (params[idx].Type == "<unknown>") then
				params[idx].OrigType = v
			end
		end
		return params
	elseif (type(a_Params) == "table") then
		-- The new style of documentation, all params are described properly, just copy the table to output:
		local params = {}
		for idx, v in ipairs(a_Params) do
			params[idx] = { }
			for paramK, paramV in pairs(v) do
				params[idx][paramK] = paramV
			end
		end
		return params
	end
	error("Unhandled params description type: " .. type(a_Params))
end





--- Returns the diff of the class' ApiDesc minus AutoAPI, as a table
-- a_ClassAutoAPI is the class' description loaded from AutoAPI
-- a_ClassDesc is the class' description loaded from APIDump
-- a_APIDesc is the complete API descriptions
local function diffClass(a_ClassAutoAPI, a_ClassDesc, a_ApiDesc)
	-- Check params:
	assert(type(a_ClassAutoAPI) == "table")
	assert(type(a_ClassDesc) == "table")
	assert(type(a_ApiDesc) == "table")

	-- Diff the functions:
	local autoFunctions = a_ClassAutoAPI.Functions or {}
	local res =
	{
		Functions = {},
	}
	for fnName, fnDesc in pairs(a_ClassDesc.Functions or {}) do
		if not(autoFunctions[fnName]) then
			local fnDiff = {}
			res.Functions[fnName] = fnDiff
			local signatures = fnDesc[1] and fnDesc or {fnDesc}  -- Normalize the signatures to always be an array-table
			for idx, signature in ipairs(signatures) do
				fnDiff[idx] =
				{
					Params = guessParamTypes(signature.Params, a_ApiDesc),
					Returns = guessParamTypes(signature.Returns, a_ApiDesc),
					IsStatic = signature.IsStatic,
					IsGlobal = signature.IsGlobal,
				}
			end  -- for - signatures[]
		end  -- if not in AutoAPI
	end  -- for fnName, fnDesc

	return res
end





--- Removes all sub-tables that are empty, recursively
local function pruneEmptySubTables(a_Table)
	-- Check params:
	assert(type(a_Table) == "table")

	-- Recurse into children, detect empty subtables:
	local toRemove = {}
	for k, v in pairs(a_Table) do
		if (type(v) == "table") then
			pruneEmptySubTables(v)
			if not(next(v)) then  -- is "v" empty?
				table.insert(toRemove, k)
			end
		end
	end

	-- Remove the empty children:
	for _, k in ipairs(toRemove) do
		a_Table[k] = nil
	end
end





--- Returns the diff of ApiDesc minus AutoAPI as a table
local function diffApi(a_AutoApi, a_ApiDesc)
	-- Check params:
	assert(a_AutoApi)
	assert(a_ApiDesc)
	assert(type(a_AutoApi.Classes) == "table")
	assert(type(a_AutoApi.Globals) == "table")
	assert(type(a_ApiDesc.Classes) == "table")
	assert(type(a_ApiDesc.Globals) == "table")
	assert(not(a_ApiDesc.Classes.Globals))

	-- Diff the classes:
	local res = {Classes = {}}
	res.Globals = diffClass(a_AutoApi.Globals, a_ApiDesc.Globals, a_ApiDesc)
	for className, classDesc in pairs(a_ApiDesc.Classes) do
		local classAutoApi = a_AutoApi.Classes[className] or {}
		res.Classes[className] = diffClass(classAutoApi, classDesc, a_ApiDesc)
	end

	return res
end





--- Returns the type of the object
-- Recognizes Cuberite types (via tolua.type()) and returns those instead of "userdata"
-- If the object is nil, returns a nil
local function typeOf(a_Object)
	local objType = type(a_Object)
	if (objType == "userdata") then
		return tolua.type(a_Object)
	end
	if (objType == "nil") then
		return nil
	end
	return objType
end





--- Adds the class' constants and variables into the output
-- a_Class is the class table (such as _G.cPlugin)
-- a_Output is the table which is to receive the Constants and Variables members specifying the symbols
local function addConstantsAndVariables(a_Class, a_Output)
	-- Check params:
	assert(type(a_Class) == "table")
	assert(type(a_Output) == "table")

	a_Output.Variables = a_Output.Variables or {}
	a_Output.Constants = a_Output.Constants or {}

	-- Constants and variables are stored in the ".get" and ".set" class members as entries in the dictionary table.
	-- Variables are in both, constants only in ".get".
	local dotGet = a_Class[".get"]
	if (dotGet and (type(dotGet) == "table")) then
		local dotSet = a_Class[".set"] or {}
		local res, classInstance = pcall(a_Class)  -- This works only for classes with Lua-accessible constructors
		if not(res) then
			classInstance = nil
		end
		for symbolName, _ in pairs(dotGet) do
			local desc = a_Output.Variables[symbolName] or a_Output.Constants[symbolName] or { Name = symbolName }
			if (dotSet[symbolName]) then
				-- It is a variable. Try to get its type:
				if (classInstance) then
					desc.Type = typeOf(classInstance[symbolName])
				end
				a_Output.Variables[symbolName] = desc
			else
				-- It is a constant. Try to get its value and type:
				local isSuccess, value = pcall(dotGet[symbolName], a_Class)
				if (isSuccess) then
					desc.Type = typeOf(value)
					desc.Value = value
				end
				a_Output.Constants[symbolName] = desc
			end
		end  -- for symbolName - dotGet[]
	end

	-- Add the directly accessible values in the class tables (such as sqlite3.OK), as constants:
	for symbolName, symbolValue in pairs(a_Class) do
		local st = type(symbolValue)
		if (
			(st == "string") or
			(st == "number") or
			(st == "boolean")
		) then
			a_Output.Constants[symbolName] = a_Output.Constants[symbolName] or { Type = st, Value = symbolValue }
		end
	end
end





--- Adds the class' enums (ConstantGroups) into the output
-- a_Class is the class table (such as _G.cPlugin)
-- a_Desc is the class description (from APIDesc)
-- a_Output is the table which is to receive the Enums members specifying the symbols
local function addEnums(a_Class, a_Desc, a_Output)
	-- Check params:
	assert(type(a_Class) == "table")
	assert(type(a_Desc) == "table")
	assert(type(a_Output) == "table")

	-- If there are no constant groups described, bail out:
	if not(a_Desc.ConstantGroups) then
		return
	end

	-- Insert lists of all constants matching the constant groups' description:
	a_Output.Enums = {}
	for enumName, enumDesc in pairs(a_Desc.ConstantGroups) do
		if (type(enumDesc.Include) ~= "table") then
			enumDesc.Include = { enumDesc.Include }
		end
		local values = {}
		for symName, _ in pairs(a_Output.Constants) do
			for _, inc in ipairs(enumDesc.Include) do
				if (string.match(symName, inc)) then
					table.insert(values, { Name = symName })
				end
			end
		end
		a_Output.Enums[enumName] = values
	end
end





--- Dumps all symbols that are in a_ApiDesc, but not in a_AutoApi
-- The output format is usable by CuberitePluginChecker as the manual API, except for the parameter types
-- We can safely assume that there's no function that has both automatic and manual signatures - ToLua++ cannot do that
-- Therefore we walk through all ApiDesc functions and check each against AutoApi:
local function dumpManualSymbols(a_AutoApi, a_ApiDesc)
	-- Check params:
	assert(a_AutoApi)
	assert(a_ApiDesc)
	assert(type(a_AutoApi.Classes) == "table")
	assert(type(a_AutoApi.Globals) == "table")
	assert(type(a_ApiDesc.Classes) == "table")
	assert(type(a_ApiDesc.Globals) == "table")
	assert(not(a_ApiDesc.Classes.Globals))

	-- Calculate the diff - ApiDesc minus AutoAPI:
	local diff = diffApi(a_AutoApi, a_ApiDesc)
	if not(diff) then
		LOG("Failed to diff the API")
		return
	end

	-- Add the enums, constants and variables to the diff:
	for className, classDesc in pairs(a_ApiDesc.Classes) do
		local class = _G[className]
		if (class) then
			diff.Classes[className] = diff.Classes[className] or {}
			addConstantsAndVariables(class, diff.Classes[className])
			addEnums(class, classDesc, diff.Classes[className])
		end
	end
	addConstantsAndVariables(_G, diff.Globals)
	addEnums(_G, a_ApiDesc.Globals, diff.Globals)

	-- Output the differences:
	pruneEmptySubTables(diff)
	local f = assert(io.open("ManualAPI.lua", "w"))
	f:write("return\n{\n", serializeSimpleTable(diff, "\t"), "\n}\n")
	f:close()

	-- Check that the produced file is valid, by loading it:
	local test = assert(loadfile("ManualAPI.lua"))
	local sandbox = {}
	setfenv(test, sandbox)
	test()  -- Execute the file
end





--- Handler for the "manualapi" command
-- Command signature: "manualapi [<autoApiPath> [<APIDump path>]]
function HandleConsoleCmdManualApi(a_Split)
	-- Load the AutoAPI documentation
	local autoApi = loadAutoApi(a_Split[2])

	-- Load the documentation in the APIDump plugin:
	local apiDesc = loadApiDesc(a_Split[3])

	-- Dump the manual symbols (in apiDesc, not in autoApi):
	dumpManualSymbols(autoApi, apiDesc)

	return true, "Manual API symbols dumped"
end





function Initialize(a_Plugin)
	-- Register the commands:
	dofile(cPluginManager:GetPluginsPath() .. "/InfoReg.lua")
	RegisterPluginInfoConsoleCommands()
	return true
end




