BINARY    := editor-console-mcp
BUILD     := build
LDFLAGS   := -s -w
PLATFORMS := darwin/arm64 darwin/amd64 linux/amd64 linux/arm64 windows/amd64

.PHONY: build all clean $(PLATFORMS)

# Host build -> build/<host-os>-<host-arch>/editor-console-mcp
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

clean:
	rm -rf $(BUILD)
