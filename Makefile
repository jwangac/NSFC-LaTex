SHELL := bash

BUILD_PDF     := SOURCE_DATE_EPOCH=0 latexmk -pdf	 -latexoption='-synctex=1' -output-directory=output/build
BUILD_XELATEX := SOURCE_DATE_EPOCH=0 latexmk -xelatex -latexoption='-synctex=1' -output-directory=output/build

TEXS := $(wildcard *.tex)
PDFS := $(addprefix output/build/,$(TEXS:.tex=.pdf))

define FILTER_PY
#!/usr/bin/env python3

import sys

log = []
log_cnt = 0

skip_line_break = True
for line in sys.stdin.buffer:
    if line.startswith(b'xdvipdfmx:warning: '):
        skip_line_break = True
        continue
    if skip_line_break:
        skip_line_break = False
    else:
        print()
    line = line.rstrip().decode('utf-8', errors='replace')

    if line.startswith('! '):
        log_cnt = 8
    if line.startswith('Overfull '):
        log_cnt = 2

    if log_cnt > 0:
        log_cnt = log_cnt - 1
        log.append(line)

    print(line, end='')
print()

for line in log:
    print('[Error]', line)
endef
export FILTER_PY
FILTER_PY_PATH := $(shell mktemp)

all: $(PDFS)
	@if [[ -f ./script/synctex_patch.sh ]]; then ./script/synctex_patch.sh; fi
	@rm -f "$(FILTER_PY_PATH)"

output/build/%.pdf: %.tex directory_layout bibfix filter_py
	@if grep -qP '[\p{Han}\p{Hiragana}\p{Katakana}]' $<; then \
	    $(BUILD_XELATEX) $< </dev/null 2>&1 | "$(FILTER_PY_PATH)"; if [[ "$${PIPESTATUS[0]}" != "0" ]]; then rm -rf output/build/ && exit 1; fi \
	else \
	    $(BUILD_PDF)     $< </dev/null 2>&1 | "$(FILTER_PY_PATH)"; if [[ "$${PIPESTATUS[0]}" != "0" ]]; then rm -rf output/build/ && exit 1; fi \
	fi
	@mv $@ $(subst output/build/,output/,$@)
	@{ [ -f output/build/$(<:.tex=.synctex.gz) ] && cp output/build/$(<:.tex=.synctex.gz) output/$(<:.tex=.synctex.gz) ; } || true

directory_layout:
	@mkdir -p $$(find -name '*.tex' -printf 'output/build/%h\n')

bibfix:
	@find -name '*.bib' -exec bibfix {} +

filter_py:
	@echo "$$FILTER_PY" >"$(FILTER_PY_PATH)"
	@chmod +x "$(FILTER_PY_PATH)"

clean:
	@rm -rf output/
