SHELL := /bin/bash

unexport FILTER
test_filter_arg = $(if $(value FILTER),--filter '$(subst ','"'"',$(value FILTER))')

.PHONY: build check format lint restart start start-debug start-release stop test test-fast

start start-debug restart:
	./Scripts/compile_and_run.sh

start-release:
	./Scripts/compile_and_run.sh --release

stop:
	./Scripts/compile_and_run.sh --stop

build:
	swift build

test:
	./Scripts/test.sh

test-fast:
	./Scripts/test_fast.sh $(test_filter_arg)

check lint:
	./Scripts/lint.sh lint

format:
	./Scripts/lint.sh format
