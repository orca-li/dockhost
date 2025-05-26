DOMAIN ?= example.com
EMAIL ?= no-reply@$(DOMAIN)
SERVICES ?= nextcloud wordpress gitea
TIMESTAMP := $(shell date +"%Y-%m-%d_%H-%M-%S")

define service_domain
$(if $(findstring nextcloud,$(1)),cloud.$(DOMAIN),$(if $(findstring wordpress,$(1)),blog.$(DOMAIN),$(if $(findstring gitea,$(1)),git.$(DOMAIN),$(1).$(DOMAIN))))
endef

build:
	@echo "🛠 Создание директории сборки..."
	@rm -rf build && mkdir -p build

	@echo "🔐 Генерация .env с секретами..."
	@echo "DOMAIN=$(DOMAIN)" > build/.env
	@echo "EMAIL=$(EMAIL)" >> build/.env
	@echo "MYSQL_ROOT_PASSWORD=$$(openssl rand -base64 32 | tr -d '=')" >> build/.env

	@for svc in $(SERVICES); do \
		UC_SVC=$$(echo $$svc | tr a-z A-Z); \
		DOMAIN_VAR=$${UC_SVC}_DOMAIN; \
		DBPASS_VAR=$${UC_SVC}_DB_PASS; \
		SVC_DOMAIN=$$( \
			if [ "$$svc" = "nextcloud" ]; then echo "cloud.$(DOMAIN)"; \
			elif [ "$$svc" = "wordpress" ]; then echo "blog.$(DOMAIN)"; \
			elif [ "$$svc" = "gitea" ]; then echo "git.$(DOMAIN)"; \
			else echo "$$svc.$(DOMAIN)"; fi); \
		echo "$${DOMAIN_VAR}=$$SVC_DOMAIN" >> build/.env; \
		echo "$${DBPASS_VAR}=$$(openssl rand -base64 32 | tr -d '=')" >> build/.env; \
		cat templates/env/$$svc.env | envsubst >> build/.env; \
	done

	@echo "🧩 Генерация docker-compose.yml..."
	@cp docker-compose.header.yml build/docker-compose.yml
	@echo "  # services will be inserted below" >> build/docker-compose.yml
	@for svc in $(SERVICES); do \
		envsubst < templates/compose/$$svc.yml >> build/docker-compose.yml ; \
	done

	@echo "📦 Добавление Caddy в docker-compose.yml..."
	@cat <<EOF >> build/docker-compose.yml

  caddy:
    image: caddy:latest
    container_name: caddy
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./build/Caddyfile:/etc/caddy/Caddyfile
      - caddy_data:/data
      - caddy_config:/config
    networks:
      - internal

EOF

	@echo "" >> build/docker-compose.yml
	@echo "networks:" >> build/docker-compose.yml
	@echo "  internal:" >> build/docker-compose.yml
	@echo "    driver: bridge" >> build/docker-compose.yml
	@echo "" >> build/docker-compose.yml
	@echo "volumes:" >> build/docker-compose.yml
	@grep ' - [a-zA-Z0-9_]\+_data' build/docker-compose.yml | sed 's/.*- //' | sed 's/:.*//' | sort -u | while read vol; do \
		echo "  $$vol:" >> build/docker-compose.yml; \
	done
	@echo "  caddy_data:" >> build/docker-compose.yml
	@echo "  caddy_config:" >> build/docker-compose.yml

	@echo "🌐 Генерация Caddyfile..."
	@{ \
		echo "{"; \
		echo "  email $(EMAIL)"; \
		echo "}"; \
		echo ""; \
	} > build/Caddyfile

	@for svc in $(SERVICES); do \
		DOMAIN=$$( \
			if [ "$$svc" = "nextcloud" ]; then echo "cloud.$(DOMAIN)"; \
			elif [ "$$svc" = "wordpress" ]; then echo "blog.$(DOMAIN)"; \
			elif [ "$$svc" = "gitea" ]; then echo "git.$(DOMAIN)"; \
			else echo "$$svc.$(DOMAIN)"; fi); \
		PORT=$$(test "$$svc" = "gitea" && echo 3000 || echo 80); \
		echo "$$DOMAIN {" >> build/Caddyfile; \
		echo "  reverse_proxy $$svc:$$PORT" >> build/Caddyfile; \
		echo "}" >> build/Caddyfile; \
		echo "" >> build/Caddyfile; \
	done

	@echo "✅ Build completed."

up:
	@docker compose -f build/docker-compose.yml --env-file build/.env up -d

down:
	@docker compose -f build/docker-compose.yml down

clean:
	@read -p "This will remove the build folder and all generated configs. Continue? [y/N]: " confirm; \
	if [ "$$confirm" = "y" ] || [ "$$confirm" = "Y" ]; then \
		docker compose -f build/docker-compose.yml down -v; \
		rm -rf build; \
		echo "🧹 Clean completed."; \
	else \
		echo "❌ Aborted."; \
	fi

backup:
	@mkdir -p backup/$(TIMESTAMP)
	@for V in $$(docker volume ls -q); do \
		docker run --rm -v $$V:/volume -v $$PWD/backup/$(TIMESTAMP):/backup alpine \
		tar czf /backup/$$V.tar.gz -C /volume . ; \
	done
	@echo "💾 Backup completed. Saved in ./backup/$(TIMESTAMP)"

restore:
	@read -p "This will overwrite existing volume data. Are you sure? [y/N]: " confirm; \
	if [ "$$confirm" = "y" ] || [ "$$confirm" = "Y" ]; then \
		for F in backup/*.tar.gz; do \
			V=$$(basename $$F .tar.gz); \
			docker volume create $$V; \
			docker run --rm -v $$V:/volume -v $$PWD/backup:/backup alpine \
			tar xzf /backup/$$F -C /volume ; \
		done; \
		echo "🔄 Restore completed."; \
	else \
		echo "❌ Aborted."; \
	fi

prune:
	@docker system prune -f
	@docker volume prune -f
	@docker network prune -f
	@echo "🗑 Prune completed."

force-clean:
	@read -p "WARNING: This will delete ALL Docker data. Continue? [y/N]: " confirm; \
	if [ "$$confirm" = "y" ] || [ "$$confirm" = "Y" ]; then \
		docker container stop $$(docker ps -aq) || true; \
		docker container rm $$(docker ps -aq) || true; \
		docker volume rm $$(docker volume ls -q) || true; \
		docker network rm $$(docker network ls -q | grep -v bridge) || true; \
		docker rmi -f $$(docker images -q) || true; \
		rm -rf build backup; \
		echo "💣 Force clean completed."; \
	else \
		echo "❌ Aborted."; \
	fi
