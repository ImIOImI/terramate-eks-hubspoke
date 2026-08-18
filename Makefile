.PHONY: generate stacks check-ids check validate lint
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
