all: fava/static/app.js

fava/static/app.js: frontend/css/* frontend/src/* frontend/package.json frontend/node_modules
	cd frontend; npm run build

frontend/node_modules: frontend/package-lock.json
	cd frontend; npm install --no-progress
	touch -m frontend/node_modules

.PHONY: clean
clean: mostlyclean
	rm -rf build dist
	rm -rf fava/static/*

.PHONY: mostlyclean
mostlyclean:
	rm -rf .*cache
	rm -rf .eggs
	rm -rf .tox
	rm -rf build
	rm -rf dist
	rm -rf frontend/node_modules
	find . -type f -name '*.py[c0]' -delete
	find . -type d -name "__pycache__" -delete

.PHONY: check-lint
check-lint: frontend/node_modules
	cd frontend; npm run check-lint
	tox -e lint

.PHONY: lint
lint: frontend/node_modules
	cd frontend; npm run lint
	tox -e format
	tox -e lint

.PHONY: test
test:
	cd frontend; npm run test
	tox -e py

.PHONY: update-snapshots
update-snapshots:
	find . -name "__snapshots__" -type d -prune -exec rm -r "{}" +
	-SNAPSHOT_UPDATE=1 tox
	tox

.PHONY: docs
docs:
	tox -e docs

.PHONY: run-example
run-example:
	@xdg-open http://localhost:3333
	BEANCOUNT_FILE= fava -p 3333 --debug tests/data/example.beancount

.PHONY: bql-grammar
bql-grammar:
	contrib/scripts.py generate-bql-grammar-json

dist: fava/static/app.js fava setup.cfg setup.py MANIFEST.in
	rm -rf build dist
	python setup.py sdist bdist_wheel

.PHONY: before-release
before-release: bql-grammar translations-push translations-fetch

# Before making a release, CHANGES needs to be updated and
# a tag should be created too.
#
# Also, fava.pythonanywhere.com should be updated.
.PHONY: upload
upload: dist
	twine upload dist/*

# Extract translation strings.
.PHONY: translations-extract
translations-extract:
	pybabel extract -F fava/translations/babel.conf -o fava/translations/messages.pot .

# Extract translation strings and upload them to POEditor.com.
# Requires the environment variable POEDITOR_TOKEN to be set to an API token
# for POEditor.
.PHONY: translations-push
translations-push: translations-extract
	contrib/scripts.py upload-translations

# Download translations from POEditor.com. (also requires POEDITOR_TOKEN)
.PHONY: translations-fetch
translations-fetch:
	contrib/scripts.py download-translations
	pybabel compile -d fava/translations

# Build and upload the website.
.PHONY: gh-pages
gh-pages:
	git checkout master
	git checkout --orphan gh-pages
	tox -e docs
	ls | grep -v 'build' | xargs rm -r
	mv -f build/docs/* ./
	rm -r build
	touch .nojekyll
	git add -A
	git commit -m 'Update gh-pages'
	git push --force git@github.com:beancount/fava.git gh-pages:gh-pages
	git checkout master
	git branch -D gh-pages
