-- [nfnl] fnl/run_visual/init.fnl
local function get_selection_text()
  vim.cmd("normal! gv\"xy")
  return vim.fn.trim(vim.fn.getreg("x"))
end
local function write_selection_to_tmp_file()
  local selection_text = get_selection_text()
  local tmp_file = (vim.fs.dirname(os.tmpname()) .. "/nvim_run_visual_tmp")
  vim.fn.writefile(vim.split(selection_text, "\n"), tmp_file)
  if vim.fn.has("unix") then
    os.execute(("chmod 777 " .. tmp_file))
  else
  end
  return tmp_file
end
local state = {bufid = nil, winid = nil}
local function buffer_append(lines)
  local bufid = state["bufid"]
  local winid = state["winid"]
  local line_start = vim.api.nvim_buf_line_count(bufid)
  if (1 == line_start) then
    line_start = 0
  else
  end
  vim.api.nvim_buf_set_lines(bufid, line_start, -1, false, lines)
  return vim.api.nvim_win_set_cursor(winid, {vim.api.nvim_buf_line_count(bufid), 0})
end
local function ensure_buf_and_win()
  local bufid = state["bufid"]
  local winid = state["winid"]
  if not (bufid and (1 == vim.fn.bufexists(bufid))) then
    bufid = vim.api.nvim_create_buf(false, true)
    vim.bo[bufid]["filetype"] = "RunVisual"
  else
  end
  if not (winid and vim.api.nvim_win_is_valid(winid)) then
    winid = vim.api.nvim_open_win(bufid, false, {split = "below", style = "minimal"})
  else
  end
  state.bufid = bufid
  state.winid = winid
  return nil
end
local function title_lines(cmd)
  local time_str = os.date("!%m-%d %H:%M:%S", os.time())
  return {("# " .. string.rep("-", 80)), ("# " .. time_str .. " - " .. table.concat(cmd, " "))}
end
local function result_lines(_5_)
  local code = _5_["code"]
  local stdout = _5_["stdout"]
  local stderr = _5_["stderr"]
  local text
  if (code == 0) then
    text = stdout
  elseif (nil ~= code) then
    local code0 = code
    local _6_
    if (stderr ~= "") then
      _6_ = stderr
    else
      _6_ = stdout
    end
    text = ("\240\159\146\128 Code: " .. code0 .. "\n" .. _6_)
  else
    text = nil
  end
  local function _11_()
    local _9_, _10_ = string.gsub(text, "\27%[.-m", "")
    if ((nil ~= _9_) and true) then
      local a = _9_
      local _ = _10_
      return a
    else
      return nil
    end
  end
  return vim.fn.split(vim.fn.trim(_11_()), "\n", true)
end
local function create_user_cmds(bufid)
  local function _14_(_13_)
    local fargs = _13_["fargs"]
    local tmp_file = write_selection_to_tmp_file()
    local cmd = {unpack(fargs), tmp_file}
    ensure_buf_and_win()
    buffer_append(title_lines(cmd))
    local function log_result(obj)
      return buffer_append(result_lines(obj))
    end
    return vim.system(cmd, {text = true}, vim.schedule_wrap(log_result))
  end
  vim.api.nvim_buf_create_user_command(bufid, "RunVisual", _14_, {nargs = "+", range = true})
  return nil
end
local function create_keymaps(bufid)
  local pattern = "\\v^# \\-+$"
  vim.keymap.set({"n", "v", "o"}, "[e", string.format("<Cmd>call search('%s', 'bw')<CR>", pattern), {buffer = bufid, silent = true, desc = "[RunVisual] Goto prev log entry"})
  vim.keymap.set({"n", "v", "o"}, "]e", string.format("<Cmd>call search('%s', 'w')<CR>", pattern), {buffer = bufid, silent = true, desc = "[RunVisual] Goto next log entry"})
  return nil
end
local function create_aucmds()
  local function _15_(_241)
    return create_user_cmds(_241.buf)
  end
  vim.api.nvim_create_autocmd("BufWinEnter", {desc = "[RunVisual] Create usercommand", callback = _15_})
  local function _16_(_241)
    return create_keymaps(_241.buf)
  end
  return vim.api.nvim_create_autocmd("FileType", {desc = "[RunVisual] Add keymaps for goto prev/next log entry", pattern = "RunVisual", callback = _16_})
end
local M = {}
M.setup = function(config)
  create_aucmds()
  return nil
end
return M
