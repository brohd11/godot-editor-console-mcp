BINARY    := godot-editor-console-mcp
BUILD     := build
VERSION   ?= $(shell git describe --tags --always --dirty 2>/dev/null || echo dev)
LDFLAGS   := -s -w -X main.version=$(VERSION)
PLATFORMS := darwin/arm64 linux/amd64 windows/amd64

.PHONY: build all clean package $(PLATFORMS)

# Host build -> build/<host-os>-<host-arch>/godot-editor-console-mcp
build:
	go build -ldflags '$(LDFLAGS)' \
	  -o $(BUILD)/$(shell go env GOOS)-$(shell go env GOARCH)/$(BINARY) .

# Cross-compile every target in one shot
all: $(PLATFORMS)

$(PLATFORMS):
	@os=$(word 1,$(subst /, ,$@)); arch=$(word 2,$(subst /, ,$@)); \
	ext=$$( [ "$$os" = "windows" ] && echo .exe || echo ); \
	echo "building $$os/$$arch"; \
	GOOS=$$os GOARCH=$$arch CGO_ENABLED=0 \
	  go build -ldflags '$(LDFLAGS)' \
	  -o $(BUILD)/$$os-$$arch/$(BINARY)$$ext .

# Build all targets, then zip each into build/<binary>-<version>-<os>-<arch>.zip.
# -j junks paths so each archive contains only the simple-named executable.
package: all
	@for p in $(PLATFORMS); do \
	  os=$${p%/*}; arch=$${p#*/}; \
	  ext=$$( [ "$$os" = "windows" ] && echo .exe || echo ); \
	  zipname=$(BINARY)-$(VERSION)-$$os-$$arch.zip; \
	  echo "packaging $$zipname"; \
	  ( cd $(BUILD)/$$os-$$arch && rm -f ../$$zipname && zip -j -q ../$$zipname $(BINARY)$$ext ); \
	done; \
	echo "done -> $(BUILD)/*.zip"

clean:
	rm -rf $(BUILD)
