.PHONY: data terraform-init terraform-validate terraform-plan terraform-apply clean

data:
	python3 scripts/generate_synthetic_data.py

terraform-init:
	cd infra/terraform && terraform init

terraform-validate:
	cd infra/terraform && terraform validate

terraform-plan:
	cd infra/terraform && terraform plan

terraform-apply:
	cd infra/terraform && terraform apply

clean:
	rm -rf outputs data/runtime
