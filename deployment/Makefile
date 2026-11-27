SHELL := /usr/bin/env bash
.SHELLFLAGS := -o pipefail -c
.DEFAULT_GOAL := setup-install-pre-requisites

include $(addprefix $(dir $(lastword $(MAKEFILE_LIST)))make/,setup.mk certs.mk k3s.mk charts.mk)

.PHONY: help

# Use the first comment in each included file as its help section heading.
help: ## Show deployment commands
	@printf '%s\n' 'Deployment commands'
	@awk -F ':.*## ' ' \
		FNR == 1 && /^# / { labels[++count] = substr($$0, 3); next } \
		NF == 2 && $$1 ~ /^[[:alnum:]_-]+$$/ { \
			labels[++count] = $$1; descriptions[count] = $$2; \
			if (length($$1) > width) width = length($$1); \
		} \
		END { \
			for (i = 1; i <= count; i++) { \
				if (i in descriptions) printf "  %-*s  %s\n", width, labels[i], descriptions[i]; \
				else printf "\n%s\n", labels[i]; \
			} \
		}' $(MAKEFILE_LIST)
	@printf '\n%s\n  %s\n' 'Remote setup example' \
		'make setup-k3s-cluster-remote NODES="admin@server1 admin@server2 admin@server3"'
