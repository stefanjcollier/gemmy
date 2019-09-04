# Description:
#   Determine if the current local dependency chain is compatible
#   Checks: <current repo> -> dressipi_partner_api -> ff_api 
# Usage:
#   # go to the relevant repo e.g. pantheon2
#   ./gemmy.sh
# Requires
#     # GNU date (aliased to gdate)
#     # GNU find (aliased to gfind)
# Setup
#   $ brew install coreutils # gdate
#   $ brew install findutils # gfind
#   # then get scripting!
# Exit Codes
#   0  - success
#   4x are all user errors
#    41 - Not in a repo
#   5x are all internal errors
#    51 - incorrect number of args written to gemmy debug file
#    52 - cannot find the repo dir
set -e

# cd to previously cd'ed dir without the output
function silent_cd_back() { cd -  1> /dev/null; }

function cd_repo() {
  repo_dir="${HOME}/Source/$1"
  if [ -e "$repo_dir" ]; then
    cd "$repo_dir"
  else
    errecho "Cannot find repo dir for ~/Source/$1"
    exit 52
  fi
}

function datetimestamp() { gdate --utc --iso-8601=seconds;  }

RED='\033[0;31m'
BLUE='\033[0;36m'
NC='\033[0m'
function errecho() { echo -e "⚠️  ${RED}gemmy: $@${NC}" >&2; }
function debug() { if [[ -n $DEBUG ]] ; then echo -e "ℹ️  ${BLUE}$@${NC}" >&2 ; fi; }

# Get the branch of the given repo
function local_branch() {
  local repo_name=$1
  cd_repo "$repo_name"
  # TODO handle repo is not cloned locally
  local branch_name=$(git rev-parse --abbrev-ref HEAD)
  debug "[local_branch($1)] branch_name = $branch_name"

  silent_cd_back
  echo "$branch_name"
}

function find_repo_line { 
  local repo_name=$1
  local parent_repo_name=$2
  cd_repo "$parent_repo_name"
  line=$(grep "gem '${repo_name}'" Gemfile)
  debug "[find_repo_line($1, $2)] line = $line"
  silent_cd_back
  echo "$line"
}

function needed_by_parent() {
  (find_repo_line $@ 1> /dev/null) && return 0 || return 1
}

# Find the branch desired in the gemfile
function gemfile_branch() {
  local repo_name=$1
  local parent_repo_name=$2

  function extract_branch { grep -o "branch.*" |  cut -d ' ' -f 2; }
  function remove_formatting { sed 's/[:" ]//g'; }
  line=$(find_repo_line "$repo_name" "$parent_repo_name")
  echo "$line" | extract_branch | remove_formatting
}

function use_local_repo() {
  local repo_name=$1
  bundle config | grep "local.$repo_name"
}

PREFIX=".gemmy"
FILE="${PREFIX}_$(datetimestamp).csv"
SETUP=
function setup_file() {
  if [ ! $SETUP ]; then
    function find_other_gemmies() { find . -name "$PREFIX*" ! -name $FILE;  }
    find_other_gemmies | xargs rm 
    touch "$FILE"
    SETUP='done'
    csv_header
    debug "[setup_file] Setup done! (var = $SETUP) (file = $FILE)"
  fi
}

BAD_WRITE_EXIT_CODE=51
function writeline() {
  if [ $# -ne 7 ]; then
    errecho "Writeline missing an arg, $# out of 7 given"
    errecho "  args: $@"
    exit $BAD_WRITE_EXIT_CODE 
  fi
  local repo_name=$1
  local parent_name=$2
  local in_gemfile=$3
  local desired_branch=$4
  local using_local=$5
  local local_branch=$6
  local setup_correct=$7
  setup_file
  echo "$repo_name,$parent_name,$in_gemfile,$desired_branch,$using_local,$local_branch,$setup_correct" >> "$FILE"
}

function csv_header() {
  writeline "Requirement" "Parent" "in Gemfile?" "Desired branch" "using local?" "local_branch" "will work?"
}

function will_work() {
  local use_local_source=$1
  local in_gemfile=$2
  local active_branch=$3
  local desired_branch=$4
  if [[ $use_local_source == '❌' ]] || [[ $in_gemfile == '❌' ]]; then
    echo '✅'
    debug "[will_work($1, $2, $3, $4)] Early exit"
    return
  fi
  if [[ $active_branch == $desired_branch ]]; then
    echo '✅'
    debug "[will_work($1, $2, $3, $4)] Success"
  else
    debug "[will_work($1, $2, $3, $4)] Failure"
    echo '❌'
  fi
}

function dump_requirement() {
  local repo=$1
  local parent=$2
  local active_branch=$(local_branch "$repo")
  local use_local_source=$(if [[ -n $(use_local_repo "$repo") ]]; then echo '✅'; else echo '❌'; fi)

  local desired_branch=$(
    if needed_by_parent "$repo" "$parent"; then
      gemfile_branch "$repo" "$parent"
    else
      echo '❌'
    fi
  )
  will_work=$(will_work "$use_local_source" "$desired_branch" "$active_branch" "$desired_branch")
  writeline "$repo" "$parent" '✅' "$desired_branch" "$use_local_source" "$active_branch" "$will_work"
  debug "[dump_requirement($1, $2)] Done determining $repo usage for $parent"
}

PWD_IS_NOT_REPO_EXIT_CODE=41
function is_git_repo() {
  [ -d .git ] || git rev-parse --git-dir > /dev/null 2>&1
}

function current_repo_name() {
  if is_git_repo ; then
    basename $(pwd)

  else
    errecho 'The current directory is not a git repo'
    exit $PWD_IS_NOT_REPO_EXIT_CODE
  fi
}

curr_repo_name=$(current_repo_name)
dump_requirement ff_api dressipi_partner_api
dump_requirement dressipi_partner_api "$curr_repo_name"

column -t -s, "$FILE"
