GITHUB_URL := https://github.com/intitni/CopilotForXcode/
ZIPNAME_BASE := Copilot.for.Xcode.app

setup:
	echo "Setup."

# Usage: make appcast app=path/to/bundle.app tag=1.0.0 [channel=beta] [release=1]
appcast:
	$(eval TMPDIR := ~/Library/Caches/CopilotForXcodeRelease/$(shell uuidgen))
	$(eval BUNDLENAME := $(shell basename "$(app)"))
	$(eval ZIPNAME := $(ZIPNAME_BASE).$(if $(channel),$(channel).)$(if $(release),$(release),1).zip)
	mkdir -p $(TMPDIR)
	cp appcast.xml $(TMPDIR)/appcast.xml
	cd "$(app)" && cd .. && zip -r "$(ZIPNAME)" "$(BUNDLENAME)"
	cd "$(app)" && cd .. && cp "$(ZIPNAME)" $(TMPDIR)/
	-Core/.build/artifacts/sparkle/bin/generate_appcast $(TMPDIR) --download-url-prefix "$(GITHUB_URL)releases/download/$(tag)/" --full-release-notes-url "$(GITHUB_URL)releases/tag/$(tag)" $(if $(channel),--channel "$(channel)")
	mv -f $(TMPDIR)/appcast.xml .
	rm -rf $(TMPDIR)

.PHONY: setup appcast