ONESHELL:
.SHELL := /usr/bin/sh
VARS=vars/$(ENV_REGION)/$(WORKSPACE).tfvars
S3_BUCKET=$(ENV)-app-tf-state-bucket
DYNAMODB_TABLE=$(ENV)-app-tf-state-locking
REGION=$(ENV_REGION)
APPLICATION=test
BOLD=$(shell tput bold)
RED=$(shell tput setaf 1)
GREEN=$(shell tput setaf 2)
YELLOW=$(shell tput setaf 3)
RESET=$(shell tput sgr0)


set-env:
	@if [ -z $(ENV) ]; then \
		echo "$(BOLD)$(RED)ENV was not set$(RESET)"; \
		exit 1; \
	 fi
	@if [ -z $(ENV_REGION) ]; then \
		echo "$(BOLD)$(RED)ENV_REGION was not set$(RESET)"; \
		exit 1; \
	 fi
	@if [ ! -f "$(VARS)" ]; then \
		echo "$(BOLD)$(RED)Could not find variables file: $(VARS)$(RESET)"; \
		exit 1; \
	fi
	 @if [ -z $(WORKSPACE) ]; then \
		echo "$(BOLD)$(RED)WORKSPACE was not set$(RESET)"; \
		exit 1; \
	 fi
prepare-backend: set-env	## Prepare a new workspace (environment) if needed, configure the tfstate backend, update any modules, and switch to the workspace
	@rm -rf .terraform; \
	echo "$(BOLD) Creating new bucket with versioning enabled to store tfstate$(RESET)"; \
	aws-vault exec ${ENV} -- aws s3api  \
		create-bucket \
		--bucket $(S3_BUCKET) \
		--acl private \
		--region $(REGION) \
		--create-bucket-configuration LocationConstraint="$(REGION)"; \
	aws-vault exec ${ENV} -- aws  s3api  \
		put-bucket-versioning \
		--bucket $(S3_BUCKET) \
		--versioning-configuration Status=Enabled; \
	echo "$(BOLD)$(YELLOW)S3 bucket $(S3_BUCKET) created$(RESET)"; \
	sed 's/\[\[BUCKET-NAME\]\]/$(S3_BUCKET)/g' terraform_tf_state_s3_policy_template.json > .terraform_tf_state_s3_policy.json; \
	echo "$(BOLD)$(YELLOW)S3 policy for $(S3_BUCKET) bucket created$(RESET)"; \
	aws-vault exec ${ENV} -- aws  s3api put-bucket-policy --bucket $(S3_BUCKET)  --policy file://.terraform_tf_state_s3_policy.json; \
	sleep 2; \
	echo "$(BOLD)$(YELLOW)S3 policy for $(S3_BUCKET) applied$(RESET)"; \
	aws-vault exec ${ENV} -- aws  s3api put-bucket-encryption --bucket $(S3_BUCKET) --server-side-encryption-configuration '{    "Rules": [      {        "ApplyServerSideEncryptionByDefault": {          "SSEAlgorithm": "aws:kms"      }      }    ]}'; \
	echo "$(BOLD)$(YELLOW)S3 encryption $(S3_BUCKET) applied$(RESET)"; \
	aws-vault exec ${ENV} -- aws  s3api put-public-access-block --bucket $(S3_BUCKET) --public-access-block-configuration "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"; \
	echo "$(BOLD)$(YELLOW)S3 block public access $(S3_BUCKET) applied$(RESET)"; \

	@echo "$(BOLD)Create DynamoDB Table for lock state$(RESET)"; \
	aws-vault exec ${ENV} -- aws dynamodb  create-table \
		--region $(REGION) \
		--table-name $(DYNAMODB_TABLE) \
		--attribute-definitions AttributeName=LockID,AttributeType=S \
		--key-schema AttributeName=LockID,KeyType=HASH \
		--provisioned-throughput ReadCapacityUnits=1,WriteCapacityUnits=1; \
	echo "$(BOLD)$(YELLOW)DynamoDB table $(DYNAMODB_TABLE) created$(RESET)"; \
	echo "Sleeping for 10 seconds to allow DynamoDB state to propagate through AWS"; \
	sleep 10; \
	echo "$(BOLD)Configuring the terraform backend$(RESET)" ;\

init: set-env ## Init backend
	aws-vault exec ${ENV} -- terraform init \
		-backend=true \
		-reconfigure \
		-backend-config="region=$(REGION)" \
		-backend-config="bucket=$(S3_BUCKET)" \
		-backend-config="key=$(WORKSPACE)/state.tfstate" \
		-backend-config="dynamodb_table=$(DYNAMODB_TABLE)"\
		-backend-config="acl=private";
	echo "$(BOLD)Switching to workspace $(WORKSPACE)$(RESET)"; \
	aws-vault exec $(ENV) -- terraform workspace select $(WORKSPACE) || aws-vault exec $(ENV) -- terraform workspace new $(WORKSPACE);
plan: init ## Run terraform plan
	@echo "$(BOLD)Run terraform plan for $(ENV) environment and $(WORKSPACE) workspace$(RESET)"; \
	terraform validate;\
	terraform get; \
	aws-vault exec $(ENV) -- terraform plan \
		-lock=true \
		-input=false \
		-refresh=true \
		-var-file="$(VARS)" \
		-var-file="vars/global.tfvars" \
		-out=tfplan;

plan-target: init
	@read -p "PLAN target: " DATA && \
	aws-vault exec ${ENV} -- terraform plan \
			-lock=true \
			-input=true \
			-refresh=true \
			-var-file="$(VARS)" \
			-var-file="vars/global.tfvars" \
			-out=tfplan \
			-target=$$DATA
apply:
	@aws-vault exec ${ENV} -- terraform apply \
            -lock=true \
            -input=true \
            -refresh=true \
            tfplan;

destroy:
	@aws-vault exec ${ENV} -- terraform destroy \
		-lock=true \
		-input=true \
		-refresh=true \
		-var-file="$(VARS)" \
		-var-file="vars/global.tfvars"