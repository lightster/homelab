.PHONY: init plan apply inventory host guests

TOFU = set -a && . terraform/.env.sh && set +a && cd terraform && tofu
ANSIBLE = set -a && . ansible/.env.sh && set +a && cd ansible && ansible-playbook

init:
	$(TOFU) init

plan:
	$(TOFU) plan

apply:
	$(TOFU) apply

inventory:
	./scripts/tf-to-inventory.sh

host: inventory
	$(ANSIBLE) playbooks/host.yml

guests: inventory
	$(ANSIBLE) playbooks/guests.yml
