SHELL := /bin/bash
.SHELLFLAGS := -euo pipefail -c
.DEFAULT_GOAL := help

# ============================================================================
# Configuration
# ============================================================================

# Load environment variables
ifneq (,$(wildcard .env))
    include .env
    export $(shell grep -E '^[A-Z_]+=' .env | cut -d= -f1 | xargs)
endif

# Terraform directories
TERRAFORM_MAIN := infrastructure/environments-main
TERRAFORM_BOOTSTRAP := infrastructure/payment-bootstrap

# Lambda configuration
SRC_DIR := src
LAMBDA_INIT_DIR := $(SRC_DIR)/lambda-payments-initializer
LAMBDA_EXEC_DIR := $(SRC_DIR)/lambda-payments-executor
LAMBDA_PSP_DIR := $(SRC_DIR)/lambda-payments-psp
LAMBDA_WALLET_DIR := $(SRC_DIR)/lambda-payments-wallet
DOCKERFILE := $(SRC_DIR)/Dockerfiles/Dockerfile

# AWS configuration
AWS_REGION ?= eu-west-1
AWS_ACCOUNT_ID := $(shell grep ^ACCOUNT_ID= .env 2>/dev/null | cut -d= -f2)
PROJECT_PREFIX := o11y-lab
S3_BUCKET_NAME := $(PROJECT_PREFIX)-s3-bucket

# Build configuration
DOCKER_IMAGE := lambda-build
DOCKER_CONTAINER := lambda-build-container

# ============================================================================
# Help
# ============================================================================

.PHONY: help
help:  ## Show this help message
	@echo "===================================================================="
	@echo "  O11y Lab - Serverless Payments Deployment"
	@echo "===================================================================="
	@echo ""
	@echo "Usage: make <target>"
	@echo ""
	@awk 'BEGIN {FS = ":.*?##"} \
	/^##@/ {printf "\n%s\n", substr($$0, 5)} \
	/^[a-zA-Z0-9_-]+:.*?##/ {printf "  %-30s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

# ============================================================================
##@ 0. Prerequisites (One-time Setup)
# ============================================================================

.PHONY: check-aws
check-aws:  ## Check AWS CLI configuration
	@aws sts get-caller-identity > /dev/null && echo "AWS credentials OK"

.PHONY: create-state-bucket
create-state-bucket: check-aws  ## Create Terraform remote state S3 bucket
	@aws s3api create-bucket \
		--bucket $(PROJECT_PREFIX)-terraform-state \
		--region $(AWS_REGION) \
		--create-bucket-configuration LocationConstraint=$(AWS_REGION) 2>/dev/null || true
	@aws s3api put-bucket-versioning \
		--bucket $(PROJECT_PREFIX)-terraform-state \
		--versioning-configuration Status=Enabled
	@aws s3api put-bucket-encryption \
		--bucket $(PROJECT_PREFIX)-terraform-state \
		--server-side-encryption-configuration \
		'{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"},"BucketKeyEnabled":true}]}'

# ============================================================================
##@ 1. Terraform - Environments Main
# ============================================================================

.PHONY: init-main
init-main:  ## Initialize environments-main Terraform
	@terraform -chdir=$(TERRAFORM_MAIN) init

.PHONY: plan-main
plan-main:  ## Plan environments-main Terraform
	@terraform -chdir=$(TERRAFORM_MAIN) plan

.PHONY: apply-main
apply-main:  ## Apply environments-main Terraform
	@terraform -chdir=$(TERRAFORM_MAIN) apply

.PHONY: destroy-main
destroy-main:  ## Destroy environments-main Terraform
	@terraform -chdir=$(TERRAFORM_MAIN) destroy

# ============================================================================
##@ 2. Terraform - Payment Bootstrap
# ============================================================================

.PHONY: init-payments
init-payments:  ## Initialize payment-bootstrap Terraform
	@terraform -chdir=$(TERRAFORM_BOOTSTRAP) init

.PHONY: plan-payments
plan-payments:  ## Plan payment-bootstrap Terraform
	@terraform -chdir=$(TERRAFORM_BOOTSTRAP) plan

.PHONY: plan-payments-wallet
plan-payments-wallet:  ## Plan payment-bootstrap showing only wallet lambda and summary
	@terraform -chdir=$(TERRAFORM_BOOTSTRAP) plan 2>&1 | sed -n '/# module.lambda_wallet.aws_lambda_function.function/,/^$$/p; /^Plan:/p'

.PHONY: apply-payments
apply-payments:  ## Apply payment-bootstrap Terraform
	@terraform -chdir=$(TERRAFORM_BOOTSTRAP) apply

.PHONY: destroy-payments
destroy-payments:  ## Destroy payment-bootstrap Terraform
	@terraform -chdir=$(TERRAFORM_BOOTSTRAP) destroy

# ============================================================================
##@ INFRASTRUCTURE MANAGEMENT
# ============================================================================

