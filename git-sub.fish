# ======================================== Header ========================================
function impl_mixin_deps
end
# ============================================================================================================



# ============================================================================================================
# Helpers

# Reset
set Color_Off '\033[0m'       # Text Reset
# Regular Colors
set Gray      '\033[0;90m'    # Gray
set Black     '\033[0;30m'    # Black
set Red       '\033[0;31m'    # Red
set Green     '\033[0;32m'    # Green
set Yellow    '\033[0;33m'    # Yellow
set Blue      '\033[0;34m'    # Blue
set Purple    '\033[0;35m'    # Purple
set Cyan      '\033[0;36m'    # Cyan
set White     '\033[0;37m'    # White
# Bold
set BGray     '\033[1;30m'
set BBlack    '\033[1;30m'    # Black
set BRed      '\033[1;31m'    # Red
set BGreen    '\033[1;32m'    # Green
set BYellow   '\033[1;33m'    # Yellow
set BBlue     '\033[1;34m'    # Blue
set BPurple   '\033[1;35m'    # Purple
set BCyan     '\033[1;36m'    # Cyan
set BWhite    '\033[1;37m'    # White
# Underline
set UBlack    '\033[4;30m'    # Black
set URed      '\033[4;31m'    # Red
set UGreen    '\033[4;32m'    # Green
set UYellow   '\033[4;33m'    # Yellow
set UBlue     '\033[4;34m'    # Blue
set UPurple   '\033[4;35m'    # Purple
set UCyan     '\033[4;36m'    # Cyan
set UWhite    '\033[4;37m'    # White

function awk_with_colours
   awk                          \
      -v Color_Off="$Color_Off" \
      -v Gray="$Gray"           \
      -v Black="$Black"         \
      -v Red="$Red"             \
      -v Green="$Green"         \
      -v Yellow="$Yellow"       \
      -v Blue="$Blue"           \
      -v Purple="$Purple"       \
      -v Cyan="$Cyan"           \
      -v White="$White"         \
      -v BBlack="$BBlack"       \
      -v BRed="$BRed"           \
      -v BGreen="$BGreen"       \
      -v BYellow="$BYellow"     \
      -v BBlue="$BBlue"         \
      -v BPurple="$BPurple"     \
      -v BCyan="$BCyan"         \
      -v BWhite="$BWhite"       \
      -v UBlack="$UBlack"       \
      -v URed="$URed"           \
      -v UGreen="$UGreen"       \
      -v UYellow="$UYellow"     \
      -v UBlue="$UBlue"         \
      -v UPurple="$UPurple"     \
      -v UCyan="$UCyan"         \
      -v UWhite="$UWhite"       \
      $argv
end

function impl_git::MaybeRun
   echo -e (set_color brblack)"cd "(pwd)"; "(string join -- " " (string escape -- $argv))(set_color normal) 1>&2
   if test -n "$GIT_SUB_DRY_RUN"
      return
   end
   $argv
end

function impl_git::get_root_repo_path
   set current_dir (pwd)

   while git -C $current_dir/.. rev-parse --is-inside-work-tree > /dev/null 2>&1
      set current_dir (realpath $current_dir/..)
   end
   echo $current_dir
end



# ============================================================================================================
# Post-order DFS traversal

function impl_git::exec_for_each_submodule_dfs_helper
   argparse --ignore-unknown "repo_path=" "indent=" "callback=" "root_repo=" -- $argv || return
   set gitmodules_file $_flag_repo_path/.gitmodules
   if not test -f $gitmodules_file
      return
   end

   # set fish_trace 1
   set -l label_path_pairs (git config --file $gitmodules_file --get-regexp path | string replace -r 'submodule\.(.*)\.path (.*)' '$1 $2')
   for pair in $label_path_pairs
      set -l label_path     (string split " " -- $pair)
      set -l label          $label_path[1]
      set -l path_in_parent $label_path[2]
      set -l branch         (git config --file $gitmodules_file submodule.$label.branch)

      impl_git::exec_for_each_submodule_dfs_helper --repo_path $_flag_repo_path/$path_in_parent \
                                                   --indent   "$_flag_indent     "              \
                                                   --callback  $_flag_callback                  \
                                                   --root_repo $_flag_root_repo                 \
                                                   $argv

      # Post order
      # echo "$_flag_indent Parent repo: $_flag_repo_path: label: $label, path_in_parent: $path_in_parent" >> /dev/stderr
      pushd $_flag_repo_path/$path_in_parent
      $_flag_callback --parent_repo $_flag_repo_path  \
                --submod_label      $label            \
                --submod_rel_path   $path_in_parent   \
                 --branch          "$branch"          \
                 --indent          "$_flag_indent"    \
                 --root_repo        $_flag_root_repo  \
                  $argv
      popd
   end
