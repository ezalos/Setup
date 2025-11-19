#!/usr/bin/env bash
# ---------------------------------------------------------------------------- #
#  heuritech_env.sh                                                             #
# ---------------------------------------------------------------------------- #
# Environment variables, PATH tweaks and aliases that are specific to          #
# any machine whose WHICH_COMPUTER ends with _Heuritech.                       #
# This file is sourced by ~/.zshrc.                                            #
# ---------------------------------------------------------------------------- #

# Guard clause – source nothing if not on a Heuritech machine
[[ $WHICH_COMPUTER =~ _Heuritech$ ]] || return 0

# ------------------------------ Generic Heuritech ---------------------------- #

# # Pyenv
# export PYENV_ROOT="$HOME/.pyenv"
# [[ -d $PYENV_ROOT/bin ]] && path_prepend "$PYENV_ROOT/bin"

# # Initialise pyenv only if available
# command -v pyenv >/dev/null 2>&1 && {
#   eval "$(pyenv init --path)"
#   eval "$(pyenv init -)"
#   eval "$(pyenv virtualenv-init -)"
# }

# # Add monorepo libraries to PYTHONPATH
# pythonpaths_monorepo_lib_src=$(find "$HOME/monorepo/libraries" -maxdepth 2 -name "src" -type d | tr '\n' ':' | sed 's/:$//')
# export PYTHONPATH="${PYTHONPATH}:${pythonpaths_monorepo_lib_src}"

# AWS & service endpoints
export AWS_PROFILE="euprod"
export AWS_REGION="eu-west-1"

export THESAURUS_ROUTE_BASE=https://thesaurus-api.heuritech.com/api
export OPSTER_MODULES_ROUTE_BASE=https://opster-api.heuritech.com/modules
export MODULES_ROUTE_BASE=https://modules-api.heuritech.com
export CATALOG_ROUTE_BASE=https://catalog-api.heuritech.com
export INDUS_ROUTE_BASE=https://indus-api.heuritech.com
export DATASET_ROUTE_BASE=https://dataset-api.heuritech.com
export LABELING_ROUTE_BASE=https://labeling-api.heuritech.com

