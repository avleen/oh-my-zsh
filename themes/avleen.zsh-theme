# vim:ft=zsh ts=2 sw=2 sts=2
#
# agnoster's Theme - https://gist.github.com/3712874
# A Powerline-inspired theme for ZSH
#
# # README
#
# In order for this theme to render correctly, you will need a
# [Powerline-patched font](https://github.com/Lokaltog/powerline-fonts).
#
# In addition, I recommend the
# [Solarized theme](https://github.com/altercation/solarized/) and, if you're
# using it on Mac OS X, [iTerm 2](http://www.iterm2.com/) over Terminal.app -
# it has significantly better color fidelity.
#
# # Goals
#
# The aim of this theme is to only show you *relevant* information. Like most
# prompts, it will only show git information when in a git working directory.
# However, it goes a step further: everything from the current user and
# hostname to whether the last call exited with an error to whether background
# jobs are running in this shell will all be displayed automatically when
# appropriate.

### Segment drawing
# A few utility functions to make it easy and re-usable to draw segmented prompts

CURRENT_BG='NONE'

# Fix odd char on mac
if [[ `uname` == 'Darwin' ]]; then
    SEGMENT_SEPARATOR='\ue0b0'
else
    SEGMENT_SEPARATOR=''
fi

# Begin a segment
# Takes two arguments, background and foreground. Both can be omitted,
# rendering default background/foreground.
prompt_segment() {
  local bg fg
  [[ -n $1 ]] && bg="%K{$1}" || bg="%k"
  [[ -n $2 ]] && fg="%F{$2}" || fg="%f"
  if [[ $CURRENT_BG != 'NONE' && $1 != $CURRENT_BG ]]; then
    echo -n " %{$bg%F{$CURRENT_BG}%}$SEGMENT_SEPARATOR%{$fg%} "
  else
    echo -n "%{$bg%}%{$fg%} "
  fi
  CURRENT_BG=$1
  [[ -n $3 ]] && echo -n $3
}

# End the prompt, closing any open segments
prompt_end() {
  if [[ -n $CURRENT_BG ]]; then
    echo -n " %{%k%F{$CURRENT_BG}%}$SEGMENT_SEPARATOR"
  else
    echo -n "%{%k%}"
  fi
  echo -n "%{%f%}"
  CURRENT_BG=''
}

### Prompt components
# Each component will draw itself, and hide itself if no information needs to be shown

# Context: user@hostname (who am I and where am I)
prompt_context() {
  if [[ "$USER" != "$DEFAULT_USER" || -n "$SSH_CLIENT" ]]; then
    if [[ "$HOSTNAME" =~ ".vm.|.doop." ]]; then
      prompt_segment black default "%(!.%{%F{yellow}%}.)$USER@%3m"
    else
      prompt_segment black default "%(!.%{%F{yellow}%}.)$USER@%2m"
    fi
  fi
}

# Git: branch/detached head, dirty status
prompt_git() {
  local ref dirty mode repo_path
  repo_path=$(git rev-parse --git-dir 2>/dev/null)

  if $(git rev-parse --is-inside-work-tree >/dev/null 2>&1); then
    dirty=$(parse_git_dirty)
    ref=$(git symbolic-ref HEAD 2> /dev/null) || ref="➦ $(git show-ref --head -s --abbrev |head -n1 2> /dev/null)"
    if [[ -n $dirty ]]; then
      prompt_segment yellow black
    else
      prompt_segment green black
    fi

    if [[ -e "${repo_path}/BISECT_LOG" ]]; then
      mode=" <B>"
    elif [[ -e "${repo_path}/MERGE_HEAD" ]]; then
      mode=" >M<"
    elif [[ -e "${repo_path}/rebase" || -e "${repo_path}/rebase-apply" || -e "${repo_path}/rebase-merge" || -e "${repo_path}/../.dotest" ]]; then
      mode=" >R>"
    fi

    setopt promptsubst
    autoload -Uz vcs_info

    zstyle ':vcs_info:*' enable git
    zstyle ':vcs_info:*' get-revision true
    zstyle ':vcs_info:*' check-for-changes true
    zstyle ':vcs_info:*' stagedstr '✚'
    zstyle ':vcs_info:git:*' unstagedstr '●'
    zstyle ':vcs_info:*' formats ' %u%c'
    zstyle ':vcs_info:*' actionformats ' %u%c'
    vcs_info
    echo -n "${ref/refs\/heads\// }${vcs_info_msg_0_%% }${mode}"
  fi
}

