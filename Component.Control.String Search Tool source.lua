--[[
============================================================================
  Component Code Search Tool v2.0
  
  Search through all component code for specific strings or patterns.
  Supports both plain text and Lua pattern matching with detailed
  line-by-line results and visual position indicators.
  
  Created: December 2025
  Author: Joshua Cerecke - White Label AV
  Website: http://whitelabelav.co.nz
============================================================================
]]

function SetTextOnUserPatterns()
  Controls.UsePatterns.Legend = Controls.UsePatterns.Boolean and "Patterns" or "Plain Text"
end

all = Component.GetComponents()

-- Count function that respects the pattern flag
function count(base, pattern, isPattern)
  local count = 0
  local pos = 1
  while true do
    local success, found = pcall(string.find, base, pattern, pos, not isPattern)
    if not success then
      return nil, found  -- Return nil and error message
    end
    if not found then break end
    count = count + 1
    pos = found + 1
  end
  return count
end

-- Search within a specific string and add results to output table
function searchInString(code, searchPattern, locationName, output)
  local occurrences, err = count(code, searchPattern, Controls.UsePatterns.Boolean)
  
  -- Handle error from count function
  if not occurrences then
    return nil, string.format("Pattern error: %s", err)
  end
  
  -- Skip if no occurrences
  if occurrences == 0 then
    return true
  end
  
  local plural = occurrences == 1 and "" or "s"
  table.insert(output, string.format("%d occurrence%s found in component: %s", occurrences, plural, locationName))
  
  -- Better line splitting: add newline at end if missing, then split
  local codeWithNewline = code:match("\n$") and code or code .. "\n"
  local lines = {}
  for line in codeWithNewline:gmatch("([^\n]*)\n") do
    table.insert(lines, line)
  end
  
  local currentPos = 1
  local occurrenceNum = 0
  
  while true do
    local success, startPos, endPos = pcall(string.find, code, searchPattern, currentPos, not Controls.UsePatterns.Boolean)
    if not success then
      return nil, string.format("Pattern error during search: %s", startPos)
    end
    if not startPos then break end
    
    occurrenceNum = occurrenceNum + 1
    
    -- Count which line this occurrence is on
    local lineNum = 1
    local charCount = 0
    for i, line in ipairs(lines) do
      charCount = charCount + #line + 1 -- +1 for newline
      if startPos <= charCount then
        lineNum = i
        break
      end
    end
    
    -- Calculate column position within the line
    local lineStart = 1
    for i = 1, lineNum - 1 do
      lineStart = lineStart + #lines[i] + 1
    end
    local column = startPos - lineStart + 1
    
    -- Get the full line content
    local fullLine = lines[lineNum] or ""
    local trimmedLine = fullLine:match("^%s*(.-)%s*$")
    
    -- Add to output table
    table.insert(output, string.format("  [%d] Line %d, Column %d:", occurrenceNum, lineNum, column))
    table.insert(output, string.format("      %s", trimmedLine))
    table.insert(output, string.format("      %s^", string.rep(" ", column - 1)))
    
    currentPos = endPos + 1
  end
  
  return true
end

function doSearch()
  -- Collect all output here
  local output = {}
  
  local searchPattern = Controls.findme.String
  
  if Controls.UsePatterns.Boolean then
    -- If using patterns, auto-escape parentheses to prevent captures
    searchPattern = searchPattern:gsub("%(", "%%("):gsub("%)", "%%)")

    -- Validate pattern first if using patterns
    local success, err = pcall(string.find, "", searchPattern, 1, false)
    if not success then
      local errorMsg = string.format("Invalid pattern: %s\n\nError: %s\n\nReminder: In pattern mode, these characters must be escaped with %%:\n. [ ] * + - ? ^ $ %%", 
        Controls.findme.String, err)
      print(errorMsg)
      Controls.output.String = errorMsg
      return
    end
  end

  for _, component in ipairs(all) do
    if Controls.all.Boolean then
      -- Search through all controls in the component
      local componentControls = Component.GetControls(component.Name)
      
      for _, control in ipairs(componentControls) do
        if control.String then
          local success, err = searchInString(control.String, searchPattern, component.Name .. "." .. control.Name, output)
          if not success then
            print(err)
            Controls.output.String = err
            return
          end
        end
      end
    else
      -- Search through specific control name
      local comp = Component.New(component.Name)
      if comp[Controls.findin.String] then
        local success, err = searchInString(comp[Controls.findin.String].String, searchPattern, component.Name, output)
        if not success then
          print(err)
          Controls.output.String = err
          return
        end
      end
    end
  end

  -- Print the entire output as one multiline string at the very end
  if #output > 0 then
    output = table.concat(output, "\n")
  else
    output = "No occurrences found in any component"
    if Controls.UsePatterns.Boolean then
      output = output .. "\n\nNote: Pattern mode is enabled. Parentheses are treated as literal. Other special characters like . * + - ? must be escaped with %"
    end
  end
  print(output)
  Controls.output.String = output
end

Controls.findme.EventHandler = doSearch
Controls.findin.EventHandler = doSearch

Controls.UsePatterns.EventHandler = function()
  SetTextOnUserPatterns()
  doSearch()
end

Controls.default.EventHandler = function()
  Controls.all.Boolean = false
  Controls.findin.String = "code"
  Controls.findin.IsDisabled = false

  doSearch()
end

function SetFindInTextBox()
  Controls.findin.IsDisabled = Controls.all.Boolean
  if Controls.all.Boolean then 
    FindInString = Controls.findin.String
    Controls.findin.String = ""
  else 
    Controls.findin.String = FindInString
  end
end

Controls.all.EventHandler = function()
  SetFindInTextBox()
  doSearch()
end

SetTextOnUserPatterns()
doSearch()