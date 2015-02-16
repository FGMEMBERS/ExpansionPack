build_docs:
	$(MAKE) -C doc html

clean_docs:
	$(MAKE) -C doc clean

clean: clean_docs

docs: build_docs
