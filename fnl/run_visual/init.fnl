(fn get_selection_text []
  (vim.cmd "normal! gv\"xy")
  (vim.fn.trim (vim.fn.getreg "x")))

(fn write_selection_text_to_tmp_file []
  "Read selection text and write to temp file"
  ;; read selection_text
  (local selection_text (get_selection_text))
  ;; create tmp_file
  (local tmp_file
         (-> (os.tmpname) (vim.fs.dirname) (.. "/nvim_run_visual_tmp")))
  ;; write selection text to tmp_file
  (-> selection_text (vim.split "\n") (vim.fn.writefile tmp_file))
  ;; ensure tmp_file accessible
  (when (vim.fn.has :unix)
    (os.execute (.. "chmod 777 " tmp_file)))
  tmp_file)

;; === Task Spec ===
;; {: cmd : result : process : start_time : finish_time}

(local state {:bufid nil :winid nil :task_list []})

(fn ensure_buf_and_win []
  (var {: bufid : winid} state)
  ;; create buffer if not exists
  (when (not (and bufid (= 1 (vim.fn.bufexists bufid))))
    (set bufid (vim.api.nvim_create_buf false true))
    (tset vim.bo bufid :filetype :RunVisual))
  ;; create window if not exists
  (when (not (and winid (vim.api.nvim_win_is_valid winid)))
    (set winid
         (vim.api.nvim_open_win bufid false {:split "below" :style :minimal})))
  (set state.bufid bufid)
  (set state.winid winid)
  nil)

(fn buffer_clear []
  (vim.api.nvim_buf_set_text state.bufid 0 0 -1 -1 []))

(fn buffer_append [lines]
  (local {: bufid : winid} state)
  (var line_start (vim.api.nvim_buf_line_count bufid))
  (when (= 1 line_start) (set line_start 0))
  (vim.api.nvim_buf_set_lines bufid line_start -1 false lines)
  (vim.api.nvim_win_set_cursor winid [(vim.api.nvim_buf_line_count bufid) 0])
  nil)

(fn title_lines [cmd start_time]
  (local time_str (os.date "!%m-%d %H:%M:%S" start_time))
  [(.. "# " (string.rep "-" 80))
   (.. "# " time_str " - " (table.concat cmd " "))])

(fn result_lines [elapsed {: code : stdout : stderr}]
  (local status_text
         (case code
           0 (.. "# 🎉 Good job" " (" elapsed "s) ")
           code (.. "# 💀 Code: " code " (" elapsed "s) ")))
  (local text (case code
                0 stdout
                code (if (not= stderr "") stderr stdout)))
  (vim.list_extend [status_text]
                   (-> text
                       (string.gsub "\027%[.-m" "")
                       (case (a _) a)
                       vim.fn.trim
                       (vim.fn.split "\n" true))))

(fn log_task [{: cmd : result : start_time : finish_time}]
  (buffer_append (title_lines cmd start_time))
  (if (= nil result)
      (buffer_append ["⏳ running..."])
      (buffer_append (result_lines (- finish_time start_time) result)))
  nil)

(fn log_task_list []
  (local {: task_list} state)
  (buffer_clear)
  (each [_ task (ipairs task_list)]
    (log_task task)))

(fn on_state_changed []
  (ensure_buf_and_win)
  (log_task_list)
  nil)

(fn add_task [task]
  (table.insert state.task_list task)
  (on_state_changed))

(fn update_task_result [task res]
  (set task.result res)
  (set task.finish_time (os.time))
  (on_state_changed))

(fn run_visual [{: fargs}]
  (local tmp_file (write_selection_text_to_tmp_file))
  (local cmd [(unpack fargs) tmp_file])
  (local task {:cmd cmd :start_time (os.time)})
  (add_task task)

  (fn on_exit [obj]
    (update_task_result task obj))

  (local (ok? res) (pcall vim.system cmd {:text true}
                          (vim.schedule_wrap on_exit)))
  (if ok?
      (set task.process res)
      (update_task_result task {:code 999 :stderr res :stdout ""})))

(fn create_user_cmds [bufid]
  (vim.api.nvim_buf_create_user_command bufid :RunVisual run_visual
                                        {:nargs "+" :range true})
  nil)

(fn create_keymaps [bufid]
  (local pattern "\\v^# \\-+$")
  (vim.keymap.set [:n :v :o] "[e"
                  (string.format "<Cmd>call search('%s', 'bw')<CR>" pattern)
                  {:buffer bufid
                   :silent true
                   :desc "[RunVisual] Goto prev log entry"})
  (vim.keymap.set [:n :v :o] "]e"
                  (string.format "<Cmd>call search('%s', 'w')<CR>" pattern)
                  {:buffer bufid
                   :silent true
                   :desc "[RunVisual] Goto next log entry"})
  nil)

(fn create_aucmds []
  (vim.api.nvim_create_autocmd :BufWinEnter
                               {:desc "[RunVisual] Create usercommand"
                                :callback #(create_user_cmds $.buf)})
  (vim.api.nvim_create_autocmd :FileType
                               {:desc "[RunVisual] Add keymaps for goto prev/next log entry"
                                :pattern :RunVisual
                                :callback #(create_keymaps $.buf)}))

(local M {})

(fn M.setup [config]
  (create_aucmds)
  nil)

M
