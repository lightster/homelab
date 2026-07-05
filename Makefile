.PHONY: init plan apply

TOFU = set -a && . terraform/.env.sh && set +a && cd terraform && tofu

init:
	$(TOFU) init

plan:
	$(TOFU) plan

apply:
	$(TOFU) apply
