#!/bin/sh

set -e

find lib/ -name "*.pm" -type f -exec sed -i 's/2025/2026/' {} \;
find t/ -name "*.t" -type f -exec sed -i 's/2025/2026/' {} \;
sed -i 's/2025/2026/' *.PL
find bin -name "*.sh" -type f -exec sed -i 's/2025/2026/' {} \;
find bin -name "*.pl" -type f -exec sed -i 's/2025/2026/' {} \;
find data/tests -name "*.sh" -type f -exec sed -i 's/2025/2026/' {} \;
sed -i 's/2025/2026/' bitbucket-pipelines.yml COPYING data/Makefile debian/rules debian/copyright

exit 0
