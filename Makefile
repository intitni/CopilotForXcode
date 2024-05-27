GITHUB_URL := https://github.com/intitni/CopilotForXcode/
ZIPNAME_BASE := Copilot.for.Xcode.app

setup:
	echo "Setup."

# Usage: make appcast app=path/to/bundle.app tag=1.0.0 [channel=beta] [release=1]
appcast:
	$(eval TMPDIR := ~/Library/Caches/CopilotForXcodeRelease/$(shell uuidgen))
	$(eval BUNDLENAME := $(shell basename "$(app)"))
	$(eval WORKDIR := $(shell dirname "$(app)"))
	$(eval ZIPNAME := $(ZIPNAME_BASE)$(if $(channel),.$(channel).$(if $(release),$(release),1)))
	$(eval RELEASENOTELINK := $(GITHUB_URL)releases/tag/$(tag))
	mkdir -p $(TMPDIR)
	cp appcast.xml $(TMPDIR)/appcast.xml
	cd $(WORKDIR) && ditto -c -k --sequesterRsrc --keepParent "$(BUNDLENAME)" "$(ZIPNAME).zip"
	cd $(WORKDIR) && cp "$(ZIPNAME).zip" $(TMPDIR)/
	touch $(TMPDIR)/$(ZIPNAME).html
	echo "<body></body>" > $(TMPDIR)/$(ZIPNAME).html
	-Core/.build/artifacts/sparkle/bin/generate_appcast $(TMPDIR) --download-url-prefix "$(GITHUB_URL)releases/download/$(tag)/" --release-notes-url-prefix "$(RELEASENOTELINK)" $(if $(channel),--channel "$(channel)")
	mv -f $(TMPDIR)/appcast.xml .
	rm -rf $(TMPDIR)
	sed -i '' 's/$(ZIPNAME).html/$(tag)/g' appcast.xml

.PHONY: setup appcast