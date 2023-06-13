setup: setup-langchain

setup-langchain:
	cd Python; \
	curl -L https://github.com/beeware/Python-Apple-support/releases/download/3.11-b1/Python-3.11-macOS-support.b1.tar.gz -o Python-3.11-macOS-support.b1.tar.gz; \
	tar -xzvf Python-3.11-macOS-support.b1.tar.gz; \
	rm Python-3.11-macOS-support.b1.tar.gz; \
	cp module.modulemap.copy Python.xcframework/macos-arm64_x86_64/Headers/module.modulemap
	cd Python/site-packages; \
	sh ./install.sh

.PHONY: setup setup-langchain
