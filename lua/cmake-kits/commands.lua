local project = require("cmake-kits.project")
local config = require("cmake-kits.config")
local plenay_job = require("plenary.job")

local M = {}

M.configure = function(callback)
    if project.root_dir == nil then
        error("You must be in a cmake project")
        return
    end

    local args = {
        "-S",
        project.root_dir,
        "-B",
        project.interpolate_string(config.build_directory),
        "-G",
        config.generator,
        "-DCMAKE_BUILD_TYPE=" .. project.build_type,
    }
    if project.selected_kit ~= "Unspecified" then
        table.insert(args, "-DCMAKE_C_COMPILER=" .. project.selected_kit.compilers.C) -- C compiler is guaranteed to exist
        if project.selected_kit.compilers.CXX then
            table.insert(args, "-DCMAKE_CXX_COMPILER=" .. project.selected_kit.compilers.CXX)
        end
    end

    for _, arg in ipairs(config.configure_args) do
        table.insert(args, arg)
    end
    plenay_job:new({
        command = config.command,
        args = args,
        on_stderr = function(err, data)
            vim.print(data)
        end,
        on_exit = function()
            M.update_build_targets(callback)
        end
    }):start()
end

M.build = function(callback)
    local build_dir = project.interpolate_string(config.build_directory)
    if vim.fn.isdirectory(build_dir) == 0 then
        return M.configure(M.build)
    end

    vim.ui.select(project.build_targets, {
        prompt = "Select build target",
    }, function(choice)
        if choice == nil then
            return
        end
        project.selected_build = choice
        plenay_job:new({
            command = config.command,
            args = { "--build", build_dir, "--config", project.build_type, "--target", choice },
            on_exit = function()
                if type(callback) == "function" then
                    callback()
                end
            end
        }):start()
    end)
end

M.update_build_targets = function(callback)
    local build_dir = project.interpolate_string(config.build_directory)
    project.build_targets = {}
    plenay_job:new({
        command = config.command,
        args = { "--build", build_dir, "--config", project.build_type, "--target", "help" },
        on_stdout = function(err, data)
            if not vim.endswith(data, "phony") then
                return
            elseif vim.startswith(data, "Experimental") or vim.startswith(data, "Nightly") or vim.startswith(data, "Continuous") then
                return
            end
            local name = data:sub(0, #data - 7)                                                                           -- remove `phony` from the end
            if vim.endswith(name, "test") or vim.endswith(name, "rebuild_cache") or vim.endswith(name, "edit_cache") then -- Filter reserved names from cmake
                return
            end
            table.insert(project.build_targets, name)
        end,
        on_exit = function()
            if type(callback) == "function" then
                callback()
            end
        end
    }):start()
end
return M
