.PHONY: generate stacks check-ids check validate lint ci-up ci-kubeconfig ci-hub-apply ci-down
stacks:          ## seed each stack.tm.hcl with its derived id (run before first generate)
	./make/create-stacks.sh

check-ids:       ## fail if any stack.tm.hcl id has drifted from its derived value
	./make/create-stacks.sh --check

generate: ## two passes: object-layer _tmgen inputs, then bundle stacks
	terramate generate
	terramate generate

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

# ── local MiniStack fabric (one endpoint shared by every local env) ─────────
# ci-up/ci-down manage the single MiniStack container; the per-env apply chains
# (ci-hub-apply now, a future ci-spoke-apply) run inside it. CI_HUB_CLUSTER is
# the hub cluster name — a spoke would add its own CI_SPOKE_CLUSTER.
CI_HUB_CLUSTER ?= tmhs-eks-ci-hub

ci-up:           ## start MiniStack (docker socket mounted; required for EKS/k3s)
	./make/ci-up.sh

ci-kubeconfig:   ## extract k3s admin certs for the ci-hub cluster into .ministack/
	./make/ci-kubeconfig.sh $(CI_HUB_CLUSTER)

# Tier by tier, not one sweep: outputs-sharing cannot resolve a producer's
# outputs until that producer is applied, so `tofu init` on the whole env fails
# up front. ci-kubeconfig has to land between cluster and nodes -- it needs the
# k3s container that the cluster stack creates.
TM_CI = terramate run --enable-sharing --tags
ci-hub-apply: ci-up  ## full local hub run: bootstrap -> network -> cluster -> nodes -> provisioning
	cd stacks/aws/ci-hub/bootstrap && tofu init && tofu apply -auto-approve
	$(TM_CI) env-ci-hub:network      -- tofu init
	$(TM_CI) env-ci-hub:network      -- tofu apply -auto-approve
	$(TM_CI) env-ci-hub:cluster      -- tofu init
	$(TM_CI) env-ci-hub:cluster      -- tofu apply -auto-approve
	$(MAKE) ci-kubeconfig
	$(TM_CI) env-ci-hub:nodes        -- tofu init
	$(TM_CI) env-ci-hub:nodes        -- tofu apply -auto-approve
	$(TM_CI) env-ci-hub:provisioning -- tofu init
	$(TM_CI) env-ci-hub:provisioning -- tofu apply -auto-approve
	@echo "ci-hub up: kubectl --kubeconfig <(make -s ci-kubeconfig) or see BOOTSTRAPPING.md"

ci-down:         ## tear the whole local fabric down (hub + any spoke)
	docker rm -f $$(docker ps -aq --filter "name=ministack") 2>/dev/null || true
	rm -rf .ministack
