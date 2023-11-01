CMD:=tzconverter
MODULE:=github.com/nezorflame/$(CMD)
PKG_LIST:=$(shell go list -f '{{.Dir}}' ./...)
GIT_HASH?=$(shell git log --format="%h" -n 1 2> /dev/null)
GIT_TAG:=$(shell git describe --exact-match --abbrev=0 --tags 2> /dev/null)
APP_VERSION?=$(if $(GIT_TAG),$(GIT_TAG),$(shell git describe --all --long HEAD 2> /dev/null))
GO_VERSION:=$(shell go version)
GO_VERSION_SHORT:=$(shell echo $(GO_VERSION)|sed -E 's/.* go(.*) .*/\1/g')

export GO111MODULE=on
export GOPROXY=https://proxy.golang.org
BUILD_ENVPARMS:=CGO_ENABLED=0
BUILD_TS:=$(shell date +%FT%T%z)
PLATFORMS:=darwin linux windows
ARCHITECTURES:=386 amd64 arm arm64

# Setup linker flags option for build that interoperate with variable names in src code
LDFLAGS=-ldflags "-X main.Version=${APP_VERSION} -X main.Build=${GIT_HASH}"

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
	
.PHONY: build
build: deps 
	$(info #Building binaries...)
	$(shell $(BUILD_ENVPARMS) go build -o bin/$(CMD) ./cmd/$(CMD))
	@echo

.PHONY: build-all
build-all:
	$(foreach GOOS, $(PLATFORMS),\
	$(foreach GOARCH, $(ARCHITECTURES), $(shell export GOOS=$(GOOS); export GOARCH=$(GOARCH); go build -o bin/$(CMD)-$(GOOS)-$(GOARCH) ./cmd/$(CMD))))
	$(foreach GOARCH, $(ARCHITECTURES), $(shell mv bin/$(CMD)-windows-$(GOARCH) bin/$(CMD)-windows-$(GOARCH).exe))
	@echo

.PHONY: install
install: deps
	$(info #Installing binaries...)
	$(shell $(BUILD_ENVPARMS) go install ./cmd/$(CMD))
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
