#!/bin/bash
# Description
#   Install the requirements for gemmy.sh
# Usage
#   ./install.sh
#

echo '=[⚙ ️]=================[ Installing Requirements ]==================='
function install() {
  local command=$1
  local install_method=$2

  echo "🤔 Checking for: ${command}"
  if $command --version 2> /dev/null; then
    echo "✅ ${command} already is installed"
    echo
  else
    echo "⚙️  installing ${command}"
    $install_method || exit 1
    echo
  fi
}

echo 'Installing requirements for gemmy ⚙️'
install 'brew'      "echo 'head to https://brew.sh/ for install instructions'; exit 1"
install 'ggrep'     "brew install grep"
install 'greadlink' "brew install coreutils"
install 'gcut'      "brew install coreutils"

echo
echo '=[📝 ]======================[ Adding Alias ]=========================='
function check_profile_works() {
  {
    source ~/.bash_profile && echo "✅ ~/.bash_profile is stable"
  } || {
    echo '👹 Something went wrong sourcing ~/.bash_profile, please fix your bash_profile';
    exit 2
  }
}

#echo '🤔 Checking for gemmy alias'
# TODO

echo "🧪 Check ~/.bash_profile is stable before adding alias"
check_profile_works

current_script_path=$(greadlink -f "${BASH_SOURCE[0]}")
gemmy_dir=$(dirname "$current_script_path")
echo "Adding alias to ~/.bash_profile"
echo "alias gemmy='sh ${gemmy_dir}/gemmy.sh'" >> ~/.bash_profile
echo "🧪  Check ~/.bash_profile is stable after adding alias"
check_profile_works

echo
echo '=[🧪 ]=====================[ Testing Gemmy ]=========================='
echo '🤖 Running gemmy script'
{
  sh "${gemmy_dir}/gemmy.sh" help && echo "✅  Gemmy ran!"
} || {
  echo '👹 Oh no gemmy did not work!'
}
