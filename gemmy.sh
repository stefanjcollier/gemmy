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
#     - GNU readlink (alias: greadlink)
#
# Setup
#   $ brew install coreutils # gcut, greadlink
#   $ brew install ggrep # ggrep
#   # then get scripting!
#
TRUE=0
FALSE=1

GEMFILE=./Gemfile
MAX_DEPTH=5

A_GEMMY_CHECK="check"
A_GEMMY_LOCAL="local"
A_GEMMY_REMOTE="remote"

function get_value() { echo "$arg" | gcut --delimiter='=' --fields=2; }

# ========================================================================
# ==[ Helpers ]===========================================================
# =========================== [ Text Functions ] =========================
# ========================================================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
GREY='\033[0;37m'
NC='\033[0m'
function errecho() { echo -e "⚠️  ${RED}gemmy: $@${NC}" >&2; }
function debug() { [[ -n $DEBUG ]] && echo -e "ℹ️  ${BLUE}$@${NC}" >&2; }
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


# ========================================================================
# ==[ Helpers ]===========================================================
# =========================== [ Bundle Config ] ==========================
# ========================================================================
function skip_lines_like() { ggrep --invert-match $@; }

function get_bundle_locals_and_repos() {
  bundle config | grep 'local\.' --after-context 1 | \
   sed 's/local\.//' | skip_lines_like '^--' | get_last_field;
}

function discover_bundle_local_overrides () {
  BUNDLE_LOCAL_REPOS=()  # global
  BUNDLE_LOCAL_PATHS=()  # global
  local repo path

  for line in $(get_bundle_locals_and_repos); do
    if [[ -z $repo ]]; then
      repo=$line
      BUNDLE_LOCAL_REPOS+=($repo)
    else
      path=$(echo $line | clean | strip)
      BUNDLE_LOCAL_PATHS+=($path)
      repo=''
    fi
  done
  debug "===[ Local Bundle Override]==========================="
  debug "Repo Names:: ${BUNDLE_LOCAL_REPOS[*]}"
  debug "Repo Paths:: ${BUNDLE_LOCAL_PATHS[*]}"
  debug "======================================================="
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

# ========================================================================
# ==[ Action ]============================================================
# ============================ [ Gemmy Check ] ===========================
# ========================================================================
function help__gemmy_check () {
  echo "gemmy check [--gemfile=<path> (default: ./Gemfile)] [--max-depth=<int> (default: 5)]"
}

function parse_gemmy_check_options () {
  local options=$@
  for arg in $options; do
    case $arg in
      --gemfile=*)
        GEMFILE=`get_value`
        ;;

      --depth=*|--max-depth=*)
        MAX_DEPTH=`get_value`
        ;;

      *)
        echo "Unrecognised option: $arg"
        exit 2
        ;;
    esac
  done
}


VER_OPERATOR_REGEX='^[=<>~][=<>~]?$'
# Note: SEMVER_REGEX requires is in perl syntax NOT BASH SYNTAX
# It is also not the official one, it allows for incomplete semver e.g. 8.0 instead 8.0.0
SEMVER_REGEX='([0-9]+)(\.([0-9]+)(\.([0-9]+)(?:-([0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*))?(?:\+[0-9A-Za-z-]+)?)?)?'
function extract_semversion() { ggrep --only-matching --perl-regexp "$SEMVER_REGEX"; }
function is_semversion() { ggrep --only-matching --perl-regexp "^$SEMVER_REGEX$" --silent; }
function get_repo_version() {
  local repo_name=$1
  local repo_path=$2

  # First try a version.rb file
  for version_file in $(find "${repo_path}" -name version.rb); do
    version=$(cat "$version_file" | extract_semversion)
    if [[ -n "$version" ]]; then
      echo "$version"
      return
    fi
  done

  # Fallback to gemspec file
  gemspec_file="${repo_path}/${repo_name}.gemspec"
  if [ ! -f "$gemspec_file" ]; then
    gemspec_file="${repo_path}/${repo_name//-/_}.gemspec"
  fi
  cat "$gemspec_file" | ggrep -P "\.version.*=.*$SEMVER_REGEX" | extract_semversion
}

