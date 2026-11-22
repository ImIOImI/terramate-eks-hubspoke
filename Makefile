.PHONY: generate stacks check-ids check validate lint apply ci-up ci-kubeconfig ci-apply ci-hub-apply ci-test ci-argo ci-down compat
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
# Orchestration is the `deploy` Terramate script (scripts.tm.hcl): Terramate
# walks the stack graph (bootstrap -> network -> cluster -> nodes ->
# provisioning, spokes after their hub) and runs init + apply per stack, which
# is what outputs-sharing needs. These targets are just short aliases.
#
# Real-AWS envs run on your ambient admin creds: bootstrap creates the deploy
# role, trusts your caller, and its gate waits until it's assumable before the
# eks tiers assume it. Local (MiniStack) stacks also start MiniStack and pull
# each k3s cluster's certs + IP into .ministack/ (see scripts.tm.hcl).
apply:           ## stand up one environment: make apply ENV=<id>
	$(if $(ENV),,$(error usage: make apply ENV=<id>  (e.g. dev, ci-hub)))
	terramate script run --tags env-$(ENV) deploy

# ── local MiniStack fabric (one endpoint shared by every local env) ─────────
# ci-up/ci-down manage the single MiniStack container. CI_HUB_CLUSTER is the hub
# cluster name for the standalone ci-kubeconfig convenience target.
CI_HUB_CLUSTER ?= tmhs-eks-ci-hub

ci-up:           ## start MiniStack (docker socket mounted; required for EKS/k3s)
	./make/ci-up.sh

ci-kubeconfig:   ## extract k3s admin certs for the ci-hub cluster into .ministack/
	./make/ci-kubeconfig.sh $(CI_HUB_CLUSTER)

ci-apply:        ## every local env (ci-hub + ci-dev + ci-prd), test the apps, print the ArgoCD URL
	terramate script run --tags local deploy
	terramate script run ci test
	terramate script run ci argo

ci-hub-apply:    ## just the local hub (make apply ENV=ci-hub)
	terramate script run --tags env-ci-hub deploy

ci-test:         ## wait for the hub to sync + heal the demo apps on every local spoke
	terramate script run ci test

ci-argo:         ## print the local hub's ArgoCD URL + admin password
	terramate script run ci argo

ci-down:         ## tear the whole local fabric down (hub + any spoke)
	docker rm -f $$(docker ps -aq --filter "name=ministack") 2>/dev/null || true
	rm -rf .ministack

# ── toolchain compatibility ─────────────────────────────────────────────────
# Test one terramate/tofu/aws combination in a throwaway worktree of HEAD.
# MODE=validate (default) checks every non-local stack; MODE=apply runs the full
# ci-hub chain on MiniStack. Tested ranges: docs/TOOLCHAIN.md.
compat:          ## make compat TM=0.17.4 TOFU=1.13.9 AWS=6.73.0 [MODE=apply]
	TM=$(TM) TOFU=$(TOFU) AWS=$(AWS) MODE=$(or $(MODE),validate) ./make/compat.sh
