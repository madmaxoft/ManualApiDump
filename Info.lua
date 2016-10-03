-- Info.lua

-- Declares the plugin's metadata





g_PluginInfo =
{
	Name = "ManualApiDump",
	Description = "Exports API symbols that are documented in the APIDump plugin, but not in the AutoAPI. This is then used as ManualAPI for the CuberitePluginChecker script.",
	ConsoleCommands =
	{
		["manualapi"] =
		{
			Handler = HandleConsoleCmdManualApi,
			Help = "Dumps the manually-exported API symbols to a file",
			Alias = "ma",
		},
	},
}




