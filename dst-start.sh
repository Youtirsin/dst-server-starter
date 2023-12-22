#!/bin/bash

#################### config start #########################

# ### NOTICE: no `/` in the end ###

# path to install DoNotStarveTogether dedicated server
# if you dont care, just leave it to be `$HOME/dst_server`
install_dir="$HOME/dst_server"

# the server name, also the directory name of the cluster
# for example, `Server_LTS` for `/mnt/d/workspace/dst/Server_LTS`
cluster_name=""

# the path to the parent directory of the cluster directory
# for example, `/mnt/d/workspace/dst` for `/mnt/d/workspace/dst/Server_LTS`
dontstarve_dir=""

# the path to the mods directory (optional)
# the directory usually contains `dedicated_server_mods_setup.lua` and `modsettings.lua`
mods_dir=""

####################  config end  #########################

function info()
{
  echo "[INFO] $@"
}

function error()
{
  echo "[ERROR] $@" >&2
}

function fail()
{
  error $@
  exit 1
}

function check_config_empty()
{
  if [[ "$install_dir" == "" ]]; then
    fail "please config install_dir."
  fi

  if [[ "$cluster_name" == "" ]]; then
    fail "please config cluster_name."
  fi

  if [[ "$dontstarve_dir" == "" ]]; then
    fail "please config dontstarve_dir."
  fi
}

function check_for_file()
{
  if [ ! -e "$1" ]; then
    error "missing file: $1"
    return 0
  fi
  return 1
}

function check_for_file_or_fail()
{
  if [ ! -e "$1" ]; then
    fail "missing file: $1"
    return 0
  fi
  return 1
}

function check_installed()
{
  local exe_name=$1

  if which "$exe_name" >/dev/null 2>&1; then
    info "$exe_name has been installed."
    return 1
  else
    info "$exe_name has not been installed."
    return 0
  fi
}

function install_steamcmd()
{
  sudo add-apt-repository multiverse; sudo dpkg --add-architecture i386; sudo apt update
  sudo apt install -y steamcmd
}

function ensure_steamcmd_installed()
{
  check_installed steamcmd
  if [[ $? -eq 0 ]]; then
    info "installing steamcmd."
    install_steamcmd
    # check if it has been installed
    check_installed steamcmd
    if [[ $? -eq 0 ]]; then
      fail "failed to install steamcmd."
    fi
  fi
}

function install_server()
{
  ensure_steamcmd_installed
  mkdir -p "$install_dir"
  steamcmd +force_install_dir "$install_dir" +login anonymous +app_update 343050 validate +quit
}

function ensure_server_installed()
{
  info "install or update dst server."
  install_server

  check_for_file "$install_dir/bin64"
  if [[ $? -eq 0 ]]; then
    install_server
    # check if it has been installed
    check_for_file "$install_dir/bin64"
    if [[ $? -eq 0 ]]; then
      fail "failed to install server."
    fi
  fi

  check_for_file "$install_dir/bin64/dontstarve_dedicated_server_nullrenderer_x64"
  if [[ $? -eq 0 ]]; then
    fail "invalid installation detected, please clear install_dir."
  fi
}

function maybe_copy_mod_config()
{
  if [[ "$mods_dir" == "" ]]; then
    info "mods_dir is empty, skip setting up mod config."
    return 0
  fi

  check_for_file_or_fail "$mods_dir/dedicated_server_mods_setup.lua"
  check_for_file_or_fail "$mods_dir/modsettings.lua"

  check_for_file_or_fail "$install_dir/mods"

  cp "$mods_dir/dedicated_server_mods_setup.lua" "$install_dir/mods"
  cp "$mods_dir/modsettings.lua" "$install_dir/mods"
}

function start_server()
{
  check_config_empty

  check_for_file_or_fail "$dontstarve_dir/$cluster_name/cluster.ini"
  check_for_file_or_fail "$dontstarve_dir/$cluster_name/cluster_token.txt"
  check_for_file_or_fail "$dontstarve_dir/$cluster_name/Master/server.ini"
  check_for_file_or_fail "$dontstarve_dir/$cluster_name/Caves/server.ini"

  ensure_server_installed

  cd "$install_dir/bin64" || fail "failed to enter the dst_dedicated_server dir"

  maybe_copy_mod_config

  run_shared=(./dontstarve_dedicated_server_nullrenderer_x64)
  run_shared+=(-persistent_storage_root "$dontstarve_dir")
  run_shared+=(-conf_dir ".")
  # this option is decrecated, use [MSIC] / console_enabled setting instead
  # run_shared+=(-console)
  run_shared+=(-cluster "$cluster_name")
  run_shared+=(-monitor_parent_process $$)

  "${run_shared[@]}" -shard Caves  | sed 's/^/Caves:  /' &
  "${run_shared[@]}" -shard Master | sed 's/^/Master: /'
}

start_server
