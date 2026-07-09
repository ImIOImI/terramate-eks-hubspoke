.PHONY: generate check validate lint
generate:        ## two passes: object-layer _tmgen inputs, then bundle stacks
	terramate generate
	terramate generate

check: generate
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
