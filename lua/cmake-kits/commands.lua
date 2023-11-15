local project = require("cmake-kits.project")
local config = require("cmake-kits.config")
local plenay_job = require("plenary.job")
local kits = require("cmake-kits.kits")
local utils = require("cmake-kits.utils")
local cmake_file_api = require("cmake-kits.cmake_file_api")
local Path = require("plenary.path")
local terminal = require("cmake-kits.terminal")

local M = {}

M.active_job = nil

M.configure = function(callback)
    if M.active_job then
        utils.notify(
            "Configuration error",
            "You must wait for another command to finish to use this command"
        )
        return
    end
    terminal.clear()

    local build_dir = project.interpolate_string(config.build_directory)
    cmake_file_api.create_query(build_dir)

    local args = {
        "-S",
        project.root_dir,
        "-B",
        build_dir,
        "-G",
        config.generator,
        unpack(config.configure_args),
        "-DCMAKE_BUILD_TYPE=" .. project.build_type,
    }
    if kits.selected_kit ~= "Unspecified" then
        table.insert(args, "-DCMAKE_C_COMPILER=" .. kits.selected_kit.compilers.C) -- C compiler is guaranteed to exist
        if kits.selected_kit.compilers.CXX then
            table.insert(args, "-DCMAKE_CXX_COMPILER=" .. kits.selected_kit.compilers.CXX)
        end
    end

    M.active_job = true
    plenay_job
        :new({
            command = config.command,
            args = args,
            on_stdout = function(_, data)
                vim.schedule(function()
                    terminal.send_data("[configure] " .. data)
                end)
            end,
            on_stderr = function(_, data)
                vim.schedule(function()
                    terminal.send_data("[configure] " .. data)
                end)
            end,
            on_exit = function(_, code)
                M.active_job = false
                if code ~= 0 then
                    utils.notify("Configuration", "Failure")
                    return
                end

                utils.notify("Configuration", "Sucessful", vim.log.levels.INFO)

                if config.compile_commands_path then
                    local source = Path:new(build_dir) / "compile_commands.json"
                    local destination =
                        Path:new(project.interpolate_string(config.compile_commands_path))
                    if destination:is_dir() then
                        destination = destination / "compile_commands.json"
                    end
                    source:copy({
                        destination = destination,
                    })
                end

                project.build_targets = cmake_file_api.get_build_targets(build_dir)
                project.runnable_targets =
                    cmake_file_api.get_runnable_targets(project.build_targets)
                if type(callback) == "function" then
                    callback()
                end
            end,
        })
        :start()
end

M.build = function(callback)
    if M.active_job then
        utils.notify(
            "Build error",
            "You must wait for another command to finish to use this command"
        )
        return
    end

    local build_dir = project.interpolate_string(config.build_directory)
    if vim.fn.isdirectory(build_dir) == 0 then
        return M.configure(M.build)
    end

    vim.ui.select(project.build_targets, {
        prompt = "Select build target",
        format_item = function(target)
            return target.name
        end,
    }, function(choice)
        if choice == nil then
            return
        end
        project.selected_build = choice
        M.create_build_job(build_dir, callback, choice)
    end)
end

function M.quick_build(callback)
    if M.active_job then
        utils.notify(
            "Build error",
            "You must wait for another command to finish to use this command"
        )
        return
    end
    if project.selected_build == nil then
        utils.notify(
            "Build error",
            "You must select a build target before running CmakeQuickBuild",
            vim.log.levels.ERROR
        )
        return
    end

    local build_dir = project.interpolate_string(config.build_directory)
    if vim.fn.isdirectory(build_dir) == 0 or vim.tbl_isempty(project.build_targets) then
        return M.configure(function()
            M.quick_build(callback)
        end)
    end
    M.create_build_job(build_dir, callback, project.selected_build)
end

M.run = function(callback)
    if M.active_job then
        utils.notify("Run error", "You must wait for another command to finish to use this command")
        return
    end

    local build_dir = project.interpolate_string(config.build_directory)
    if vim.fn.isdirectory(build_dir) == 0 then
        return M.configure(M.run)
    end

    vim.ui.select(project.runnable_targets, {
        prompt = "Select a target to run",
        format_item = function(target)
            return target.name
        end,
    }, function(choice)
        if choice == nil then
            return
        end
        project.selected_runnable = choice
        M.create_build_job(build_dir, function()
            M.create_run_job(callback)
        end, project.selected_runnable)
    end)
end

function M.quick_run(callback)
    if M.active_job then
        utils.notify("Run error", "You must wait for another command to finish to use this command")
        return
    end
    if project.selected_runnable == nil then
        utils.notify(
            "Run error",
            "You must select a runnable target before running CmakeQuickRun",
            vim.log.levels.ERROR
        )
        return
    end

    local build_dir = project.interpolate_string(config.build_directory)
    if vim.fn.isdirectory(build_dir) == 0 or vim.tbl_isempty(project.runnable_targets) then
        return M.configure(function()
            M.quick_run(callback)
        end)
    end

    M.create_run_job(callback)
end

--- @param target cmake-kits.Target
function M.create_build_job(build_dir, callback, target)
    if target == nil then
        target = {
            name = "all",
            full_path = nil,
        }
    end
    M.active_job = true
    plenay_job
        :new({
            command = config.command,
            args = { "--build", build_dir, "--config", project.build_type, "--target", target.name },
            on_stdout = function(_, data)
                vim.schedule(function()
                    terminal.send_data("[build] " .. data)
                end)
            end,
            on_stderr = function(_, data)
                vim.schedule(function()
                    terminal.send_data("[build] " .. data)
                end)
            end,
            on_exit = function(_, code)
                M.active_job = false
                if code ~= 0 then
                    utils.notify("Build", "Build error")
                    return
                end

                utils.notify("Build", "Sucessful", vim.log.levels.INFO)
                if type(callback) == "function" then
                    callback()
                end
            end,
        })
        :start()
end

function M.create_run_job(callback)
    if not Path:new(project.selected_runnable.full_path):exists() then
        local build_dir = project.interpolate_string(config.build_directory)
        return M.create_build_job(build_dir, function()
            M.create_run_job(callback)
        end, project.selected_runnable)
    end

    M.active_job = true
    local ext_terminal, args = utils.get_external_terminal()
    plenay_job
        :new({
            command = ext_terminal,
            args = {
                unpack(args),
                "bash",
                "-c",
                project.selected_runnable.full_path
                    .. " && "
                    .. 'read -n 1 -r -p "\nPress any key to continue..."',
            },
            on_start = function()
                --- The on_exit is only called when the console exits.
                --- This enables the user to run more than one target.
                M.active_job = false
            end,
            on_exit = function(_, code)
                if code ~= 0 then
                    utils.notify("Run", "Exited with code " .. tostring(code))
                    return
                end

                if type(callback) == "function" then
                    callback()
                end
            end,
        })
        :start()
end

return M
