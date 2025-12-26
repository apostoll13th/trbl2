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

После деплоя на VM доступны 8 задач:

| # | Задача | Легенда | Сложность | Время |
|---|--------|---------|-----------|-------|
| 1 | Docker | Port 8080 недоступен, контейнер запущен | Средняя | 7-10 мин |
| 2 | DNS | curl по домену не работает, ping по IP работает | Простая | 5-7 мин |
| 3 | Kubernetes | Pod в CrashLoopBackOff | Средняя+ | 7-10 мин |
| 4 | GitLab Runner | Jobs падают сразу | Средняя | 5-7 мин |
| 5 | PostgreSQL | psql не подключается | Средняя | 7-10 мин |
| 6 | Disk Full | df показывает занято, du показывает пусто | Средняя+ | 10-15 мин |
| 7 | SSL Certificate | HTTPS не работает, сертификат истёк | Простая | 5-7 мин |
| 8 | Nginx Systemd | Сервис не стартует | Простая | 5-7 мин |

Подробные описания: [docs/TASKS.md](docs/TASKS.md)

Решения (для интервьюера): [docs/SOLUTIONS.md](docs/SOLUTIONS.md)

## Рекомендуемые комбинации

| Уровень | Задачи | Время |
|---------|--------|-------|
| Junior | DNS, SSL, Nginx Systemd | 30 мин |
| Middle | DNS, Docker, PostgreSQL, Disk Full, K8s | 45 мин |
| Senior | Все 8 задач | 60 мин |

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
│       ├── common/           # Docker, базовые пакеты
│       ├── docker-broken/    # Задача 1
│       ├── dns-broken/       # Задача 2
│       ├── k8s-broken/       # Задача 3
│       ├── gitlab-broken/    # Задача 4
│       ├── postgres-broken/  # Задача 5
│       ├── diskfull-broken/  # Задача 6
│       ├── ssl-broken/       # Задача 7
│       └── nginx-systemd-broken/  # Задача 8
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