.PHONY: deploy-infrastructure
deploy-infrastructure: check-aws  ## Deploy complete infrastructure (steps 0-2)
	@echo "Deploying infrastructure (state bucket, main, payments)..."
	@read -p "Continue? (yes/no): " confirm; \
	[ "$$confirm" = "yes" ] || exit 1
	@$(MAKE) create-state-bucket || true
	@$(MAKE) init-main && $(MAKE) plan-main && terraform -chdir=$(TERRAFORM_MAIN) apply --auto-approve
	@$(MAKE) init-payments && $(MAKE) plan-payments && terraform -chdir=$(TERRAFORM_BOOTSTRAP) apply --auto-approve
	@echo "Done."

##@ ==========================================================================
# ============================================================================
##@ Lambda deployment
# ============================================================================
# Lambda build/upload/update functions
define build_lambda
	@cd $(2) && \
	rm -rf package *.zip Dockerfile && \
	mkdir -p package && \
	cp ../Dockerfiles/Dockerfile Dockerfile && \
	docker build -t $(DOCKER_IMAGE) . && \
	docker create --name $(DOCKER_CONTAINER) $(DOCKER_IMAGE) && \
	docker cp $(DOCKER_CONTAINER):/out/. ./package && \
	docker rm $(DOCKER_CONTAINER) && \
	if [ -n "$$(ls -A package 2>/dev/null)" ]; then \
		cd package && zip -q -r ../$(PROJECT_PREFIX)-$(1).zip . && cd ..; \
	else \
		touch package/.keep && cd package && zip -q -r ../$(PROJECT_PREFIX)-$(1).zip .keep && rm .keep && cd ..; \
	fi && \
	zip -q $(PROJECT_PREFIX)-$(1).zip lambda.py && \
	rm -rf Dockerfile
endef

define upload_lambda
	@aws s3 cp $(2)/$(PROJECT_PREFIX)-$(1).zip s3://$(S3_BUCKET_NAME)/$(PROJECT_PREFIX)-$(1).zip
endef

define update_lambda
	@aws lambda update-function-code \
		--function-name $(PROJECT_PREFIX)-$(1) \
		--s3-bucket $(S3_BUCKET_NAME) \
		--s3-key $(PROJECT_PREFIX)-$(1).zip \
		--no-cli-pager
	@echo "Waiting for Lambda function update to complete..."
	@aws lambda wait function-updated --function-name $(PROJECT_PREFIX)-$(1)
	@echo "Publishing new Lambda version..."
	@publish_response=$$(aws lambda publish-version --function-name $(PROJECT_PREFIX)-$(1) --no-cli-pager 2>&1); \
	aws_version=$$(echo "$$publish_response" | jq -r '.Version // "1"' 2>/dev/null || echo "$$publish_response" | grep -o '"Version"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*"Version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/' | grep -o '[0-9]\+' | head -1 || echo "1"); \
	if [ -z "$$aws_version" ] || [ "$$aws_version" = "\$$LATEST" ] || [ "$$aws_version" = "LATEST" ]; then \
		echo "Warning: publish-version did not return a version number, checking published versions..."; \
		aws_version=$$(aws lambda list-versions-by-function --function-name $(PROJECT_PREFIX)-$(1) --query 'Versions[?Version!=`\$$LATEST`].Version' --output text 2>/dev/null | tr '\t' '\n' | grep -v '\$$LATEST' | sort -n | tail -1 || echo "1"); \
	fi; \
	if [ -z "$$aws_version" ] || [ "$$aws_version" = "\$$LATEST" ]; then \
		aws_version="1"; \
	fi; \
	semantic_version=$$(printf "0.0.%d\n" $$aws_version); \
	echo "Lambda function $(PROJECT_PREFIX)-$(1) updated to version $$semantic_version (AWS version: $$aws_version)"; \
	echo "Sending SDLC event to Dynatrace..."; \
	./send_sdlc_event.sh $(PROJECT_PREFIX)-$(1) $$semantic_version || echo "Warning: Failed to send SDLC event"
endef

# Individual Lambda targets
.PHONY: build-lambda-initializer
build-lambda-initializer:  ## Build lambda-payments-initializer
	$(call build_lambda,lambda-payments-initializer,$(LAMBDA_INIT_DIR))

.PHONY: build-lambda-executor
build-lambda-executor:  ## Build lambda-payments-executor
	$(call build_lambda,lambda-payments-executor,$(LAMBDA_EXEC_DIR))

.PHONY: build-lambda-psp
build-lambda-psp:  ## Build lambda-payments-psp
	$(call build_lambda,lambda-payments-psp,$(LAMBDA_PSP_DIR))

.PHONY: build-lambda-wallet
build-lambda-wallet:  ## Build lambda-payments-wallet
	$(call build_lambda,lambda-payments-wallet,$(LAMBDA_WALLET_DIR))

.PHONY: upload-lambda-initializer
upload-lambda-initializer:  ## Upload lambda-payments-initializer to S3
	$(call upload_lambda,lambda-payments-initializer,$(LAMBDA_INIT_DIR))

