.DEFAULT_GOAL := help

.PHONY: help \
	clean \
	parity-gen-all \
	parity-check-all \
	parity-gen-main \
	parity-check-main \
	parity-gen-tracing-chrome \
	parity-check-tracing-chrome \
	gen-inventory-tracing \
	gen-source-parity-tracing \
	gen-test-parity-tracing \
	check-inventory-tracing \
	check-source-parity-tracing \
	check-test-parity-tracing \
	gen-inventory-tracing-chrome \
	gen-source-parity-tracing-chrome \
	gen-test-parity-tracing-chrome \
	check-inventory-tracing-chrome \
	check-source-parity-tracing-chrome \
	check-test-parity-tracing-chrome

PARITY_SKILL_DIR ?= $(HOME)/.codex/skills/cross-language-crystal-parity
PARITY_SCRIPT_DIR := $(PARITY_SKILL_DIR)/scripts
RUBY ?= ruby
PARITY_LANGUAGE ?= rust

TRACING_VENDOR_DIR := vendor/tracing
TRACING_CHROME_VENDOR_DIR := vendor/tracing-chrome

TRACING_PORT_INVENTORY := plans/inventory/rust_port_inventory.tsv
TRACING_SOURCE_PARITY := plans/inventory/rust_source_parity.tsv
TRACING_TEST_PARITY := plans/inventory/rust_test_parity.tsv

TRACING_CHROME_PORT_INVENTORY := plans/inventory/tracing_chrome_port_inventory.tsv
TRACING_CHROME_SOURCE_PARITY := plans/inventory/tracing_chrome_source_parity.tsv
TRACING_CHROME_TEST_PARITY := plans/inventory/tracing_chrome_test_parity.tsv

help:
	@printf "\ntracing.cr make targets\n\n"
	@printf "General:\n"
	@printf "  %-34s %s\n" "make clean" "Remove temp artifacts"
	@printf "\nMain tracing workspace (vendor/tracing):\n"
	@printf "  %-34s %s\n" "make parity-gen-main" "Generate/refresh all main tracing inventory/parity TSVs"
	@printf "  %-34s %s\n" "make parity-check-main" "Check all main tracing inventory/parity TSVs"
	@printf "  %-34s %s\n" "make gen-inventory-tracing" "Generate curated port inventory if missing"
	@printf "  %-34s %s\n" "make gen-source-parity-tracing" "Refresh source parity manifest"
	@printf "  %-34s %s\n" "make gen-test-parity-tracing" "Refresh test parity manifest"
	@printf "  %-34s %s\n" "make check-inventory-tracing" "Check curated port inventory drift"
	@printf "  %-34s %s\n" "make check-source-parity-tracing" "Check source parity drift"
	@printf "  %-34s %s\n" "make check-test-parity-tracing" "Check test parity drift"
	@printf "\ntracing-chrome submodule (vendor/tracing-chrome):\n"
	@printf "  %-34s %s\n" "make parity-gen-tracing-chrome" "Generate/refresh all tracing-chrome inventory/parity TSVs"
	@printf "  %-34s %s\n" "make parity-check-tracing-chrome" "Check all tracing-chrome inventory/parity TSVs"
	@printf "  %-34s %s\n" "make gen-inventory-tracing-chrome" "Generate curated tracing-chrome port inventory if missing"
	@printf "  %-34s %s\n" "make gen-source-parity-tracing-chrome" "Refresh tracing-chrome source parity manifest"
	@printf "  %-34s %s\n" "make gen-test-parity-tracing-chrome" "Refresh tracing-chrome test parity manifest"
	@printf "  %-34s %s\n" "make check-inventory-tracing-chrome" "Check tracing-chrome port inventory drift"
	@printf "  %-34s %s\n" "make check-source-parity-tracing-chrome" "Check tracing-chrome source parity drift"
	@printf "  %-34s %s\n" "make check-test-parity-tracing-chrome" "Check tracing-chrome test parity drift"
	@printf "\nAll inventories:\n"
	@printf "  %-34s %s\n" "make parity-gen-all" "Generate/refresh both main tracing and tracing-chrome TSVs"
	@printf "  %-34s %s\n" "make parity-check-all" "Check both main tracing and tracing-chrome TSVs"
	@printf "\nVariables:\n"
	@printf "  %-34s %s\n" "PARITY_SKILL_DIR=/path" "Override parity skill install path"
	@printf "  %-34s %s\n" "PARITY_LANGUAGE=rust" "Override language passed to parity scripts"

