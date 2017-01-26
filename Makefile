W3_SUITE = https://www.w3.org/Voice/2013/scxml-irp

TXML = $(shell find test/scxml_w3 -type f -iname '*.txml')
SCXML  = $(TXML:.txml=.scxml)

test: generate
	@mix test

generate: test/scxml_w3/cases/.manifest $(SCXML)
	@$(MAKE) test/scxml_w3/cases/.cases 

test/scxml_w3/cases/.cases: $(SCXML)
	@mix run test/scxml_w3/cases.exs $?
	@touch $@

%.scxml: %.txml
	saxon --suppressXsltNamespaceCheck:on -s:$< -xsl:test/scxml_w3/conf_elixir.xsl -o:$@

test/scxml_w3/cases/.manifest: test/scxml_w3/cases/manifest.xml test/scxml_w3/manifest.exs
	@mix run test/scxml_w3/manifest.exs test/scxml_w3/cases/manifest.xml $@ $(W3_SUITE)

test/scxml_w3/cases/manifest.xml:
	@mkdir -p test/scxml_w3/cases
	curl -L $(W3_SUITE)/manifest.xml -o $@

clean:
	@rm -rf test/scxml_w3/cases

.PHONY: clean