.PHONY: upload-lambda-executor
upload-lambda-executor:  ## Upload lambda-payments-executor to S3
	$(call upload_lambda,lambda-payments-executor,$(LAMBDA_EXEC_DIR))

.PHONY: upload-lambda-psp
upload-lambda-psp:  ## Upload lambda-payments-psp to S3
	$(call upload_lambda,lambda-payments-psp,$(LAMBDA_PSP_DIR))

.PHONY: upload-lambda-wallet
upload-lambda-wallet:  ## Upload lambda-payments-wallet to S3
	$(call upload_lambda,lambda-payments-wallet,$(LAMBDA_WALLET_DIR))

.PHONY: update-lambda-initializer
update-lambda-initializer: build-lambda-initializer upload-lambda-initializer  ## Update deployed lambda-payments-initializer
	$(call update_lambda,lambda-payments-initializer)

.PHONY: update-lambda-executor
update-lambda-executor: build-lambda-executor upload-lambda-executor  ## Update deployed lambda-payments-executor
	$(call update_lambda,lambda-payments-executor)

.PHONY: update-lambda-psp
update-lambda-psp: build-lambda-psp upload-lambda-psp  ## Update deployed lambda-payments-psp
	$(call update_lambda,lambda-payments-psp)

.PHONY: update-lambda-wallet
update-lambda-wallet: build-lambda-wallet upload-lambda-wallet  ## Update deployed lambda-payments-wallet
	$(call update_lambda,lambda-payments-wallet)

# Combined targets
.PHONY: build-all-lambdas
build-all-lambdas: build-lambda-initializer build-lambda-executor build-lambda-psp build-lambda-wallet  ## Build all Lambda functions

.PHONY: upload-all-lambdas
upload-all-lambdas: upload-lambda-initializer upload-lambda-executor upload-lambda-psp upload-lambda-wallet  ## Upload all Lambda functions to S3

.PHONY: package-all-lambdas
package-all-lambdas: build-all-lambdas upload-all-lambdas  ## Build and upload all Lambda functions

.PHONY: update-all-lambdas
update-all-lambdas: update-lambda-initializer update-lambda-executor update-lambda-psp update-lambda-wallet  ## Update all deployed Lambda functions

##@ ==========================================================================
# ============================================================================
##@ COMPLETE STACK DEPLOYMENT
# ============================================================================

.PHONY: deploy-full-stack
deploy-full-stack: check-aws  ## Deploy complete stack from scratch
	@echo "Deploying full stack..."
	@$(MAKE) init-main && terraform -chdir=$(TERRAFORM_MAIN) apply --auto-approve
	@$(MAKE) package-all-lambdas
	@$(MAKE) init-payments && terraform -chdir=$(TERRAFORM_BOOTSTRAP) apply --auto-approve
	@echo "Done."

.PHONY: destroy-full-stack
destroy-full-stack:  ## Destroy complete stack
	@echo "WARNING: This will destroy ALL infrastructure!"
	@read -p "Type 'yes' to continue: " confirm; \
	[ "$$confirm" = "yes" ] || exit 1
	@terraform -chdir=$(TERRAFORM_BOOTSTRAP) destroy --auto-approve
	@terraform -chdir=$(TERRAFORM_MAIN) destroy --auto-approve
	@echo "Done."

# ============================================================================
##@ UTILITIES
# ============================================================================

.PHONY: validate-terraform
validate-terraform:  ## Validate all Terraform configurations
	@terraform -chdir=$(TERRAFORM_MAIN) validate
	@terraform -chdir=$(TERRAFORM_BOOTSTRAP) validate

.PHONY: format-terraform
format-terraform:  ## Format all Terraform files
	@terraform -chdir=$(TERRAFORM_MAIN) fmt -recursive
	@terraform -chdir=$(TERRAFORM_BOOTSTRAP) fmt -recursive

.PHONY: clean
clean:  ## Clean build artifacts
	@find $(SRC_DIR) -type f -name '*.zip' -delete
	@find $(SRC_DIR) -type f -name '*.pyc' -delete
	@find $(SRC_DIR) -type d -name '__pycache__' -exec rm -rf {} + 2>/dev/null || true
	@find $(SRC_DIR) -type d -name 'package' -exec rm -rf {} + 2>/dev/null || true
	@find $(SRC_DIR) -type f -name 'Dockerfile' -not -path '*/Dockerfiles/*' -delete

.PHONY: clean-docker
clean-docker:  ## Clean Docker images and containers
	@docker ps -a | grep $(DOCKER_CONTAINER) | awk '{print $$1}' | xargs docker rm -f 2>/dev/null || true
	@docker images | grep $(DOCKER_IMAGE) | awk '{print $$3}' | xargs docker rmi -f 2>/dev/null || true

.PHONY: nuke
nuke: check-aws  ## Nuke entire AWS account
	@echo "WARNING: This will DELETE ALL resources in your AWS account!"
	@read -p "Are you sure you want to continue? (yes/no): " confirm; \
	[ "$$confirm" = "yes" ] || exit 1
	@aws-nuke run --config infrastructure/nuke-config.yml --force --no-dry-run