clean:
	rm -rf temp/*

parity-gen-main: gen-inventory-tracing gen-source-parity-tracing gen-test-parity-tracing

parity-check-main: check-inventory-tracing check-source-parity-tracing check-test-parity-tracing

parity-gen-tracing-chrome: gen-inventory-tracing-chrome gen-source-parity-tracing-chrome gen-test-parity-tracing-chrome

parity-check-tracing-chrome: check-inventory-tracing-chrome check-source-parity-tracing-chrome check-test-parity-tracing-chrome

parity-gen-all: parity-gen-main parity-gen-tracing-chrome

parity-check-all: parity-check-main parity-check-tracing-chrome

gen-inventory-tracing:
	@if [ -f "$(TRACING_PORT_INVENTORY)" ]; then \
		printf "Skipping existing curated inventory: %s\n" "$(TRACING_PORT_INVENTORY)"; \
	else \
		$(RUBY) "$(PARITY_SCRIPT_DIR)/generate_port_inventory.rb" --root . --out "$(TRACING_PORT_INVENTORY)" --source "$(TRACING_VENDOR_DIR)" --language "$(PARITY_LANGUAGE)"; \
	fi

gen-source-parity-tracing:
	$(RUBY) "$(PARITY_SCRIPT_DIR)/generate_source_parity_manifest.rb" --root . --out "$(TRACING_SOURCE_PARITY)" --source "$(TRACING_VENDOR_DIR)" --language "$(PARITY_LANGUAGE)" --force-overwrite

gen-test-parity-tracing:
	$(RUBY) "$(PARITY_SCRIPT_DIR)/generate_test_parity_manifest.rb" --root . --out "$(TRACING_TEST_PARITY)" --source "$(TRACING_VENDOR_DIR)" --language "$(PARITY_LANGUAGE)" --force-overwrite

check-inventory-tracing:
	$(RUBY) "$(PARITY_SCRIPT_DIR)/check_port_inventory.rb" --root . --manifest "$(TRACING_PORT_INVENTORY)" --source "$(TRACING_VENDOR_DIR)" --language "$(PARITY_LANGUAGE)"

check-source-parity-tracing:
	$(RUBY) "$(PARITY_SCRIPT_DIR)/check_source_parity.rb" --root . --manifest "$(TRACING_SOURCE_PARITY)" --source "$(TRACING_VENDOR_DIR)" --language "$(PARITY_LANGUAGE)"

check-test-parity-tracing:
	$(RUBY) "$(PARITY_SCRIPT_DIR)/check_test_parity.rb" --root . --manifest "$(TRACING_TEST_PARITY)" --source "$(TRACING_VENDOR_DIR)" --language "$(PARITY_LANGUAGE)"

gen-inventory-tracing-chrome:
	@if [ -f "$(TRACING_CHROME_PORT_INVENTORY)" ]; then \
		printf "Skipping existing curated inventory: %s\n" "$(TRACING_CHROME_PORT_INVENTORY)"; \
	else \
		$(RUBY) "$(PARITY_SCRIPT_DIR)/generate_port_inventory.rb" --root . --out "$(TRACING_CHROME_PORT_INVENTORY)" --source "$(TRACING_CHROME_VENDOR_DIR)" --language "$(PARITY_LANGUAGE)"; \
	fi

gen-source-parity-tracing-chrome:
	$(RUBY) "$(PARITY_SCRIPT_DIR)/generate_source_parity_manifest.rb" --root . --out "$(TRACING_CHROME_SOURCE_PARITY)" --source "$(TRACING_CHROME_VENDOR_DIR)" --language "$(PARITY_LANGUAGE)" --force-overwrite

gen-test-parity-tracing-chrome:
	@output_file="$(TRACING_CHROME_TEST_PARITY)"; \
	output=`$(RUBY) "$(PARITY_SCRIPT_DIR)/generate_test_parity_manifest.rb" --root . --out "$$output_file" --source "$(TRACING_CHROME_VENDOR_DIR)" --language "$(PARITY_LANGUAGE)" --force-overwrite 2>&1`; \
	status=$$?; \
	if [ $$status -eq 0 ]; then \
		printf "%s\n" "$$output"; \
	elif printf "%s\n" "$$output" | grep -Fq "No $(PARITY_LANGUAGE) test items found"; then \
		printf "%s\n" "$$output"; \
		printf "# source_test_id\tstatus\tcrystal_refs\tnotes\n" > "$$output_file"; \
		printf "Generated %s (0 test items; upstream has no discoverable tests).\n" "$$output_file"; \
	else \
		printf "%s\n" "$$output" >&2; \
		exit $$status; \
	fi

check-inventory-tracing-chrome:
	$(RUBY) "$(PARITY_SCRIPT_DIR)/check_port_inventory.rb" --root . --manifest "$(TRACING_CHROME_PORT_INVENTORY)" --source "$(TRACING_CHROME_VENDOR_DIR)" --language "$(PARITY_LANGUAGE)"

check-source-parity-tracing-chrome:
	$(RUBY) "$(PARITY_SCRIPT_DIR)/check_source_parity.rb" --root . --manifest "$(TRACING_CHROME_SOURCE_PARITY)" --source "$(TRACING_CHROME_VENDOR_DIR)" --language "$(PARITY_LANGUAGE)"

check-test-parity-tracing-chrome:
	$(RUBY) "$(PARITY_SCRIPT_DIR)/check_test_parity.rb" --root . --manifest "$(TRACING_CHROME_TEST_PARITY)" --source "$(TRACING_CHROME_VENDOR_DIR)" --language "$(PARITY_LANGUAGE)"
