function __wallust_prompt_color -a variable fallback
    if set -q $variable[1]
        echo $$variable[1]
    else
        echo $fallback
    end
end

function __wallust_powerline_segment -a bg fg text next_bg
    set_color -b $bg $fg
    echo -n " $text "

    if test -n "$next_bg"
        set_color -b $next_bg $bg
    else
        set_color normal
        set_color $bg
    end

    echo -n ""
    set_color normal
end

function __wallust_git_segment
    command git rev-parse --is-inside-work-tree >/dev/null 2>&1
    or return

    set -l branch (command git branch --show-current 2>/dev/null)
    if test -z "$branch"
        set branch (command git rev-parse --short HEAD 2>/dev/null)
    end

    set -l state
    command git diff --quiet --ignore-submodules -- 2>/dev/null
    or set state " ±"

    command git diff --cached --quiet --ignore-submodules -- 2>/dev/null
    or set state " ±"

    echo "$branch$state"
end

function fish_prompt
    set -l last_status $status

    set -l bg_dark (__wallust_prompt_color pure_color_dark 40383D)
    set -l fg_light (__wallust_prompt_color pure_color_light E3D5BF)
    set -l fg_normal (__wallust_prompt_color pure_color_normal F1E8D8)
    set -l primary (__wallust_prompt_color pure_color_primary 8587A3)
    set -l info (__wallust_prompt_color pure_color_info D8BC8F)
    set -l success (__wallust_prompt_color pure_color_success 7D4734)
    set -l warning (__wallust_prompt_color pure_color_warning 9C307F)
    set -l danger (__wallust_prompt_color pure_color_danger 280320)

    set -l user_bg $primary
    set -l cwd_bg $info
    set -l git_bg $success
    set -l status_bg $danger
    set -l jobs_bg $warning

    if fish_is_root_user
        set user_bg $danger
    end

    set -l segments user cwd
    set -l user_text "$USER@"(prompt_hostname)
    set -l cwd_text (prompt_pwd)
    set -l git_text (__wallust_git_segment)
    set -l status_text
    set -l jobs_text

    if test -n "$git_text"
        set -a segments git
    end

    if test $last_status -ne 0
        set status_text "x $last_status"
        set -a segments status
    end

    if test (jobs -p | count) -gt 0
        set jobs_text (jobs -p | count)" job"
        set -a segments jobs
    end

    for index in (seq (count $segments))
        set -l segment $segments[$index]
        set -l next_segment $segments[(math $index + 1)]
        set -l next_bg

        switch $next_segment
            case cwd
                set next_bg $cwd_bg
            case git
                set next_bg $git_bg
            case status
                set next_bg $status_bg
            case jobs
                set next_bg $jobs_bg
        end

        switch $segment
            case user
                __wallust_powerline_segment $user_bg $bg_dark $user_text $next_bg
            case cwd
                __wallust_powerline_segment $cwd_bg $bg_dark $cwd_text $next_bg
            case git
                __wallust_powerline_segment $git_bg $bg_dark $git_text $next_bg
            case status
                __wallust_powerline_segment $status_bg $fg_light $status_text $next_bg
            case jobs
                __wallust_powerline_segment $jobs_bg $bg_dark $jobs_text $next_bg
        end
    end

    echo
    set_color $primary
    echo -n '$ '
    set_color normal
end
