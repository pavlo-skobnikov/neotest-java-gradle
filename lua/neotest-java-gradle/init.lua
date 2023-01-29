local plenary_path = require("plenary.path")
local neotest_library = require("neotest.lib")


---@class neotest.Adapter
---@field name string
JavaGradleNeotestAdapter = { name = "neotest-java-gradle" }

---Find the project root directory given a current directory to work from.
---Should no root be found, the adapter can still be used in a non-project context if a test file matches.
---@async
---@param dir string @Directory to treat as cwd
---@return string | nil @Absolute root dir of test suite
JavaGradleNeotestAdapter.root = neotest_library.files.match_root_pattern({ "gradlew", "gradlew.bat" })

---Filter directories when searching for test files
---@async
---@param name string Name of directory
---@param rel_path string Path to directory, relative to root
---@param root string Root directory of project
---@return boolean
function JavaGradleNeotestAdapter.filter_dir(name, rel_path, root)
  return true
end

---@async
---@param file_path string
---@return boolean
function JavaGradleNeotestAdapter.is_test_file(file_path)
  -- Dismiss all non-Java files
  if not vim.endswith(file_path, ".java") then
    return false
  end

  -- Split the path and bring it to lower case
  local elems = vim.split(file_path, plenary_path.path.sep)
  local file_name = string.lower(elems[#elems])

  -- Name patterns for test classes to be detected by
  local patterns = { "test" }

  -- Search for patterns and immediately return on match
  for _, pattern in ipairs(patterns) do
    if string.find(file_name, pattern) then
      return true
    end
  end

  -- Fallback for no matches
  return false
end

---Given a file path, parse all the tests within it.
---@async
---@param file_path string Absolute file path
---@return neotest.Tree | nil
function JavaGradleNeotestAdapter.discover_positions(file_path)

  local query = [[
    (method_declaration
      (modifiers
        (marker_annotation
          name: (identifier) @annotation_name
          (#contains? @annotation_name "Test")))
      name: (identifier) @test.name) @test.definition
  ]]

  return neotest_library.treesitter.parse_positions(
    file_path,
    query,
    {
      nested_tests = false,
      require_namespaces = false,
    }
  )
end

---@param args neotest.RunArgs
---@return nil | neotest.RunSpec | neotest.RunSpec[]
function JavaGradleNeotestAdapter.build_spec(args)
  local position = args.tree:data()

  print("Position name: " .. position.name)

  return {
    command = "gradle test --tests '*" .. position.name .. "'",
    context = {
      position_id = position.id
    }
  }
end

---@async
---@param spec neotest.RunSpec
---@param result neotest.StrategyResult
---@param tree neotest.Tree
---@return table<string, neotest.Result>
function JavaGradleNeotestAdapter.results(spec, result, tree)
  local position_id = spec.context.position_id
  return {
    [position_id] = {
      status = result.code == 0 and "passed" or "failed",
      output = result.output,
    }
  }
end

return JavaGradleNeotestAdapter
