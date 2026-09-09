.PHONY: build run cli dist release clean

build:
	./scripts/build.sh

run: build
	open ".build/Better League.app"

cli: .build/lolrestore

.build/lolrestore: $(wildcard src/Core/*.swift src/CLI/*.swift) Makefile
	@mkdir -p .build
	xcrun swiftc -O -parse-as-library -target $$(uname -m)-apple-macosx26.0 src/Core/*.swift src/CLI/*.swift -o "$@"

dist: build
	./scripts/package.sh

release:
	./scripts/release.sh

clean:
	rm -rf .build
