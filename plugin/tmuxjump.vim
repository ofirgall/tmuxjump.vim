if get(g:, 'tmuxjump_loaded')
    finish
endif

let g:scripts_dir = expand('<sfile>:h:h').'/scripts/'
let g:script_path= g:scripts_dir . 'capture.sh'

function! tmuxjump#jump_to_file(fileWithPos) abort
  let l:list = split(a:fileWithPos,':')
  let l:file_name = l:list[0]
  if !filereadable(l:file_name)
      return
  endif
  execute 'e ' . l:file_name
  if len(l:list) == 2
    norm l:list[1]
  elseif len(l:list) == 3
    execute "norm " . l:list[1] . "G" . l:list[2] . "|"
  endif
endfunction

function tmuxjump#grep_tmux(pattern) abort
  let l:is_in_tmux = has_key(environ(), 'TMUX')
  if !l:is_in_tmux
    echohl WarningMsg
    echo "TmuxJump.vim: Not in tmux session"
    echohl None
    return []
  endif

  let l:script_path = get(g:, 'tmuxjump_custom_capture', g:script_path)
  let l:capturedFiles = system('bash '. l:script_path . ' '. a:pattern)
  if l:capturedFiles == ""
    echohl WarningMsg
    echo "TmuxJump.vim: Found no file paths"
    echohl None
    return []
  endif

  let l:list = uniq(reverse(split(l:capturedFiles, '\n')))
  return l:list
endfunction

function! tmuxjump#capture_and_jump(pattern, bang) abort
  let l:list = tmuxjump#grep_tmux(a:pattern)
  if len(l:list) == 0
      return 
  endif
  call tmuxjump#jump_to_file(l:list[0])
endfunction

function! tmuxjump#open_telescope(list) abort
lua << EOF
local pickers = require "telescope.pickers"
local finders = require "telescope.finders"
local conf = require("telescope.config").values
pickers.new({}, {
  prompt_title = "TmuxJump",
  finder = finders.new_table {
    results = vim.api.nvim_eval('a:list')
  },
  sorter = conf.generic_sorter(opts),
}):find()
EOF
endfunction

function! tmuxjump#capture_and_list_file(pattern, bang) abort
  let l:list = tmuxjump#grep_tmux(a:pattern)
  if len(l:list) == 0
      return
  endif
  if get(g:, 'tmuxjump_telescope')
    call tmuxjump#open_telescope(l:list)
  else
    call tmuxjump#open_fzf(l:list)
  endif
endfunction

function tmuxjump#open_fzf(list) abort
  let l:name = 'Sibling pane files'
  let l:prompt = 'TmuxJump> '
  let l:action = ''
  let l:valid_keys = ['enter']
  let l:fzf_options = [
        \ '--no-multi',
        \ '--prompt', l:prompt,
        \ '--nth', '1',
        \ '--no-sort',
        \]
  call fzf#run(fzf#wrap(
        \ {
        \   'source': a:list,
        \   'sink': { module -> tmuxjump#jump_to_file( module) },
        \   'options': l:fzf_options,
        \ },
        \)) 
endfunction

command! -bang -nargs=* TmuxJumpFile call tmuxjump#capture_and_list_file(<q-args>,<bang>0)
command! -bang -nargs=* TmuxJumpFirst call tmuxjump#capture_and_jump(<q-args>,<bang>0)

let g:tmuxjump_loaded = v:true
