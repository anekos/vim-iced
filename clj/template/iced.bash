#!/bin/bash

CWD=$(pwd)
SCRIPT_DIR=$(cd $(dirname $0); pwd)
PROJECT_DIR=$(cd $SCRIPT_DIR; cd ..; pwd)
VERSION=$(grep 'Version: ' ${SCRIPT_DIR}/../doc/vim-iced.txt | cut -d' ' -f2)

BASE_DEPENDENCIES={{{base-dependencies}}}
BASE_MIDDLEWARES={{{base-middlewares}}}

{{#option-configs}}
{{{name}}}_DEPENDENCIES={{{dependencies}}}
{{{name}}}_MIDDLEWARES={{{middlewares}}}
{{/option-configs}}

IS_LEININGEN=0
IS_BOOT=0
IS_CLOJURE_CLI=0
IS_SHADOW_CLJS=0
IS_DRYRUN=0
IS_INSTANT=0

function iced_usage() {
    echo "vim-iced ${VERSION}"
    echo ""
    echo "Usage:"
    echo "  iced <task> [options]"
    echo ""
    echo "Following tasks are available:"
    echo "  repl      Start repl"
    echo "  help      Print this help"
    echo "  version   Print vim-iced version"
    echo ""
    echo "Use 'iced help <task>' or 'iced <task> --help' for more information."
    exit 1
}

function iced_repl_usage() {
    echo "Usage:"
    echo "  iced repl [options] [--with-cljs] [--without-cljs]"
    echo "            [--with-kaocha]"
    echo "            [--dependency=VALUE] [--middleware=VALUE]"
    echo "            [--force-boot] [--force-clojure-cli]"
    echo "            [--instant]"
    echo ""
    echo "Start repl. Leiningen, Boot, and Clojure CLI are supported."
    echo ""
    echo "The --with-cljs option enables ClojureScript features."
    echo "This option is enabled automatically when project configuration"
    echo "file(eg. project.clj) contains 'org.clojure/clojurescript' dependency."
    echo ""
    echo "The --with-kaocha option enables testing with Kaocha features."
    echo ""
    echo "On the other hand, the --without-cljs option disables ClojureScript features."
    echo ""
    echo "The --dependency option adds extra dependency."
    echo "VALUE format is 'PACKAGE_NAME:VERSION'."
    echo "For example: --dependency=iced-nrepl:0.4.3"
    echo ""
    echo "The --middleware option adds extra nrepl middleware."
    echo "For example: --middleware=iced.nrepl/wrap-iced"
    echo ""
    echo "The --force-boot and --force-clojure-cli option enable you to start specified repl."
    echo ""
    echo "The --instant option launch instant REPL via Clojure CLI."
    echo "Instant REPL requires no project/config file."
    echo ""
    echo "Other options are passed to each program."
    echo "To specify Leiningen profile:"
    echo "  $ iced repl with-profile +foo"
    echo "To specify Clojure CLI alias:"
    echo "  $ iced repl -A:foo"
    echo "Combinating several options:"
    echo "  $ iced repl --with-cljs --force-clojure-cli -A:foo"
}

function echo_info() {
    echo -e "\x1B[32mOK\x1B[m: \x1B[1m${1}\x1B[m"
}

function echo_error() {
    echo -e "\x1B[31mNG\x1B[m: \x1B[1m${1}\x1B[m"
}

function leiningen_deps_args() {
    local deps=($@)

    for s in "${deps[@]}" ; do
        key="${s%%:*}"
        value="${s##*:}"
        echo -n "update-in :dependencies conj '[${key} \"${value}\"]' -- "
    done
}

function leiningen_middleware_args() {
    local mdws=($@)
    for value in "${mdws[@]}" ; do
        echo -n "update-in :repl-options:nrepl-middleware conj '${value}' -- "
    done
}

function boot_deps_args() {
    local deps=($@)

    echo -n '-i "(require ''cider.tasks)" '
    for s in "${deps[@]}" ; do
        key="${s%%:*}"
        value="${s##*:}"
        echo -n "-d ${key}:${value} "
    done
}

function boot_middleware_args() {
    local mdws=($@)
    echo -n '-- cider.tasks/add-middleware '
    for value in "${mdws[@]}" ; do
        echo -n "-m ${value} "
    done
}

function cli_deps_args() {
    local deps=($@)
    for s in "${deps[@]}" ; do
        key="${s%%:*}"
        value="${s##*:}"
        echo -n "${key} {:mvn/version \"${value}\"} "
    done
}

function cli_middleware_args() {
    local mdws=($@)
    echo -n "-m '["
    for value in "${mdws[@]}" ; do
        echo -n "\"${value}\" "
    done
    echo -n "]'"
}

function run() {
    local cmd=$1
    if [ $IS_DRYRUN -eq 0 ]; then
        bash -c "$cmd"
    else
        echo $cmd
    fi
}

if [ $# -lt 1 ]; then
    iced_usage
    exit 1
fi

ARGV=($@)
ARGV=("${ARGV[@]:1}")

IS_HELP=0
IS_CLJS=0
IS_KAOCHA=0
FORCE_BOOT=0
FORCE_CLOJURE_CLI=0
DISABLE_CLJS_DETECTOR=0

OPTIONS=""
EXTRA_DEPENDENCIES=""
EXTRA_MIDDLEWARES=""
for x in ${ARGV[@]}; do
    key="${x%%=*}"
    value="${x##*=}"

    if [ $key = '--help' ]; then
        IS_HELP=1
    elif [ $key = '--with-cljs' ]; then
        IS_CLJS=1
    elif [ $key = '--without-cljs' ]; then
        DISABLE_CLJS_DETECTOR=1
    elif [ $key = '--with-kaocha' ]; then
        IS_KAOCHA=1
    elif [ $key = '--force-boot' ]; then
        FORCE_BOOT=1
    elif [ $key = '--force-clojure-cli' ]; then
        FORCE_CLOJURE_CLI=1
    elif [ $key = '--dependency' ]; then
        EXTRA_DEPENDENCIES="${EXTRA_DEPENDENCIES} ${value}"
    elif [ $key = '--middleware' ]; then
        EXTRA_MIDDLEWARES="${EXTRA_MIDDLEWARES} ${value}"
    elif [ $x = '--instant' ]; then
        IS_INSTANT=1
    elif [ $x = '--dryrun' ]; then
        IS_DRYRUN=1
    else
        OPTIONS="${OPTIONS} ${x}"
    fi
done

IS_DETECTED=0

# For instant repl, vim-iced uses Clojure CLI
if [ $IS_INSTANT -eq 1 ]; then
    IS_DETECTED=1
    IS_CLOJURE_CLI=1
fi

while :
do
    ls project.clj > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        IS_LEININGEN=1
        IS_DETECTED=1

        if [ $DISABLE_CLJS_DETECTOR -ne 1 ]; then
            grep org.clojure/clojurescript project.clj > /dev/null 2>&1
            if [ $? -eq 0 ]; then
                IS_CLJS=1
            fi
        fi
    fi

    ls build.boot > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        IS_BOOT=1
        IS_DETECTED=1

        if [ $DISABLE_CLJS_DETECTOR -ne 1 ]; then
            grep org.clojure/clojurescript build.boot > /dev/null 2>&1
            if [ $? -eq 0 ]; then
                IS_CLJS=1
            fi
        fi
    fi

    ls deps.edn > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        IS_CLOJURE_CLI=1
        IS_DETECTED=1

        if [ $DISABLE_CLJS_DETECTOR -ne 1 ]; then
            grep org.clojure/clojurescript deps.edn > /dev/null 2>&1
            if [ $? -eq 0 ]; then
                IS_CLJS=1
            fi
        fi
    fi

    ls shadow-cljs.edn > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        IS_SHADOW_CLJS=1
        IS_DETECTED=1
    fi

    if [ $IS_DETECTED -eq 1 ]; then
        break
    fi

    cd ..
    if [ $(pwd) == $CWD ]; then
        break
    else
        CWD=$(pwd)
    fi
done

if [ $FORCE_BOOT -eq 1 ]; then
    IS_LEININGEN=0
    IS_CLOJURE_CLI=0
elif [ $FORCE_CLOJURE_CLI -eq 1 ]; then
    IS_LEININGEN=0
    IS_BOOT=0
fi

TARGET_DEPENDENCIES=$BASE_DEPENDENCIES
TARGET_MIDDLEWARES=$BASE_MIDDLEWARES
INJECTING_OPTIONS=( {{#option-configs}}'{{{name}}}' {{/option-configs}})

for k in ${INJECTING_OPTIONS[@]}; do
    eval FLAG=\$IS_${k}
    if [ $FLAG -eq 1 ]; then
        echo_info "${k} option is enabled."
        eval SUB_DEP=\"\$${k}_DEPENDENCIES\"
        eval SUB_MID=\"\$${k}_MIDDLEWARES\"

        TARGET_DEPENDENCIES="${TARGET_DEPENDENCIES} ${SUB_DEP}"
        TARGET_MIDDLEWARES="${TARGET_MIDDLEWARES} ${SUB_MID}"
    fi
done

TARGET_DEPENDENCIES="${TARGET_DEPENDENCIES} ${EXTRA_DEPENDENCIES}"
TARGET_MIDDLEWARES="${TARGET_MIDDLEWARES} ${EXTRA_MIDDLEWARES}"

case "$1" in
    "repl")
        if [ $IS_HELP -eq 1 ]; then
            iced_repl_usage
        elif [ $IS_LEININGEN -eq 1 ]; then
            echo_info "Leiningen project is detected"
            run "lein $(leiningen_deps_args ${TARGET_DEPENDENCIES}) \
                      $(leiningen_middleware_args ${TARGET_MIDDLEWARES}) \
                      $OPTIONS repl"
        elif [ $IS_BOOT -eq 1 ]; then
            echo_info "Boot project is detected"
            run "boot $(boot_deps_args ${TARGET_DEPENDENCIES}) \
                      $(boot_middleware_args ${TARGET_MIDDLEWARES}) \
                      -- $OPTIONS repl"
        elif [ $IS_CLOJURE_CLI -eq 1 ]; then
            if [ $IS_INSTANT -eq 1 ]; then
                echo_info "Starting instant REPL via Clojure CLI"
            else
                echo_info "Clojure CLI project is detected"
            fi

            run "clojure $OPTIONS -Sdeps '{:deps {iced-repl {:local/root \"${PROJECT_DIR}\"} $(cli_deps_args ${TARGET_DEPENDENCIES}) }}' \
                         -m nrepl.cmdline $(cli_middleware_args ${TARGET_MIDDLEWARES})"
        elif [ $IS_SHADOW_CLJS -eq 1 ]; then
            echo_error 'Currently iced command does not support shadow-cljs.'
            echo 'Please see `:h vim-iced-manual-shadow-cljs` for manual setting up.'
            exit 1
        else
            echo_error 'Failed to detect clojure project'
            exit 1
        fi
        ;;
    "help")
        case "$2" in
            "repl")
                iced_repl_usage
                ;;
            *)
                iced_usage
                ;;
        esac
        exit 0
        ;;
    "version")
        echo "${VERSION}"
        ;;
    *)
        iced_usage
        exit 1
        ;;
esac

exit 0
