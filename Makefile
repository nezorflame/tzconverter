MODULE:=github.com/nezorflame/tzconverter
PKG_LIST:=$(shell go list -f '{{.Dir}}' ./...)
GIT_HASH?=$(shell git log --format="%h" -n 1 2> /dev/null)
GIT_BRANCH?=$(shell git branch 2> /dev/null | grep '*' | cut -f2 -d' ')
GIT_TAG:=$(shell git describe --exact-match --abbrev=0 --tags 2> /dev/null)
APP_VERSION?=$(if $(GIT_TAG),$(GIT_TAG),$(shell git describe --all --long HEAD 2> /dev/null))
GO_VERSION:=$(shell go version)
GO_VERSION_SHORT:=$(shell echo $(GO_VERSION)|sed -E 's/.* go(.*) .*/\1/g')

export GO111MODULE=on
export GOPROXY=https://proxy.golang.org
BUILD_ENVPARMS:=CGO_ENABLED=0
BUILD_TS:=$(shell date +%FT%T%z)

PWD:=$(PWD)
export PATH:=$(PWD)/bin:$(PATH)

# install project dependencies
.PHONY: deps
deps:
	$(info #Installing dependencies...)
	go mod tidy

.PHONY: update
update:
	$(info #Updating dependencies...)
	go get -d -mod= -u

.PHONY: generate
generate:
	$(info #Generating code...)
	go generate ./...

.PHONY: refresh
refresh: tools deps generate format

# run all tests
.PHONY: test
test: deps
	$(info #Running tests...)
	go test -v -race ./...

# run all tests with coverage
.PHONY: test-cover
test-cover: deps
	$(info #Running tests with coverage...)
	go test -v -coverprofile=coverage.out -race $(PKG_LIST)
	go tool cover -func=coverage.out | grep total
	rm -f coverage.out
	
.PHONY: fast-build
fast-build: deps 
	$(info #Building binaries...)
	$(shell $(BUILD_ENVPARMS) go build -o bin/tzconverter ./cmd/tzconverter)
	@echo

.PHONY: build
build: fast-build test

.PHONY: install
install: deps
	$(info #Installing binaries...)
	$(shell $(BUILD_ENVPARMS) go install ./cmd/tzconverter)
	@echo

# install tools binary: linter, mockgen, etc.
.PHONY: tools
tools:
	$(info #Installing tools...)
	cd tools && go mod tidy && go generate -tags tools

# run linter
.PHONY: lint
lint:
	$(info #Running lint...)
	golangci-lint run ./...

.PHONY: format
format:
	$(info #Formatting code through golangci-lint...)
	golangci-lint run --fix ./...
