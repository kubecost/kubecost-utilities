# List every *.sh script in the repo, skipping the .git directory.
SHELL_SCRIPTS := $(shell find . -type f -name '*.sh' -not -path './.git/*')

.PHONY: shellcheck
shellcheck:
	@echo "🔍  Running shellcheck on $(words $(SHELL_SCRIPTS)) script(s)…"
	@# -x follows sourced files; -o all enables all optional warnings
	@shellcheck -x -o all $(SHELL_SCRIPTS)