prompt_hg() {
  local rev status
  setopt promptsubst
  autoload -Uz vcs_info
  zstyle ':vcs_info:*' enable hg
  zstyle ':vcs_info:*' get-revision true
  zstyle ':vcs_info:hg*:*' get-bookmarks true
  zstyle ':vcs_info:*' check-for-changes true
  zstyle ':vcs_info:*' formats " %h@"
  zstyle ':vcs_info:*' actionformats " %h@"
  vcs_info
  if [[ -n ${vcs_info_msg_0_} ]]; then
    # Find the root
    this_dir=${PWD}
    while [[ ${this_dir} != '/' ]]; do
        if [[ -d ${this_dir}/.hg ]]; then
            hg_root=${this_dir}
            break
        else
            this_dir=$( dirname ${this_dir} )
        fi
    done
    if [[ ! -f /tmp/zsh_hg_st.$$ || ${hg_root}/.hg/fsmonitor.state -nt /tmp/zsh_hg_st.$$ ]]; then
      hg st > /tmp/zsh_hg_st.$$ 2>/dev/null &
      hg id -n -b > /tmp/zsh_hg_id.$$ 2>/dev/null &
      wait
      # running `hg st` or `hg id` causes the fsmonitor.state file to get
      # updated. We touch our own state files to make sure they're seen as newer
      # on the next run.
      touch /tmp/zsh_hg_id.$$
      touch /tmp/zsh_hg_st.$$
    fi
    hg_st=$( cat /tmp/zsh_hg_st.$$ )
    hg_id=$( cat /tmp/zsh_hg_id.$$ )
    if [[ -e ${hg_root}/.hg/bookmarks.current ]]; then
      hg_bookmark=$( cat ${hg_root}/.hg/bookmarks.current )
    else
      hg_bookmark='none'
    fi
    rev=$( echo ${hg_id} | cut -f1 -d" " | sed 's/[^-0-9]//g')
    #branch=$( echo ${hg_id} | cut -f2 -d" " )
    st=""
    if $( echo ${hg_st} | grep -q "^\?" ); then
      prompt_segment red black
      st='±'
    elif $( echo ${hg_st} | grep -q "^[MA]" ); then
      prompt_segment yellow black
      st='±'
    else
      prompt_segment green black
    fi
    echo -n "☿ $rev@$hg_bookmark" $st
  fi

  # hg_id=$(hg id -n -b 2>/dev/null)
  # if [ $? -eq 0 ]; then
  #   if $(hg prompt >/dev/null 2>&1); then
  #     if [[ $(hg prompt "{status|unknown}") = "?" ]]; then
  #       # if files are not added
  #       prompt_segment red white
  #       st='±'
  #     elif [[ -n $(hg prompt "{status|modified}") ]]; then
  #       # if any modification
  #       prompt_segment yellow black
  #       st='±'
  #     else
  #       # if working copy is clean
  #       prompt_segment green black
  #     fi
  #     echo -n $(hg prompt "☿ {rev}@{branch}") $st
  #   else
  #     st=""
  #     rev=$( echo ${hg_id} | cut -f1 -d" " | sed 's/[^-0-9]//g')
  #     branch=$( echo ${hg_id} | cut -f2 -d" " )
  #     hg_st=$(hg st)
  #     if $( echo ${hg_st} | grep -q "^\?" ); then
  #       prompt_segment red black
  #       st='±'
  #     elif $( echo ${hg_st} | grep -q "^[MA]" ); then
  #       prompt_segment yellow black
  #       st='±'
  #     else
  #       prompt_segment green black
  #     fi
  #     echo -n "☿ $rev@$branch" $st
  #   fi
  # fi
}

# Dir: current working directory
prompt_dir() {
  prompt_segment blue black '%~'
}

# Virtualenv: current working virtualenv
prompt_virtualenv() {
  local virtualenv_path="$VIRTUAL_ENV"
  if [[ -n $virtualenv_path && -n $VIRTUAL_ENV_DISABLE_PROMPT ]]; then
    prompt_segment blue black "(`basename $virtualenv_path`)"
  fi
}

# Status:
# - was there an error
# - am I root
# - are there background jobs?
prompt_status() {
  local symbols
  symbols=()
  [[ $RETVAL -ne 0 ]] && symbols+="%{%F{red}%}✘"
  [[ $UID -eq 0 ]] && symbols+="%{%F{yellow}%}⚡"
  [[ $(jobs -l | wc -l) -gt 0 ]] && symbols+="%{%F{cyan}%}⚙"

  [[ -n "$symbols" ]] && prompt_segment black default "$symbols"
}

prompt_time() {
  prompt_segment black magenta '%*'
}

## Main prompt
build_prompt() {
  RETVAL=$?
  prompt_time
  prompt_status
  prompt_virtualenv
  prompt_context
  prompt_dir
  prompt_git
  prompt_hg
  prompt_end
}

PROMPT='%{%f%b%k%}$(build_prompt) '
