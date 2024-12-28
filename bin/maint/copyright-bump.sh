#!/bin/sh

set -e

find lib/ -name "*.pm" -type f -exec sed -i 's/2024/2024-2025/' {} \;
find t/ -name "*.t" -type f -exec sed -i 's/2024/2024-2025/' {} \;
sed -i 's/2024/2024-2025/' *.PL
find bin -name "*.sh" -type f -exec sed -i 's/2024/2024-2025/' {} \;
find bin -name "*.pl" -type f -exec sed -i 's/2024/2024-2025/' {} \;
sed -i 's/2024/2024-2025/' bitbucket-pipelines.yml COPYING data/Makefile debian/rules debian/copyright

exit 0
