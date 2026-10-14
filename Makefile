.PHONY: install build test

install:
	python3 -m pip install -r requirements.txt

build:
	python3 scripts/validate_repo.py

test:
	python3 -m unittest discover -s tests -v
