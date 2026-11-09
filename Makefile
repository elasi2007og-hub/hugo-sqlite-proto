# Hugo + SQLite (solo en build). Cada objetivo hace una cosa.
.DEFAULT_GOAL := help
.PHONY: index build serve serve-drafts check stats clean check-invites help

index:   ## Markdown → SQLite → static/search.json + data/tags.json + data/words.json
	python3 tools/index.py

build: index   ## Genera el sitio estático en public/ (esto es lo que se despliega)
	hugo --gc --minify

serve: index   ## Servidor local con recarga: http://localhost:1313/
	hugo server

serve-drafts:   ## Índice con borradores (--drafts) + hugo server -D
	python3 tools/index.py --drafts
	hugo server -D

check: index   ## Valida que los JSON generados son JSON de verdad
	python3 -m json.tool static/search.json > /dev/null
	python3 -m json.tool data/tags.json > /dev/null
	python3 -m json.tool data/words.json > /dev/null
	@echo "check: OK"

stats: index   ## Muestra resumen SQL de páginas y palabras desde build/site.db
	@python3 -c 'import sqlite3; con = sqlite3.connect("build/site.db"); [print(f"{n:4d} palabras  {url:<42} ({title})") for url, title, n in con.execute("SELECT p.url, p.title, w.n FROM posts p JOIN words w USING(url) ORDER BY w.n DESC")]'

clean:   ## Borra todo lo generado (public/, resources/, build/, JSON)
	rm -rf public resources build static/search.json data/tags.json data/words.json .hugo_build.lock

check-invites:   ## [profesor] Lista invitaciones de colaborador pendientes (gh auth login)
	@gh api user/repository_invitations --jq '.[] | "\(.id)\t\(.repository.full_name)\tinvited_by=\(.invited_by.login)\t\(.created_at)"' \
		| { grep . || echo "Sin invitaciones pendientes."; }

help:   ## Muestra esta ayuda
	@grep -E '^[a-zA-Z_-]+:.*## .*$$' $(MAKEFILE_LIST) | sort | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-16s\033[0m %s\n", $$1, $$2}'
