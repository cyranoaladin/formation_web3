.PHONY: test-runnerd

test-runnerd:
	python3 -m venv .venv-runnerd
	. .venv-runnerd/bin/activate && python -m pip install -U pip
	. .venv-runnerd/bin/activate && python -m pip install -r runnerd/requirements.txt
	. .venv-runnerd/bin/activate && python -m pytest -q runnerd/tests
