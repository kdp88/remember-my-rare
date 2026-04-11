-- tests/run_tests.lua
-- Entry point: runs all test suites and exits with a non-zero code on failure.
--
-- Usage:
--   lua tests/run_tests.lua          (from repo root)
--   lua tests/run_tests.lua -v       (verbose output)

local lu = require("luaunit")

-- Derive the addon root from this script's path so dofile() works regardless
-- of the working directory.
local ROOT = arg[0]:match("(.*[/\\])") .. "../"

-- Load test suites (each file registers its TestXxx tables globally).
dofile(ROOT .. "tests/test_data.lua")
dofile(ROOT .. "tests/test_events.lua")

os.exit(lu.LuaUnit.run())