end

function impl_git::exec_for_each_submodule
   argparse --ignore-unknown "repo_path=" "indent=" "callback=" -- $argv || return
   impl_git::exec_for_each_submodule_dfs_helper --repo_path $_flag_repo_path  \
                                                --indent "$_flag_indent     " \
                                                --callback $_flag_callback    \
                                                --root_repo $_flag_repo_path  \
                                                $argv
   pushd $_flag_repo_path
   $_flag_callback --parent_repo $_flag_repo_path                              \
                                 --submod_label    ""                          \
                                 --submod_rel_path "."                         \
                                 --branch          (git branch --show-current) \
                                 --indent          ""                          \
                                 --root_repo       $_flag_repo_path            \
                                 $argv
   popd
end



# ============================================================================================================
# Debug / printing

function impl_git::submodule_callback::print --argument-names parent_repo_path label path branch indent
   argparse --ignore-unknown "parent_repo=" "submod_label=" "submod_rel_path=" "branch=" "indent=" "root_repo=" -- $argv || return
   # echo $indent"Parent repo: $parent_repo_path: label: $label, path: $path"
end
function impl_git::print_for_each_submodule
   impl_git::exec_for_each_submodule --repo_path (impl_git::get_root_repo_path)     \
                                     --indent ""                                    \
                                     --callback impl_git::submodule_callback::print
end



# ============================================================================================================
# Git status

function impl_git::submodule_callback::status
   argparse --ignore-unknown "parent_repo=" "submod_label=" "submod_rel_path=" "branch=" "indent=" "root_repo=" -- $argv || return
   set submod_path_rel_root (realpath --relative-to=$_flag_root_repo $_flag_parent_repo/$_flag_submod_rel_path)
   # Support below the format of git status: https://git-scm.com/docs/git-status#_short_format
   git status --porcelain --ignore-submodules=all | awk_with_colours                                                        \
      -v header=$_flag_indent""(set_color -o bryellow)"$submod_path_rel_root"(set_color normal)                             \
      -v submod_path_rel_root="$submod_path_rel_root"                                                                       \
      -v indent=$_flag_indent"   "                                                              '                           \
      BEGIN {                                                                                                               \
      }                                                                                                                     \
      {                                                                                                                     \
         if(NR == 1) print header;                                                                                          \
         first_char = substr($0, 1, 1);                                                                                     \
         if(first_char ~ /^[MADRT]$/) {                                                                                     \
            action = (first_char == "M" ? "modified" : (first_char == "A" ? "added" : "other"));                            \
            staged[action, $2];                                                                                             \
         }                                                                                                                  \
         second_char = substr($0, 2, 1);                                                                                    \
         if(second_char ~ /^[MTD]$/) {                                                                                      \
            action = "modified";                                                                                            \
            unstaged[action, $NF];                                                                                          \
         }                                                                                                                  \
         if($1 == "??") {                                                                                                   \
            untracked[$2];                                                                                                  \
         }                                                                                                                  \
      }                                                                                                                     \
      END {                                                                                                                 \
         above_printed = 0;                                                                                                 \
         if(length(staged)) {                                                                                               \
             if(above_printed) printf "\n";                                                                                 \
             print indent "Changes to be committed:";                                                                       \
             above_printed = 1;                                                                                             \
             for(status_file_pair in staged) {                                                                              \
               split(status_file_pair, status_file, SUBSEP);                                                                \
               print indent "   " Green status_file[1]":   " Gray submod_path_rel_root "/" BGreen status_file[2] Color_Off; \
             }                                                                                                              \
         }                                                                                                                  \
         if (length(unstaged)) {                                                                                            \
            if(above_printed) printf "\n";                                                                                  \
            print indent "Changes not staged for commit:";                                                                  \
            above_printed = 1;                                                                                              \
            for(status_file_pair in unstaged) {                                                                             \
               split(status_file_pair, status_file, SUBSEP);                                                                \
               print indent "   " Red status_file[1]":   " Gray submod_path_rel_root "/" BRed status_file[2] Color_Off;     \
            }                                                                                                               \
         }                                                                                                                  \
         if (length(untracked)) {                                                                                           \
            if(above_printed) printf "\n";                                                                                  \
            print indent "Untracked files:";                                                                                \
            above_printed = 1;                                                                                              \
            for(file in untracked) print indent "   " Gray submod_path_rel_root "/" Red file Color_Off;                     \
         }                                                                                                                  \
         if(NR >= 1) print "\n";                                                                                            \
      }                                                                                                                     \
   '
