# ManualApiDump
Plugin for Cuberite that dumps the manually-exported API symbols in a machine-readable format. The main point of this plugin is to provide the ManualAPI descriptions for the CuberitePluginChecker project.

It calculates the difference between the API documented in the APIDump plugin, considering that the complete API, and discarding symbols that are described in the ToLua++-generated API description (by Cuberite's src/Bindings/BindingsGenerator.lua script). The symbols left are what is considered the ManualAPI; the function parameters' and return values' types are guessed using various heuristics and finally output into a Lua-formatted file.

# Running the script
The script is made as a Cuberite plugin, so you need Cuberite to run it. It also requires the APIDump plugin to be present, and the `src/Bindings/docs` folder, generated during Cuberite build. Paths for both of these can be specified as the command arguments.
Run Cuberite, load the plugin, then execute the `manualapi` console command (or `manualapi <docsFolderPath> <APIDumpFolderPath>` if your folders are not default). The resulting manual API will be dumped to ManualAPI.lua file next to the Cuberite's executable.
