SHELL=/bin/bash
.SHELLFLAGS=-e

PROJECT         = github.com/pulumi/terraform-bridge
TFGEN           = lumi-tfgen
TFGEN_BIN       = ${GOPATH}/bin/${TFGEN}
TFGEN_PKG       = ${PROJECT}/cmd/${TFGEN}
TFBRIDGE        = lumi-tfbridge
TFBRIDGE_BIN    = ${GOPATH}/bin/${TFBRIDGE}
TFBRIDGE_PKG    = ${PROJECT}/cmd/${TFBRIDGE}
GOPKGS          = $(shell go list ./cmd/... ./pkg/... | grep -v /vendor/)
LUMIROOT       ?= /usr/local/lumi
LUMILIB         = ${LUMIROOT}/packs
LUMILIB_TF      = ${LUMILIB}/tf-
LUMILIB_TFPLUG  = lumi-resource-tf-
TESTPARALLELISM = 10

ECHO=echo -e
GOMETALINTERBIN=gometalinter
GOMETALINTER=${GOMETALINTERBIN} --config=Gometalinter.json

all: banner tools packs
.PHONY: all

banner:
	@$(ECHO) "\033[1;37m==================================\033[0m"
	@$(ECHO) "\033[1;37mLumi Terraform Bridge and Packages\033[0m"
	@$(ECHO) "\033[1;37m==================================\033[0m"
	@go version
.PHONY: banner

$(TFGEN_BIN):
	go install ${PROJECT}/cmd/lumi-tfgen
$(TFBRIDGE_BIN):
	go install ${PROJECT}/cmd/lumi-tfbridge
.PHONY: $(TFGEN_BIN) $(TFBRIDGE_BIN)

build: $(TFGEN_BIN) $(TFBRIDGE_BIN)
.PHONY: build

tools: build test
.PHONY: tools

test:
	go test -cover -parallel ${TESTPARALLELISM} ${GOPKGS}
	which ${GOMETALINTERBIN} >/dev/null
	$(GOMETALINTER) ./cmd/... ./pkg/... | sort ; exit "$${PIPESTATUS[0]}"
	go tool vet -printf=false cmd/ pkg/
.PHONY: test

gen:
	$(TFGEN) --out packs/
.PHONY: gen

BUILDPACKS=$(wildcard packs/*)
$(BUILDPACKS):
	$(eval PACK := $(notdir $@))
	@$(ECHO) "[Building ${PACK} package:]"
	cd packs/${PACK} && yarn link @lumi/lumi # ensure we resolve to Lumi's stdlib.
	cd packs/${PACK} && lumijs # compile the LumiPack.
	cd packs/${PACK} && lumi pack verify # ensure the pack verifies.
	$(eval INSTALLDIR := ${LUMILIB_TF}${PACK})
	@$(ECHO) "[Installing ${PACK} package to ${INSTALLDIR}:]"
	mkdir -p ${INSTALLDIR}
	cp -r packs/${PACK}/.lumi/bin/* ${INSTALLDIR}
	cp ${TFBRIDGE_BIN} ${INSTALLDIR}/${LUMILIB_TFPLUG}${PACK}
	cp packs/${PACK}/VERSION ${INSTALLDIR}
packs packs/: $(BUILDPACKS)
.PHONY: $(BUILDPACKS) packs packs/

clean: cleanpacks
	rm -rf ${GOPATH}/bin/${TFGEN}
	rm -rf ${GOPATH}/bin/${TFBRIDGE}
.PHONY: clean

cleanpacks: $(PACKS)
	rm -rf ${LUMILIB_TF}$(notdir $?)
