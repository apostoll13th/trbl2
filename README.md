# DevOps Interview Troubleshooting Tasks

Инфраструктура для практических задач на собеседованиях DevOps инженеров.

## Быстрый старт

```bash
# 1. Настройте credentials (один раз)
cp .env.example .env
vim .env  # заполните username, password, project_id

# 2. Деплой
./scripts/deploy.sh

# 3. Подключение к VM
ssh ubuntu@<VM_IP>

# 4. После собеседования
./scripts/destroy.sh
```

## Требования

- Terraform >= 1.0.0
- Ansible >= 2.9
- SSH ключ (`~/.ssh/id_rsa.pub`)
- Аккаунт VK Cloud

## Задачи

После деплоя на VM доступны 4 задачи (по 7-10 минут каждая):

| # | Задача | Легенда |
|---|--------|---------|
| 1 | Docker | Port 8080 недоступен, контейнер запущен |
| 2 | DNS | curl по домену не работает, ping по IP работает |
| 3 | Kubernetes | Pod в CrashLoopBackOff |
| 4 | GitLab Runner | Jobs падают сразу |

Подробные описания: [docs/TASKS.md](docs/TASKS.md)

Решения (для интервьюера): [docs/SOLUTIONS.md](docs/SOLUTIONS.md)

## Структура проекта

```
├── .env.example           # Шаблон credentials
├── .env                   # Credentials (не в git!)
├── terraform/             # Инфраструктура VK Cloud
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   └── versions.tf
├── ansible/               # Настройка VM
│   ├── ansible.cfg
│   ├── playbooks/
│   │   └── setup-all.yml
│   └── roles/
│       ├── common/
│       ├── docker-broken/
│       ├── dns-broken/
│       ├── k8s-broken/
│       └── gitlab-broken/
├── scripts/
│   ├── deploy.sh          # Деплой
│   └── destroy.sh         # Удаление
└── docs/
    ├── TASKS.md           # Описания задач
    └── SOLUTIONS.md       # Решения
```

## VK Cloud Credentials

Получить credentials можно в личном кабинете VK Cloud:
1. Перейти на https://mcs.mail.ru/app/project
2. Project ID: URL вида `/app/project/<PROJECT_ID>/...`
3. Username: email от аккаунта
4. Password: пароль от аккаунта
