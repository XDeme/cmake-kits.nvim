local config = require("cmake-kits.config")
local project = require("cmake-kits.project")
local kits = require("cmake-kits.kits")
local commands = require("cmake-kits.commands")

vim.api.nvim_create_user_command("CmakeSetRootDir", function(opts)
    if not vim.tbl_isempty(opts.fargs) then
        project.root_dir = opts.fargs[1]
        return
    end
    local cwd = vim.uv.cwd()
    vim.ui.input({
        prompt = "Input your root dir",
        default = cwd,
        completion = "dir",
    }, function(input)
        if input == nil then
            return
        end
        project.root_dir = cwd
    end)
end, { nargs = "*" })

vim.api.nvim_create_user_command("CmakeSelectBuildType", function(opts)
    if not vim.tbl_isempty(opts.fargs) then
        project.build_type = opts.fargs[1]
        return
    end
    project.select_build_type()
end, {
    nargs = "*",
    complete = function()
        -- TODO: Implement Filter based on current input
        return { "Debug", "Release", "MinSizeRel", "RelWithDebInfo" }
    end
})

vim.api.nvim_create_user_command("CmakeSelectKit", function()
    kits.select_kit()
end, {})

vim.api.nvim_create_user_command("CmakeConfigure", function()
    commands.configure()
end, {})

vim.api.nvim_create_user_command("CmakeBuild", function()
    commands.build()
end, {})
