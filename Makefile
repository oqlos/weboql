.PHONY: help install dev build run test clean publish

help:		## Show this help message
	@echo 'Usage: make [target]'
	@echo ''
	@echo 'Available targets:'
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  %-15s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

install:	## Install weboql in development mode
	pip install -e .

dev: install	## Install with development dependencies
	pip install -e ".[dev]"

build:		## Build distribution packages
	python -m build

run:		## Run weboql server
	HARDWARE_MODE=mock weboql-server

run-prod:	## Run weboql server in production mode
	weboql-server

test:		## Run tests
	pytest

clean:		## Clean build artifacts
	rm -rf dist/ build/ *.egg-info
	find . -type d -name __pycache__ -exec rm -rf {} +
	find . -type f -name "*.pyc" -delete

publish: clean build	## Publish to PyPI
	twine upload dist/*

publish-test: clean build	## Publish to test PyPI
	twine upload --repository testpypi dist/
