.PHONY: generate stacks check-ids check validate lint apply ci-up ci-kubeconfig ci-hub-apply ci-down
stacks:          ## seed each stack.tm.hcl with its derived id (run before first generate)
	./make/create-stacks.sh

check-ids:       ## fail if any stack.tm.hcl id has drifted from its derived value
	./make/create-stacks.sh --check

generate: ## self-bootstrapping two-pass codegen (seeds the account map for new/renamed envs)
	./make/generate.sh

check: check-ids generate
	git diff --exit-code --stat -- . ':!docs'

validate:
	terramate run -- tofu init -backend=false
	terramate run -- tofu validate

lint:
	tofu fmt -check -recursive
	tflint --recursive
	# skip .terraform: downloaded upstream modules ship example k8s manifests
	# that trip the k8s scanner; we scan our own stacks (module refs still analyzed)
	trivy config --exit-code 1 --skip-dirs "**/.terraform/**" .

# ── one-command apply ───────────────────────────────────────────────────────
# `make apply ENV=<id>` stands an environment up end to end, tier by tier
# (bootstrap -> network -> cluster -> nodes -> provisioning). Real-AWS envs run on
# your ambient admin creds: bootstrap creates the deploy role, trusts your caller,
# and its gate waits until it's assumable before the eks tiers assume it. Local
# (MiniStack) envs bring MiniStack up and extract the k3s cert automatically.
apply:           ## stand up one environment: make apply ENV=<id>
	./make/apply.sh $(ENV)

# ── local MiniStack fabric (one endpoint shared by every local env) ─────────
# ci-up/ci-down manage the single MiniStack container. CI_HUB_CLUSTER is the hub
# cluster name for the standalone ci-kubeconfig convenience target.
CI_HUB_CLUSTER ?= tmhs-eks-ci-hub

ci-up:           ## start MiniStack (docker socket mounted; required for EKS/k3s)
	./make/ci-up.sh

ci-kubeconfig:   ## extract k3s admin certs for the ci-hub cluster into .ministack/
	./make/ci-kubeconfig.sh $(CI_HUB_CLUSTER)

ci-hub-apply:    ## alias for `make apply ENV=ci-hub` (local MiniStack hub)
	./make/apply.sh ci-hub

ci-down:         ## tear the whole local fabric down (hub + any spoke)
	docker rm -f $$(docker ps -aq --filter "name=ministack") 2>/dev/null || true
	rm -rf .ministack
