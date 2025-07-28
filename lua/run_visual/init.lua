-- [nfnl] fnl/run_visual/init.fnl
local function get_selection_text()
  vim.cmd("normal! gv\"xy")
  return vim.fn.trim(vim.fn.getreg("x"))
end
local function write_selection_text_to_tmp_file()
  local selection_text = get_selection_text()
  local tmp_file = (vim.fs.dirname(os.tmpname()) .. "/nvim_run_visual_tmp")
  vim.fn.writefile(vim.split(selection_text, "\n"), tmp_file)
  if vim.fn.has("unix") then
    os.execute(("chmod 777 " .. tmp_file))
  else
  end
  return tmp_file
end
local state = {bufid = nil, winid = nil, task_list = {}}
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
local function buffer_clear()
  return vim.api.nvim_buf_set_text(state.bufid, 0, 0, -1, -1, {})
end
local function buffer_append(lines)
  local bufid = state["bufid"]
  local winid = state["winid"]
  local line_start = vim.api.nvim_buf_line_count(bufid)
  if (1 == line_start) then
    line_start = 0
  else
  end
  vim.api.nvim_buf_set_lines(bufid, line_start, -1, false, lines)
  vim.api.nvim_win_set_cursor(winid, {vim.api.nvim_buf_line_count(bufid), 0})
  return nil
end
local function title_lines(cmd, start_time)
  local time_str = os.date("!%m-%d %H:%M:%S", start_time)
  return {("# " .. string.rep("-", 80)), ("# " .. time_str .. " - " .. table.concat(cmd, " "))}
end
local function result_lines(elapsed, _5_)
  local code = _5_["code"]
  local stdout = _5_["stdout"]
  local stderr = _5_["stderr"]
  local status_text
  if (code == 0) then
    status_text = ("# \240\159\142\137 Good job" .. " (" .. elapsed .. "s) ")
  elseif (nil ~= code) then
    local code0 = code
    status_text = ("# \240\159\146\128 Code: " .. code0 .. " (" .. elapsed .. "s) ")
  else
    status_text = nil
  end
  local text
  if (code == 0) then
    text = stdout
  elseif (nil ~= code) then
    local code0 = code
    if (stderr ~= "") then
      text = stderr
    else
      text = stdout
    end
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
  return vim.list_extend({status_text}, vim.fn.split(vim.fn.trim(_11_()), "\n", true))
end
local function log_task(_13_)
  local cmd = _13_["cmd"]
  local result = _13_["result"]
  local start_time = _13_["start_time"]
  local finish_time = _13_["finish_time"]
  buffer_append(title_lines(cmd, start_time))
  if (nil == result) then
    buffer_append({"\226\143\179 running..."})
  else
    buffer_append(result_lines((finish_time - start_time), result))
  end
  return nil
end
local function log_task_list()
  local task_list = state["task_list"]
  buffer_clear()
  for _, task in ipairs(task_list) do
    log_task(task)
  end
  return nil
end
local function on_state_changed()
  ensure_buf_and_win()
  log_task_list()
  return nil
end
local function add_task(task)
  table.insert(state.task_list, task)
  return on_state_changed()
end
local function update_task_result(task, res)
  task.result = res
  task.finish_time = os.time()
  return on_state_changed()
end
local function run_visual(_15_)
  local fargs = _15_["fargs"]
  local tmp_file = write_selection_text_to_tmp_file()
  local cmd = {unpack(fargs), tmp_file}
  local task = {cmd = cmd, start_time = os.time()}
  add_task(task)
  local function on_exit(obj)
    return update_task_result(task, obj)
  end
  local ok_3f, res = pcall(vim.system, cmd, {text = true}, vim.schedule_wrap(on_exit))
  if ok_3f then
    task.process = res
    return nil
  else
    return update_task_result(task, {code = 999, stderr = res, stdout = ""})
  end
end
local function create_user_cmds(bufid)
  vim.api.nvim_buf_create_user_command(bufid, "RunVisual", run_visual, {nargs = "+", range = true})
  return nil
end
local function create_keymaps(bufid)
  local pattern = "\\v^# \\-+$"
  vim.keymap.set({"n", "v", "o"}, "[e", string.format("<Cmd>call search('%s', 'bw')<CR>", pattern), {buffer = bufid, silent = true, desc = "[RunVisual] Goto prev log entry"})
  vim.keymap.set({"n", "v", "o"}, "]e", string.format("<Cmd>call search('%s', 'w')<CR>", pattern), {buffer = bufid, silent = true, desc = "[RunVisual] Goto next log entry"})
  return nil
end
local function create_aucmds()
  local function _17_(_241)
    return create_user_cmds(_241.buf)
  end
  vim.api.nvim_create_autocmd("BufWinEnter", {desc = "[RunVisual] Create usercommand", callback = _17_})
  local function _18_(_241)
    return create_keymaps(_241.buf)
  end
  return vim.api.nvim_create_autocmd("FileType", {desc = "[RunVisual] Add keymaps for goto prev/next log entry", pattern = "RunVisual", callback = _18_})
end
local M = {}
M.setup = function(config)
  create_aucmds()
  return nil
end
return M
