# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Chris <goabonga@pm.me>

# Shell helpers wrapping the Terragrunt CLI. Source them, don't execute:
#
#   source scripts/terragrunt.sh
#   switch_env staging
#   plan  ./services/example
#   apply ./services/example
#
# Every command takes a path to a unit or to a subtree of units, relative
# to infrastructure/ (absolute paths work too). Paths resolve against
# SHOMER_INFRA_DIR, not the current directory, so these work from anywhere
# in the repo.
#
# Terragrunt's CLI redesign (>= v0.73) renamed the global flags
# (--terragrunt-non-interactive -> --non-interactive,
# --terragrunt-working-dir -> --working-dir), replaced `run-all <cmd>` with
# `run --all <cmd>`, and stopped forwarding bare OpenTofu commands — single
# unit commands now go through `run -- <cmd>`. Everything after `--` is
# passed straight to OpenTofu/Terraform.

BLACK=$(tput -Txterm setaf 0)
RED=$(tput -Txterm setaf 1)
GREEN=$(tput -Txterm setaf 2)
YELLOW=$(tput -Txterm setaf 3)
LIGHTPURPLE=$(tput -Txterm setaf 4)
PURPLE=$(tput -Txterm setaf 5)
BLUE=$(tput -Txterm setaf 6)
WHITE=$(tput -Txterm setaf 7)
RESET=$(tput -Txterm sgr0)

# Resolved at source time from this file's own location: BASH_SOURCE is set
# when sourced, unlike $0. Lets the helpers live in scripts/ while every
# path they touch stays anchored to infrastructure/.
SHOMER_INFRA_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../infrastructure" && pwd)"
export SHOMER_INFRA_DIR

export ENV=staging

# Turns a unit path into an absolute one under infrastructure/, leaving
# absolute paths alone.
function _tg_unit(){
	local p="${1#./}"
	case "${p}" in
		/*) echo "${p}" ;;
		*)  echo "${SHOMER_INFRA_DIR}/${p}" ;;
	esac
}

# Selects which configs/<env>/config.yaml the units read. No cloud context
# is switched here yet — once a provider is wired, this is where its
# account/subscription/project selection belongs (see
# services/terragrunt.hcl).
function switch_env(){
	if [[ -z "${1}" ]]
	then
		echo "usage: switch_env [environment]"
		echo "available:$(for d in "${SHOMER_INFRA_DIR}"/configs/*/; do [[ -f "${d}config.yaml" ]] && echo -n " $(basename "${d}")"; done)"
		return 1
	fi
	if [[ ! -f "${SHOMER_INFRA_DIR}/configs/${1}/config.yaml" ]]
	then
		echo "${RED}Error: file \"infrastructure/configs/${1}/config.yaml\" not found.${RESET}"
		return 1
	fi

	clean --silent
	echo "${WHITE}Switch to environment${RESET} ${PURPLE}${1}${RESET}"
	export ENV=${1}
}

function init(){
	if [[ -z "${1}" ]]
	then
		echo "usage: init ./services/<unit>"
		return 1
	fi
	terragrunt --non-interactive --working-dir "$(_tg_unit "${1}")" \
		run --all -- init -reconfigure
}

function providers(){
	if [[ -z "${1}" ]]
	then
		echo "usage: providers ./services/<unit>"
		return 1
	fi
	terragrunt --non-interactive --working-dir "$(_tg_unit "${1}")" \
		run -- providers ${2}
}

function import(){
	if [[ -z "${1}" ]]
	then
		echo "usage: import ./services/<unit> resource id"
		return 1
	fi
	terragrunt --non-interactive --working-dir "$(_tg_unit "${1}")" \
		run -- import ${2} ${3}
}

function state(){
	if [[ -z "${1}" ]]
	then
		echo "usage: state ./services/<unit> list"
		return 1
	fi
	terragrunt --non-interactive --working-dir "$(_tg_unit "${1}")" \
		run -- state ${2} ${3}
}

function apply(){
	if [[ -z "${1}" ]]
	then
		echo "usage: apply ./services/<unit>"
		return 1
	fi
	terragrunt --non-interactive --working-dir "$(_tg_unit "${1}")" \
		run --all -- apply
}

function plan(){
	if [[ -z "${1}" ]]
	then
		echo "usage: plan ./services/<unit>"
		return 1
	fi
	terragrunt --non-interactive --working-dir "$(_tg_unit "${1}")" \
		run --all -- plan ${2}
}

function output(){
	if [[ -z "${1}" ]]
	then
		echo "usage: output ./services/<unit>"
		return 1
	fi
	terragrunt --non-interactive --working-dir "$(_tg_unit "${1}")" \
		run --all -- output ${2} 2> /dev/null
}

function show(){
	if [[ -z "${1}" ]]
	then
		echo "usage: show ./services/<unit>"
		return 1
	fi
	terragrunt --non-interactive --working-dir "$(_tg_unit "${1}")" \
		run -- show ${2}
}

function graph(){
	if [[ -z "${1}" ]]
	then
		echo "usage: graph ./services/<unit>"
		return 1
	fi
	terragrunt --non-interactive --working-dir "$(_tg_unit "${1}")" \
		run --all -- graph
}

function refresh(){
	if [[ -z "${1}" ]]
	then
		echo "usage: refresh ./services/<unit>"
		return 1
	fi
	terragrunt --non-interactive --working-dir "$(_tg_unit "${1}")" \
		run --all -- refresh
}

function destroy(){
	if [[ -z "${1}" ]]
	then
		echo "usage: destroy ./services/<unit>"
		return 1
	fi
	terragrunt --non-interactive --working-dir "$(_tg_unit "${1}")" \
		run --all -- destroy
}

function clean(){
	if [[ ! "$@" =~ .*"--silent".* ]]; then
		echo "${GREEN}Clean directory${RESET}"
	fi
	rm -Rf "${SHOMER_INFRA_DIR}/graph"
	find "${SHOMER_INFRA_DIR}" -type d -name ".terragrunt-cache" \
	-o -type f -name ".terraform.lock.hcl" \
	-o -type d -name ".terraform" \
	-o -type f -name "generated_*.tf" | \
	xargs rm -Rf
}
