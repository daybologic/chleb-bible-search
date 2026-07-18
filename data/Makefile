#!/usr/bin/make -f
# Chleb Bible Search
# Copyright (c) 2024-2026, Rev. Duncan Ross Palmer (2E0EOL),
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
#
#  1. Redistributions of source code must retain the above copyright
#     notice, this list of conditions and the following disclaimer.
#
#  2. Redistributions in binary form must reproduce the above copyright
#     notice, this list of conditions and the following disclaimer in the
#     documentation and/or other materials provided with the distribution.
#
#  3. Neither the name of the project nor the names of its contributors
#     may be used to endorse or promote products derived from this software
#     without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE PROJECT AND CONTRIBUTORS ``AS IS'' AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED.  IN NO EVENT SHALL THE PROJECT OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
# OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
# HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
# LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
# OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
# SUCH DAMAGE.

all: \
	asv.bin.gz \
	asv.sqlite.gz \
	core.sqlite.gz \
	kjv.bin.gz \
	kjv.sqlite.gz

ifneq ($(wildcard static/pickthall.txt),)
all: pickthall.sqlite.gz
endif

asv.bin.gz asv.sqlite.gz &: static/asv.txt ../bin/import/text-to-asv.sh ../bin/import/text-to-bin.pl ../bin/import/text-to-sqlite.pl
	cd ../ && ./bin/import/text-to-asv.sh

core.sqlite.gz : static/kjv.txt ../bin/import/text-to-core.sh ../bin/import/text-to-sqlite.pl
	cd ../ && ./bin/import/text-to-core.sh

kjv.bin.gz kjv.sqlite.gz &: static/kjv.txt ../bin/import/text-to-kjv.sh ../bin/import/text-to-bin.pl ../bin/import/text-to-sqlite.pl
	cd ../ && ./bin/import/text-to-kjv.sh

ifneq ($(wildcard static/pickthall.txt),)
pickthall.sqlite.gz: static/pickthall.txt ../bin/import/text-to-pickthall.sh ../bin/import/text-to-sqlite.pl
	cd ../ && ./bin/import/text-to-pickthall.sh
endif

clean:
	rm -vf *.bin *.bin.gz *.sqlite *.sqlite.gz

.PHONY: clean all
