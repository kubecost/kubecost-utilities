# List every *.sh script in the repo, skipping the .git directory.
SHELL_SCRIPTS := $(shell find . -type f -name '*.sh' -not -path './.git/*')

.PHONY: shellcheck
shellcheck:
	@echo "Running shellcheck on $(words $(SHELL_SCRIPTS)) script(s)…"
	@shellcheck -x -o all -f gcc $(SHELL_SCRIPTS) || true