function get_version_spec() {
  local line=$@
  local version_controller=
  VERSION_SPECS=()
  debug "=======[ get_version_spec ]================================="
  line=$(echo $line | sed "s/'//g")
  for part in ${line//,/ }; do
    if [[ $part =~ $VER_OPERATOR_REGEX ]]; then
      version_controller=$part
      debug "Operator: '$part'  "

    elif echo "$part" | is_semversion; then
      VERSION_SPECS+=("${version_controller}${part}")
      version_controller=
      debug "Version:  '$part'  "

    else
      debug "❌        '$part'  "
    fi
  done
  debug "==============================================================="
}

function get_last_field() { rev | gcut --delimiter=' ' --fields=1 | rev; }
function clean(){ sed 's/[:",]//g' | sed "s/'//g"; }
function clean_gemfile_lines() {
  sed 's/:branch =>/branch:/' "$1" |  sed 's/:git =>/git:/' | strip;
}

function repo_lines_in_gemfile () {
  local gemfile=$1
  local depth=$2

  local line
  clean_gemfile_lines "$gemfile" | grep "git:" | while read line; do
    if (( depth > MAX_DEPTH)); then
      printer "$depth" "${GREY}─ ─ Reached Max Depth ─ ─${NC}"
      return
    fi

    name=$(echo $line | gcut --delimiter=' ' --fields=2 | clean)
    branch=$(echo $line | ggrep --only-matching 'branch:.*' | get_last_field | clean)

    local local_path='' local_branch=''
    local_path=$(find_local_repo_path "$name")

    if [[ -n $local_path ]]; then
      local_branch=$(cd "$local_path" && git rev-parse --abbrev-ref HEAD)
    fi

    if [[ -n "$local_path" ]]; then
      version=$(get_repo_version "$name" "$local_path")
      if [[ -n $version ]]; then
        version_string=" (v$version)"
        get_version_spec "$line"
      else
        [[ -n $DEBUG ]] && errecho "Cannot find version for $name"
      fi

      if [[ -n "$branch" ]] && [[ $branch != "$local_branch" ]]; then
        printer "$depth" "${RED}$name${NC}$version_string ❌ (Needs '${BLUE}$branch${NC}' branch, current: '${YELLOW}$local_branch${NC}')"
      else
        printer "$depth" "${GREEN}$name${NC}$version_string 👀"
      fi
      debug "   ^ Version:: $version    Version Specs:: ${VERSION_SPECS[@]}"
    else
      printer "$depth" "$name"
    fi

    if [[ -n $local_path ]]; then
      local next_depth=$((depth + 1))
      repo_lines_in_gemfile "$local_path/Gemfile" $next_depth
    fi

  done
}

function action_gemmy_check () {
  local options=$@
  discover_bundle_local_overrides
  parse_gemmy_check_options $options
  echo "$PARENT_NAME"
  repo_lines_in_gemfile "$GEMFILE" 1
}

# ========================================================================
# ==[ Action ]============================================================
# =========================== [ Gemmy Local ] ============================
# ========================================================================
function help__gemmy_local () {
  echo 'gemmy local <gem_name> [<path> (default: attempt to find it)]'
}

function path () { greadlink -f $1; }

# Assume the repo is in the same dir as this one e.g.
# /repos
#   |- current_repo
#   |- other_repo
function assume_repo_path () {
  local repo_name=$1
  path "../$repo_name"
}

function action_gemmy_local () {
  local repo_name=$1
  local repo_path=$2

  if [ -z "$repo_name" ]; then
    errecho "Specify a gem name"
    exit 3
  fi
  if [ -z "$repo_path" ]; then
    repo_path=$(assume_repo_path "$repo_name")
  fi

  if [ ! -d "$repo_path" ]; then
    errecho "$repo_name does not exist at $repo_path"
    exit 3
  fi

  bundle config "local.$repo_name" "$repo_path"
  echo -e "Using ${BLUE}${repo_name}${NC} at: $repo_path"
}


# ========================================================================
# ==[ Action ]============================================================
# ========================= [ Gemmy Remote ] =============================
# ========================================================================
function help__gemmy_remote () {
    echo 'gemmy remote <gem_name>...'
}

function repo_is_used_locally () {
  local repo_name=$1
  bundle config | ggrep --only-matching "local.$repo_name" --silent && return $TRUE || return $FALSE
}

function action_gemmy_remote () {
  local repo_names=$@
  if [ -z "$repo_names" ]; then
    errecho "Specify at least one gem name"
    exit 3
  fi
  for repo_name in $repo_names; do
    if repo_is_used_locally "$repo_name"; then
      bundle config --delete "local.$repo_name"
      echo -e "No longer using ${BLUE}${repo_name}${NC} locally"

    else
      errecho "$repo_name is not being used locally"
    fi
  done
}

# ========================================================================
# =============================== [ Main ] ===============================
# ========================================================================
PARENT_NAME=$(pwd | sed 's:.*/::g')

action=$1
if [[ -z $action ]] || [[ $action =~ ^-- ]]; then
  action="$A_GEMMY_CHECK"
else
  shift
fi
other_args=$@
debug "Action:: '$action' Options:: '$@' "

case $action in
  $A_GEMMY_CHECK)
    action_gemmy_check $other_args
    ;;
  $A_GEMMY_LOCAL)
    action_gemmy_local $other_args
    ;;
  $A_GEMMY_REMOTE)
    action_gemmy_remote $other_args
    ;;
  help)
    help__gemmy_check
    help__gemmy_local
    help__gemmy_remote
    ;;
  *)
    echo "gemmy: Unrecognised action: $action"
    exit 1
    ;;
esac
