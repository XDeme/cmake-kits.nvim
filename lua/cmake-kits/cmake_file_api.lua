local Path = require("plenary.path")

local M = {}

function M.create_query(build_dir)
    local path = Path:new(build_dir) / ".cmake" / "api" / "v1" / "query" / "client-cmake-kits"
    path:mkdir({ parents = true })
    local query_path = path / "query.json"
    local file = io.open(tostring(query_path), "w+")
    if file then
        local data = {
            requests = {
                {
                    kind = "codemodel",
                    version = 2,
                }
            }
        }
        file:write(vim.json.encode(data))
        file:close()
    end
end

return M