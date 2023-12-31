---@alias Generator "Ninja" | "Ninja Multi-Config" | "Unix Makefiles"

--- @class cmake-kits.CmakeConfig
--- @field command string Path of the cmake executable.
--- @field generator Generator Generator to use to build the project.
--- @field build_directory string Path where cmake will build the project.
--- @field compile_commands_path string? Path where compile_commands.json will be copied to.
--- @field configure_args string[] Arguments that will be passed when configuring the project.
--- @field build_args string[] Arguments that will be passed when building the specified target.
local M = {}

M.command = "cmake"
M.generator = "Ninja"

M.build_directory = "${workspaceFolder}/build/${buildType}"

M.compile_commands_path = "${workspaceFolder}/compile_commands.json"

M.configure_args = { "-DCMAKE_EXPORT_COMPILE_COMMANDS=ON" }
M.build_args = {}

return M

--- Defaults
--- M.command = "cmake"
--- M.generator = "Ninja"

--- M.build_directory = "${workspaceFolder}/build/${buildType}"

--- M.compile_commands_path = "${workspaceFolder}/compile_commands.json"

--- M.configure_args = { "-DCMAKE_EXPORT_COMPILE_COMMANDS=ON" }
--- M.build_args = {}
