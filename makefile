# 项目名称，可以根据需要修改
PROJECT_NAME := ship-sale

# 定义允许的环境类型
ALLOWED_ENVS := dev prod

# 默认目标
.PHONY: help
help:
	@echo "使用方法:"
	@echo "  make up ENV=<dev|prod>    - 启动 Docker Compose 环境"
	@echo "  make down ENV=<dev|prod>  - 停止并移除 Docker Compose 环境"
	@echo "  make help                 - 显示此帮助信息"

# 检查环境变量是否有效的函数
check_env = \
	$(if $(ENV),\
		$(if $(filter $(ENV),$(ALLOWED_ENVS)),\
			,\
			$(error 无效的环境 "$(ENV)". 请使用以下之一: $(ALLOWED_ENVS))),\
		$(error 请指定环境变量ENV=<prod|dev>，例如: make up ENV=dev)\
	)

# 启动 Docker Compose
.PHONY: up
up:
	$(call check_env)
	(cd src/frontend && git fetch && git reset --hard origin/main)
	(cd src/backend-main && git fetch && git reset --hard origin/main)
	(cd src/backend-mail && git fetch && git reset --hard origin/main)
	ENV=$(ENV) docker compose -p $(PROJECT_NAME)-$(ENV) up -d --wait $(option)
	docker compose -p $(PROJECT_NAME)-$(ENV) exec backend-main php artisan migrate
	@echo "$(PROJECT_NAME)-$(ENV) 已在 $(ENV) 环境中启动"

# 停止并移除 Docker Compose 环境
.PHONY: down
down:
	$(call check_env)
	docker compose -p $(PROJECT_NAME)-$(ENV) down $(option)
	@echo "$(PROJECT_NAME)-$(ENV) 已停止并移除"
