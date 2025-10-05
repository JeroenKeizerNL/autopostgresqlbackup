CONTAINER_NAME=autopostgresqlbackup
IMAGE_NAME=jeroenkeizernl/$(CONTAINER_NAME)

.PHONY: test clean publish _build shell

pull:
	@echo "📥 Pulling latest source..."
	git pull

_build: pull clean
	@echo "🐳 Building Docker image..."
	docker build -t $(IMAGE_NAME):latest .

test: _build
	@echo "🚀 Running container..."
	docker run -d --name $(CONTAINER_NAME) \
		-e PG_DBHOST=myserver \
		-e PG_USERNAME=postgres \
		-e PG_PASSWORD=mypassword \
		-e PG_DB_NAME="all" \
		-e TZ="Europe/Amsterdam" \
		-e CRON_SCHEDULE="40 4 * * *" \
		$(IMAGE_NAME):latest

publish: _build
	@echo "📤 Pushing to Docker Hub..."
	docker push $(IMAGE_NAME):latest

clean:
	@echo "🧹 Removing container and image..."
	docker rm -f $(CONTAINER_NAME)
	docker rmi -f $(IMAGE_NAME)
	docker builder prune -f

shell:
	@echo "🧑‍💻 Opening shell in container..."
	docker exec -it $(CONTAINER_NAME) /bin/bash

