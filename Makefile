.PHONY: init plan apply inventory host guests

# Load backend creds + TF_VAR_* secrets, then run tofu against the terraform dir.
TOFU = set -a && . terraform/.env.sh && set +a && tofu -chdir=terraform

init:
	$(TOFU) init

plan:
	$(TOFU) plan

apply:
	$(TOFU) apply

inventory:
	./scripts/tf-to-inventory.sh

host: inventory
	cd ansible && ansible-playbook playbooks/host.yml --ask-vault-pass

guests: inventory
	cd ansible && ansible-playbook playbooks/guests.yml --ask-vault-pass
