#!/bin/zsh
# 使い方: run-packages.sh <hoori|v2> <パッケージ...>
MODE=$1; shift
SRC=/Users/fumio/Projects/Spellu/ソース
S=/private/tmp/claude-501/-Users-fumio-Projects-Spellu/00951283-3053-434c-91a0-66870b56fbf6/scratchpad/hoori-real
W=/private/tmp/hoori-packages-$MODE
mkdir -p $W
for d in XML HTML Markdown ECMAScript EBNF CSS Lua ConformanceTestCenter; do
	if [ ! -d $W/$d ]; then
		mkdir -p $W/$d
		git -C $SRC/$d archive local/develop | tar -x -C $W/$d
		python3 -I $S/patch-package.py $W/$d $MODE $W
	fi
done
for d in "$@"; do
	FILTER="."
	if [ "$d" = "ConformanceTestCenter" ]; then
		FILTER="XMLConformanceTests|HTMLConformanceTests|MarkdownConformanceTests|EBNFConformanceTests"
	fi
	echo "=== $d $(date +%H:%M:%S)"
	W3C_XML_SUITE_ROOT=/private/tmp/XML-W3C swift test --package-path $W/$d --scratch-path /private/tmp/swift-package/hoori-$MODE-$d --filter "$FILTER" 2>&1 | sed 's/\x1b\[[0-9;]*m//g' > $W/$d.log
	grep -E "Test run with|error:" $W/$d.log | cut -c1-160 | tail -3
	echo "issues: $(grep -c 'recorded an issue' $W/$d.log)"
done
echo "=== done $(date +%H:%M:%S)"
