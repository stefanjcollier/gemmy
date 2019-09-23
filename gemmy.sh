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

function required_in_gemfile() {
  if [[  -z $(find_repo_line $@) ]]; then return 1; else return 0; fi
}

# Find the branch desired in the gemfile
function gemfile_branch() {
  local repo_name=$1
  local parent_repo_name=$2

  function extract_branch { grep -o "branch.*" |  cut -d ' ' -f 2; }
  function remove_formatting { sed 's/[:" ]//g' | sed "s/'//g"; }
  line=$(find_repo_line "$repo_name" "$parent_repo_name")
  echo "$line" | extract_branch | remove_formatting
}

function use_local_repo() {
  local repo_name=$1
  if [[ -n $(bundle config | grep "local.$repo_name") ]]; then return 1; else return 0; fi
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
  if [[ -n $NO_WRITES ]]; then
    return
  fi
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
  echo "$repo_name,$parent_name,$in_gemfile,$desired_branch,$using_local,$local_branch,$setup_correct" >> "$FILE"
}

function csv_header() {
  writeline "Requirement" "Parent" "in Gemfile?" "Desired branch" "Use local source?" "Local branch" "Branches match?"
}

SOMETHING_WRONG_WITH_ANY_REPO=
function will_work() {
  local active_branch=$1
  local desired_branch=$2
  if [[ $active_branch == $desired_branch ]]; then
    echo '✅'
    debug "[will_work($1, $2)] Success"
  else
    debug "[will_work($1, $2)] Failure"
    echo '❌'
    SOMETHING_WRONG_WITH_ANY_REPO=1
  fi
}

function dump_requirement() {
  local repo=$1
  local parent=$2
  local active_branch=$(local_branch "$repo")

  if ! required_in_gemfile "$repo" "$parent"; then
    debug "[dump_requirement($1, $2)] Not needed :("
    writeline "$repo" "$parent" '❌' '💤' '💤' '💤' '✅'
    return
  fi
  debug "[dump_requirement($1, $2)] Needed!"

  local desired_branch=$(gemfile_branch "$repo" "$parent")

  if use_local_repo "$repo"; then
    debug "[dump_requirement($1, $2)] Not using local :("
    writeline "$repo" "$parent" '✅' "$desired_branch" '❌' '💤'  '✅'
    return
  fi
  debug "[dump_requirement($1, $2)] Using local code!"

  will_work=$(will_work "$active_branch" "$desired_branch")
  writeline "$repo" "$parent" '✅' "$desired_branch" '✅' "$active_branch" "$will_work"
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

# Throw the following command into a thread
function async () {
  $@ &
}

# ----------------[ Main ]--------------------------------
SILENT=
NO_WRITES=
for arg in $@; do
  case $arg in
    --silent|-s)
    SILENT=1
    ;;
    --no-write|--no-writes|-n)
    NO_WRITES=1
    ;;

  esac
done

setup_file

curr_repo_name=$(current_repo_name)
async dump_requirement dressipi_partner_api "$curr_repo_name"
async dump_requirement ff_api "$curr_repo_name"
async dump_requirement rspec-ff_api "$curr_repo_name"
if [[ "$curr_repo_name" == 'arcadia-dressipi' ]]; then 
 async dump_requirement arcadia-emails "$curr_repo_name"
fi
async dump_requirement ff_api dressipi_partner_api

wait

if [[ -z $SILENT ]]; then
  column -t -s, "$FILE"
fi
