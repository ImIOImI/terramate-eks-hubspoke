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
	trivy config --exit-code 1 .
