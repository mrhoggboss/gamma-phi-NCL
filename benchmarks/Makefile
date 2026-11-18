# The paper's benchmarks: rerun the solves and emit the five tables. Run from the repository root:
#
#   make -C benchmarks [all]
#       Rerun every suite, then emit the five tables from the rerun (benchmarks/out/paper/results): CUTEst on the CPU,
#       then the GPU suites opf and scopf, in that order. DEVICE is checked and the SCOPF case files are downloaded
#       (each of the two sets only when its sha256 check fails) before the CPU chain starts. Days.
#
#   make -C benchmarks cpu|opf|scopf
#       Rerun one suite (cpu = CUTEst; opf = the 66 PGLIB ACOPF instances; scopf = the 41 SCOPF instances, after
#       downloading their case files when needed), then emit its tables from the rerun.
#
#   make -C benchmarks tables
#       Emit the five tables from the published results in benchmarks/results/paper. Seconds.
#
#   DEVICE=<n>                    the GPU of the GPU suites (default 0)
#   PAPER_OUT=<dir>               where everything is written (default benchmarks/out/paper); benchmarks/results/paper
#                                 is never written
#   SCOPF_DATA=<dir>              the SCOPF case files (default benchmarks/out/scopf_data), written by
#                                 instances/fetch_scopf_data.sh and instances/fetch_pglib_scopf_data.sh
#   Relative paths are taken from the repository root.
#
# A rerun resumes: after an interruption, run the same command again; finished cells are skipped. The tables are emitted
# from a rerun only when every cell of the rerun has its result; otherwise the missing cells are listed. An emit prints
# the path of every table written; the emitters' own output goes to <PAPER_OUT>/logs/emit.log.

SHELL := /bin/bash
.SHELLFLAGS := -ec
.ONESHELL:
.SILENT:
.NOTPARALLEL:

ROOT := $(abspath $(dir $(lastword $(MAKEFILE_LIST)))/..)
PAPER := $(ROOT)/benchmarks/paper
INST := $(ROOT)/benchmarks/instances
PUBLISHED := $(ROOT)/benchmarks/results/paper

# The cells of a rerun. The chains are given these lists, and a rerun is complete when every cell has its result.
CPU_CONFIGS := S SP W U6A liftedkkt ipopt madnlp
GPU_CONFIGS := S SP W U6A liftedkkt
GPU_REPS := 1 2 3

DEVICE ?= 0
PAPER_OUT ?= benchmarks/out/paper
SCOPF_DATA ?= benchmarks/out/scopf_data
fromroot = $(if $(filter /%,$(1)),$(1),$(ROOT)/$(1))
override PAPER_OUT := $(call fromroot,$(PAPER_OUT))
override SCOPF_DATA := $(call fromroot,$(SCOPF_DATA))
export DEVICE PAPER_OUT SCOPF_DATA
RERUN := $(PAPER_OUT)/results

.PHONY: all cpu opf scopf tables run-cpu run-opf run-scopf check-device fetch-scopf

all: check-device fetch-scopf run-cpu run-opf run-scopf
	$(FUNCTIONS)
	require_complete cutest opf scopf
	emit "$$(rel "$(RERUN)")" "$(RERUN)" cutest opf scopf

cpu: run-cpu
	$(FUNCTIONS)
	require_complete cutest
	emit "$$(rel "$(RERUN)")" "$(RERUN)" cutest

opf: check-device run-opf
	$(FUNCTIONS)
	require_complete opf
	emit "$$(rel "$(RERUN)")" "$(RERUN)" opf

scopf: check-device fetch-scopf run-scopf
	$(FUNCTIONS)
	require_complete scopf
	emit "$$(rel "$(RERUN)")" "$(RERUN)" scopf

tables:
	$(FUNCTIONS)
	emit "$$(rel "$(PUBLISHED)")" "$(PUBLISHED)" cutest opf scopf

check-device:
	case "$$DEVICE" in ''|*[!0-9]*) echo "DEVICE=$$DEVICE: the GPU index must be a non-negative integer" >&2; exit 2 ;; esac

fetch-scopf:
	$(call fetch,$(SCOPF_DATA),scopf_data.sha256,fetch_scopf_data.sh)
	$(call fetch,$(SCOPF_DATA),scopf_pglib_data.sha256,fetch_pglib_scopf_data.sh)

run-cpu:
	echo "== rerun cpu $$(date -Is)"
	"$(PAPER)/chain_cpu.sh" $(CPU_CONFIGS)

run-opf run-scopf: run-%: check-device
	echo "== rerun $* $$(date -Is)"
	"$(PAPER)/chain_gpu.sh" "$$DEVICE" $* "$(GPU_REPS)" "$(GPU_CONFIGS)"

run-scopf: fetch-scopf

# fetch <dir>,<manifest>,<script>: run instances/<script> <dir> unless <dir> passes the sha256 check of instances/<manifest>
define fetch
if (cd "$(1)" 2> /dev/null && sha256sum --quiet -c "$(INST)/$(2)" > /dev/null 2>&1); then
    echo "data in $(1): $(2) check passes, no fetch"
else
    "$(INST)/$(3)" "$(1)" || { echo "fetch failed: $(INST)/$(3) $(1)"; exit 1; }
fi
endef

# Shell functions of the emitting recipes (FLOATS_<suite>, TABLES and LOGS come from paper/lib.sh).
#   missing <suite>                 the cells of the suite's rerun without a result
#   require_complete <suite>...     stop, listing the missing cells, unless every cell of these reruns has its result
#   emit <label> <res> <suite>...   paper/emit.sh with RES=<res>, then the path of every table written, in FLOATS order
define FUNCTIONS
source "$(PAPER)/lib.sh"
rel() { case $$1 in "$(ROOT)"/*) printf '%s\n' "$${1#"$(ROOT)"/}" ;; *) printf '%s\n' "$$1" ;; esac; }
missing() {
    local c k
    if [ "$$1" = cutest ]; then
        for c in $(CPU_CONFIGS); do
            if [ ! -f "$(RERUN)/cutest/cutest__$${c}__ma57.csv" ]; then echo "cutest $$c"; fi
        done
    else
        for k in $(GPU_REPS); do for c in $(GPU_CONFIGS); do
            if [ ! -f "$(RERUN)/$$1/$$1__$${c}__r$$k.csv" ]; then echo "$$1 $$c r$$k"; fi
        done; done
    fi
}
require_complete() {
    local m
    m=$$(for s in "$$@"; do missing "$$s"; done)
    if [ -n "$$m" ]; then
        echo "the rerun is not complete; these cells have no result in $$(rel "$(RERUN)"):"
        echo "$$m" | sed 's/^/  /'
        echo "run the same command again to resume (finished cells are skipped)"
        exit 1
    fi
}
emit() {
    local label=$$1 res=$$2 log=$$LOGS/emit.log rc=0 s v f
    shift 2
    echo "emitting the tables of $$* from $$label"
    RES=$$res "$(PAPER)/emit.sh" "$$@" > "$$log" 2>&1 || rc=$$?
    if [ $$rc -ne 0 ]; then echo "emit.sh failed (rc $$rc); last lines of $$(rel "$$log"):"; tail -n 15 "$$log"; fi
    for s in "$$@"; do
        v=FLOATS_$$s
        for f in $${!v}; do if [ -f "$$TABLES/$$f.tex" ]; then rel "$$TABLES/$$f.tex"; fi; done
    done
    return $$rc
}
endef
