BINARY    := godot-editor-console-mcp
BUILD     := build
VERSION   ?= $(shell git describe --tags --always --dirty 2>/dev/null || echo dev)
LDFLAGS   := -s -w -X main.version=$(VERSION)
PLATFORMS := darwin/arm64 darwin/amd64 linux/amd64 linux/arm64 windows/amd64

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

# Build all targets, then archive each as build/<binary>-<os>-<arch>.<ext>.
#
# Names are deliberately version-less so install.sh can use GitHub's
# /releases/latest/download/<name> redirect and skip the API (no JSON parsing,
# no unauthenticated rate limit). The release tag carries the version, and the
# binary reports its own via `godot-editor-console-mcp version`.
#
# tar.gz on unix so the installer can stream straight into place
# (`curl ... | tar -xz`); unzip can't read stdin. zip on Windows.
package: all
	@for p in $(PLATFORMS); do \
	  os=$${p%/*}; arch=$${p#*/}; \
	  stem=$(BINARY)-$$os-$$arch; \
	  if [ "$$os" = "windows" ]; then \
	    echo "packaging $$stem.zip"; \
	    ( cd $(BUILD)/$$os-$$arch && rm -f ../$$stem.zip && zip -j -q ../$$stem.zip $(BINARY).exe ); \
	  else \
	    echo "packaging $$stem.tar.gz"; \
	    ( cd $(BUILD)/$$os-$$arch && rm -f ../$$stem.tar.gz && tar -czf ../$$stem.tar.gz $(BINARY) ); \
	  fi; \
	done; \
	echo "done -> $(BUILD)/$(BINARY)-*.{tar.gz,zip}"

clean:
	rm -rf $(BUILD)