end
function impl_git::status_for_each_submodule
   impl_git::exec_for_each_submodule --repo_path (impl_git::get_root_repo_path)       \
                                     --indent ""                                      \
                                     --callback impl_git::submodule_callback::status
end




# ============================================================================================================
# Git add

function impl_git::add_file --argument-names full_path
   set current_dir (realpath (dirname $full_path))

   while not test -f "$current_dir/.git" -o -d "$current_dir/.git" -o "$current_dir" != "/"
      set current_dir (dirname $current_dir)
   end
   if test "$current_dir" = "/"
      echo "Failed to find git repo for $full_path" >> /dev/stderr
      return
   end
   set relative_path (realpath --relative-to=$current_dir $full_path)
   pushd $current_dir
   impl_git::MaybeRun git add $relative_path
   # echo "File $relative_path added in submodule $current_dir" >> /dev/stderr
   popd
end
function impl_git::add_files
   for full_path in $argv
      impl_git::add_file $full_path
   end
end



# ============================================================================================================
# Git commit

function impl_git::submodule_callback::commmit
   argparse --ignore-unknown "parent_repo=" "submod_label=" "submod_rel_path=" "branch=" "indent=" "root_repo=" -- $argv || return
   set submod_path_rel_root (realpath --relative-to=$_flag_root_repo $_flag_parent_repo/$_flag_submod_rel_path)

   # Since we are using post-order DSF, at this point we know that all our children (submodules) have new commits.
   # Let's extract them here and git-add them to what will be commited:

   # See this https://www.git-scm.com/docs/git-diff-index#_raw_output_format for the format of git diff-index HEAD

   # 160000: is a gitlink: https://stackoverflow.com/questions/54596206/what-are-the-possible-modes-for-entries-in-a-git-tree-object
   #                       https://stackoverflow.com/questions/737673/how-to-read-the-mode-field-of-git-ls-trees-output
   # Extract dst (new) hash and relative path of submodule of this (sub-)module:
   # Example: For this input:
   # :160000 160000 e8a82dc7ede61c4...8bb e8a82dc7ede61c4...8bb M      third_party/googletest
   # we will extract "e8a82dc7ede61c4...8bb third_party/googletest"
   set -l hash_path_pairs (git diff-index HEAD | rg '^:160000 160000 .{40} (.{40}) M\t(.*)' -or '$1 $2')
   set -l zero_hash "0000000000000000000000000000000000000000" # when a submodule has new commits, its dst hash is all zeros
   for hash_path_pair in $hash_path_pairs
      # echo $hash_path_pair >> /dev/stderr
      set -l hash (string split " " -- $hash_path_pair)[1]
      set -l child_rel_path (string split " " -- $hash_path_pair)[2]
      # echo "Hash: '$hash'" >> /dev/stderr
      # echo "child_rel_path: '$child_rel_path'" >> /dev/stderr
      if test "$hash" != "$zero_hash"
         continue
      end
      impl_git::MaybeRun git add $child_rel_path
   end

   # Finally, check if there is anything in the staging area and commit:
   # (see help for --quiet option https://www.git-scm.com/docs/git-diff-index#Documentation/git-diff-index.txt---quiet)
   if not git diff-index --quiet --exit-code --cached HEAD
      impl_git::MaybeRun git commit $argv
   end
end

function impl_git::git_commit
   impl_git::exec_for_each_submodule --repo_path (impl_git::get_root_repo_path)       \
                                     --indent ""                                      \
                                     --callback impl_git::submodule_callback::commmit \
                                     $argv
end



# ============================================================================================================
# Git diff


function impl_git::git_diff --argument-names submod_path
   pushd $submod_path
   git diff $argv[2..]
   popd
end



# ============================================================================================================
# Git log

function impl_git::git_log --argument-names submod_path
   pushd $submod_path
   git log $argv[2..]
   popd
end



# ============================================================================================================
# Git restore

function impl_git::restore_file
   argparse --ignore-unknown "staged" "full_path=" -- $argv || return
   set current_dir (realpath (dirname $_flag_full_path))

   while not test -f "$current_dir/.git" -o -d "$current_dir/.git" -o "$current_dir" != "/"
      set current_dir (dirname $current_dir)
   end
   if test "$current_dir" = "/"
      echo "Failed to find git repo for $_flag_full_path" >> /dev/stderr
      return
   end
   set relative_path (realpath --relative-to=$current_dir $_flag_full_path)
   pushd $current_dir
   impl_git::MaybeRun git restore $_flag_staged $relative_path
   # echo "File $relative_path added in submodule $current_dir" >> /dev/stderr
   popd
end

function impl_git::git_restore
   argparse --ignore-unknown "staged" -- $argv || return
   for full_path in $argv
      impl_git::restore_file $_flag_staged --full_path $full_path
   end
end