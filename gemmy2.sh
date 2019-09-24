# Description:
#   Determine if the current local dependency chain is compatible
#   Checks: <current repo> -> dressipi_partner_api -> ff_api
#
# Usage:
#   # go to the relevant repo e.g. pantheon2
#   ./gemmy.sh
#
# Requires
#     - bash 4
#     - GNU cut  (alias: gcut)
#     - GNU grep (alias: ggrep)
#
# Setup
#   $ brew install coreutils # gcut
#   # then get scripting!
#
TRUE=0
FALSE=1

NO_WRITES=
GEMFILE=./Gemfile
MAX_DEPTH=1

function get_value() { echo "$arg" | gcut --delimiter='=' --fields=2; }
function parse_args () {
  for arg in $@; do
    case $arg in
      --gemfile=*)
        GEMFILE=`get_value`
        ;;

      --depth=*)
        MAX_DEPTH=`get_value`
        ;;

      --no-write|--no-writes|-n)
        NO_WRITES=1
        ;;

      *)
        echo "Unrecognised argument: $arg"
        exit 2
        ;;
    esac
  done
}

RED='\033[0;31m'
BLUE='\033[0;36m'
NC='\033[0m'
function errecho() { echo -e "⚠️  ${RED}gemmy: $@${NC}" >&2; }
function debug() { if [[ -n $DEBUG ]] ; then echo -e "ℹ️  ${BLUE}$@${NC}" >&2 ; fi; }
function lstrip() { sed 's/^[ ][ ]*//'; }
function rstrip() { sed 's/[ ][ ]*$//'; }
function strip() { lstrip | rstrip; }

function print_branch()   { echo -e "   ├── $@"; }
function pprint_branch()  { echo -e "   │   ├── $@"; }
function ppprint_branch() { echo -e "   │   │    ├── $@"; }
function printer() {
  local depth=$1
  shift
  case $depth in
    0) print_branch $@;;
    1) print_branch $@;;
    2) pprint_branch $@;;
    *) ppprint_branch $@;;
  esac
}

function find_local_repo_path() {
  local test_repo=$1
  local index=0

  for repo in "${BUNDLE_LOCAL_REPOS[@]}"; do
    if [[ $test_repo == $repo ]]; then
      path="${BUNDLE_LOCAL_PATHS[$index]}"
      echo $path
      return
    fi
    (( index++ ))
  done
  echo ''
}


function get_last_field() { rev | gcut --delimiter=' ' --fields=1 | rev; }
function clean(){ sed 's/[:",]//g' | sed "s/'//g"; }

function repo_lines_in_gemfile () {
  local gemfile=$1
  local depth=$2

  local line
  grep "git: " "$gemfile" | strip | while read line; do
    name=$(echo $line | gcut --delimiter=' ' --fields=2 | clean)
    branch=$(echo $line | ggrep --only-matching 'branch: .*' | get_last_field | clean)

    local local_path='' local_branch=''
    local_path=$(find_local_repo_path "$name")

    if [[ -n $local_path ]]; then
      local_branch=$(cd "$local_path" && git rev-parse --abbrev-ref HEAD)
    fi

    if [[ -z "$local_path" ]]; then
      printer $depth "$name"
    elif [[ $branch == "$local_branch" ]]; then
      printer $depth "$name"
    else
      printer $depth "${RED}$name${NC} ❌  (Needs '$branch' branch, current: '$local_branch')"
    fi

    if [[ -n $local_path ]]; then
      local next_depth=$((depth + 1))
      repo_lines_in_gemfile "$local_path/Gemfile" $next_depth
    fi

  done
}


function skip_lines_like() { ggrep --invert-match $@; }

function get_bundle_locals_and_repos() {
  bundle config | grep 'local\.' --after-context 1 | \
   sed 's/local\.//' | skip_lines_like '^--' | get_last_field;
}

function discover_bundle_local_overrides () {
  local repo path
  for line in `get_bundle_locals_and_repos`; do
    if [[ -z $repo ]]; then
      repo=$line
      BUNDLE_LOCAL_REPOS+=($repo)
    else
      path=$(echo $line | clean | strip)
      BUNDLE_LOCAL_PATHS+=($path)
      repo=''
    fi
  done
}

# ------------------[ Main ]------------------
BUNDLE_LOCAL_REPOS=()
BUNDLE_LOCAL_PATHS=()
discover_bundle_local_overrides
debug "=============================="
debug ${BUNDLE_LOCAL_REPOS[*]}
debug ${BUNDLE_LOCAL_PATHS[*]}
debug "=============================="

parse_args $@
debug "Using Gemfile: $GEMFILE"

current_repo=$(pwd | sed 's:.*/::g')
echo $current_repo
repo_lines_in_gemfile "$GEMFILE" 1
