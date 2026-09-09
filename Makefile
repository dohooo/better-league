.PHONY: build run cli dist check release clean

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

check: dist cli
	./scripts/verify.sh "dist/Better-League-$$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' resources/Info.plist)-local.dmg"

release:
	./scripts/release.sh

clean:
	rm -rf .build
