.PHONY: run build serve new clean

HUGO_VERSION := 0.124.1

run:
	hugo server -D --disableFastRender

build:
	hugo --minify --gc

serve:
	hugo server --disableFastRender --port 1313

new:
	@read -p "Section (kubernetes/cicd/observability/azure/platform-engineering): " section; \
	read -p "Slug: " slug; \
	hugo new posts/$$section/$$slug.md

clean:
	rm -rf public resources .hugo_build.lock

install-hugo:
	wget -O /tmp/hugo.tar.gz \
	  https://github.com/gohugoio/hugo/releases/download/v$(HUGO_VERSION)/hugo_extended_$(HUGO_VERSION)_linux-amd64.tar.gz
	tar -xzf /tmp/hugo.tar.gz -C /tmp
	sudo mv /tmp/hugo /usr/local/bin/
	hugo version

theme:
	git submodule add https://github.com/adityatelange/hugo-PaperMod.git themes/PaperMod
	git submodule update --init --recursive
