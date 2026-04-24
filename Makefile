.PHONY: data test local terraform-init terraform-plan terraform-apply clean

data:
	python3 scripts/generate_synthetic_data.py

test:
	python3 -m pytest -q

local:
	streamlit run app/streamlit/app.py

terraform-init:
	cd infra/terraform && terraform init

terraform-plan:
	cd infra/terraform && terraform plan

terraform-apply:
	cd infra/terraform && terraform apply

clean:
	rm -rf .pytest_cache outputs data/runtime
