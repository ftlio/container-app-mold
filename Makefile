# This directory
base_dir :=$(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))

# Load Configuration from .env files
# Build
ifneq ("$(wildcard ./conf-build.env)", "")
	cnf ?= conf-build.env
	include $(cnf)
	export $(shell sed 's/=.*//' $(cnf))
endif

# App
ifneq ("$(wildcard ./conf-app.env)", "")
	app_cnf ?= conf-app.env
	include $(app_cnf)
	export $(shell sed 's/=.*//' $(app_cnf))
endif

# Dev
ifneq ("$(wildcard ./conf-dev.env)", "")
	dev_cnf ?= conf-dev.env
	include $(dev_cnf)
	export $(shell sed 's/=.*//' $(dev_cnf))
endif


# Shorthand args, defaults
stage ?= app
tag ?= $(shell whoami)-dev
BUILD_STAGE ?= $(stage)
BUILD_TAG ?= $(tag)
BUILD_REPOSITORY ?= local
BUILD_IMAGE ?= $(BUILD_REPOSITORY):$(BUILD_TAG)
LOCAL_IMAGE ?= $(notdir $(base_dir)):$(BUILD_TAG)
LOCAL_CONTAINER ?= $(notdir $(base_dir))
LOCAL_MNT ?= local_mnt

# Misc Build / Run Config
DOCKER_FILE ?= Dockerfile
DOCKER_CONTEXT ?= app
LOCAL_BUILDS ?= $(DOCKER_CONTEXT)/local_build

# Docker Run Args
DOCKER_RUN_ARGS ?= \
	-it --rm \
	--name="$(LOCAL_CONTAINER)" \
	--env-file=conf-app.env \
	-v "$(base_dir)/$(LOCAL_MNT_DATA):$(APP_MNT_EXAMPLE)" \
	-p "$(APP_PORT_EXAMPLE):$(LOCAL_PORT_EXAMPLE)" \

# Dev Docker Run Args
DEV_RUN_ARGS ?= \

# Dev Run Command
DEV_RUN_CMD ?= /bin/sh

# Docker Build Args
DOCKER_BUILD_ARGS ?= \
	-f $(DOCKER_FILE) \
	$(DOCKER_CONTEXT)

# Docker Build Targets
default: build run

.PHONY: build
build: local-builds
	@echo Building $(LOCAL_IMAGE)
	@docker build -t $(LOCAL_IMAGE) \
		$(DOCKER_BUILD_ARGS)

.PHONY: build-clean
build-clean: local-builds
	@echo Building without cache $(LOCAL_IMAGE)
	@docker build -t $(LOCAL_IMAGE) \
		--no-cache \
		$(DOCKER_BUILD_ARGS)

.PHONY: build-$(BUILD_STAGE)
build-$(BUILD_STAGE): local-builds
	@echo Building $(LOCAL_IMAGE)-$(BUILD_STAGE)
	@docker build \
		-t $(LOCAL_IMAGE)-$(BUILD_STAGE) \
		--target $(BUILD_STAGE) \
		$(DOCKER_BUILD_ARGS)

# Docker Run Targets
run: local-resources
	@echo Running $(LOCAL_IMAGE)
	@docker run \
		$(DOCKER_RUN_ARGS) \
		$(LOCAL_IMAGE)

run-dev: local-resources
	@echo Running development mode - $(LOCAL_IMAGE)
	@docker run \
		$(DOCKER_RUN_ARGS) \
		$(DEV_RUN_ARGS) \
		$(LOCAL_IMAGE) \
		$(DEV_RUN_CMD)

run-$(BUILD_STAGE): local-resources
	@echo Running $(LOCAL_IMAGE)-$(BUILD_STAGE)
	@docker run \
		$(DOCKER_RUN_ARGS) \
		$(DEV_RUN_ARGS) \
		$(LOCAL_IMAGE)-$(BUILD_STAGE) \
		$(DEV_RUN_CMD)

# Push, Deploy, Misc.
.PHONY: push
push: repo-login
	@echo Pushing $(LOCAL_IMAGE) to $(BUILD_IMAGE)
	@docker tag $(LOCAL_IMAGE) $(BUILD_IMAGE)
	@docker push $(BUILD_IMAGE)

.PHONY: repo-login
repo-login:
ifdef $(BUILD_AWS_PROFILE)
	@eval `aws ecr --profile $(BUILD_AWS_PROFILE) get-login --no-include-email`
endif

# Init
init: init-conf
	@$(MAKE) init-local

# Init Conf
init-conf: conf-build.env conf-app.env conf-dev.env Dockerfile
default.conf-build.env default.conf-app.env default.conf-dev.env:
	echo "" > $@

conf-%.env: \
	default.conf-build.env \
	default.conf-app.env \
	default.conf-dev.env
		@echo "Copying default.$@ to $@"
		@cp default.$@ $@

# Init
init-local: local-builds local-resources

# Host-built or downloadable assets
# that are convenient not to handle in Docker
local-builds: \
	$(LOCAL_BUILDS) \
	$(LOCAL_BUILDS)/.gitignore

$(LOCAL_BUILDS):
	mkdir -p $(LOCAL_BUILDS)

# Example Local Built Item
$(LOCAL_BUILDS)/.gitignore:
	echo "*" > $@


# Local resources
local-resources: \
	$(LOCAL_MNT)/ \
	$(LOCAL_MNT_DATA)	\
	$(LOCAL_MNT)/.gitignore \

$(LOCAL_MNT) $(LOCAL_MNT)/%:
	mkdir -p $@

$(LOCAL_MNT)/.gitignore:
	echo "*" > $@



# TODO - Add clean-docker to try and track down images, containers, etc
clean:
	@rm -rf $(LOCAL_BUILDS)
	@rm -rf $(LOCAL_MNT)
	@rm conf-*.env
