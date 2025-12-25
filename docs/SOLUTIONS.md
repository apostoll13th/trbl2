# Решения задач

**ВНИМАНИЕ:** Этот документ только для интервьюера!

---

## Задача 1: Docker - Port недоступен

### Проблема
Приложение слушает `127.0.0.1:8080` вместо `0.0.0.0:8080`.
Compose файл в нестандартном месте: `/opt/apps/webapp/deploy/`

### Диагностика
```bash
# Проверить что контейнер запущен
docker ps

# Проверить на каком IP слушает приложение внутри контейнера
docker exec webapp netstat -tlnp
# или
docker exec webapp ss -tlnp
# Видим: 127.0.0.1:8080 - вот проблема!

# Найти compose файл
docker inspect webapp --format '{{index .Config.Labels "com.docker.compose.project.working_dir"}}'
# или
find /opt -name "compose.yaml" 2>/dev/null
find /opt -name "docker-compose.yaml" 2>/dev/null
```

### Решение
```bash
# Редактировать compose.yaml
vim /opt/apps/webapp/deploy/compose.yaml

# Изменить:
#   command: python -m http.server 8080 --bind 127.0.0.1
# На:
#   command: python -m http.server 8080 --bind 0.0.0.0

# Перезапустить
cd /opt/apps/webapp/deploy
docker compose down
docker compose up -d

# Проверить
curl localhost:8080
```

### Ключевые моменты
- `127.0.0.1` = только localhost (внутри контейнера)
- `0.0.0.0` = все интерфейсы (доступно снаружи)
- Docker port mapping (`-p 8080:8080`) не поможет если приложение слушает только localhost

---

## Задача 2: DNS не работает

### Проблема
- `/etc/resolv.conf` содержит несуществующий DNS сервер `10.255.255.1`
- `systemd-resolved` остановлен

### Диагностика
```bash
# Проверить текущий DNS
cat /etc/resolv.conf
# Видим: nameserver 10.255.255.1 - несуществующий сервер

# Проверить systemd-resolved
systemctl status systemd-resolved
# Видим: inactive
```

### Решение (вариант 1 - быстрый)
```bash
# Заменить DNS сервер
echo "nameserver 8.8.8.8" | sudo tee /etc/resolv.conf

# Проверить
ping google.com
```

### Решение (вариант 2 - правильный)
```bash
# Запустить systemd-resolved
sudo systemctl start systemd-resolved
sudo systemctl enable systemd-resolved

# Восстановить symlink
sudo ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf

# Проверить
ping google.com
```

### Ключевые моменты
- `/etc/resolv.conf` - конфигурация DNS resolver
- `systemd-resolved` - современный DNS resolver в Ubuntu
- Публичные DNS: 8.8.8.8 (Google), 1.1.1.1 (Cloudflare)

---

## Задача 3: Kubernetes - CrashLoopBackOff

### Проблема
Readiness/Liveness probe настроены на `/health`, а приложение отдаёт на `/healthz`.

### Диагностика
```bash
# Посмотреть статус подов
kubectl -n interview get pods
# Видим: CrashLoopBackOff или 0/1 Ready

# Посмотреть детали
kubectl -n interview describe pod webapp-xxx
# В Events видим:
# Warning  Unhealthy  Readiness probe failed: HTTP probe failed with statuscode: 404

# Проверить что приложение внутри работает
kubectl -n interview exec -it webapp-xxx -- curl localhost/healthz
# Ответ: OK

kubectl -n interview exec -it webapp-xxx -- curl localhost/health
# Ответ: 404
```

### Решение
```bash
# Редактировать deployment
kubectl -n interview edit deployment webapp

# Найти и изменить:
#   path: /health
# На:
#   path: /healthz
# (в обоих местах - readinessProbe и livenessProbe)

# Сохранить и выйти (:wq)

# Проверить
kubectl -n interview get pods
# Должен стать Running и 1/1 Ready
```

### Альтернативное решение (patch)
```bash
kubectl -n interview patch deployment webapp --type='json' -p='[
  {"op": "replace", "path": "/spec/template/spec/containers/0/readinessProbe/httpGet/path", "value": "/healthz"},
  {"op": "replace", "path": "/spec/template/spec/containers/0/livenessProbe/httpGet/path", "value": "/healthz"}
]'
```

### Ключевые моменты
- `readinessProbe` - определяет готов ли под принимать трафик
- `livenessProbe` - определяет нужно ли перезапустить контейнер
- 404 в probe = probe failed = pod не ready / перезапуск
- Всегда проверять какой endpoint реально отдаёт приложение

---

## Задача 4: GitLab Runner - Jobs не выполняются

### Проблема
- GitLab Runner работает и зарегистрирован
- Executor = docker
- В config.toml указан неправильный путь к docker socket

### Диагностика
```bash
# Проверить статус runner
systemctl status gitlab-runner
# Видим: active (running)

# Проверить конфигурацию
cat /etc/gitlab-runner/config.toml
# Видим: executor = "docker"
# Видим: host = "unix:///var/run/docker-wrong.sock"  <-- ПРОБЛЕМА!

# Docker работает нормально
docker ps
# Видим: контейнеры работают

# Но gitlab-runner не может подключиться
sudo gitlab-runner verify
# Видим ошибку: Cannot connect to the Docker daemon at unix:///var/run/docker-wrong.sock
```

### Решение
```bash
# Редактировать config.toml
sudo vim /etc/gitlab-runner/config.toml

# Найти и удалить или исправить строку:
#   host = "unix:///var/run/docker-wrong.sock"
# На:
#   host = "unix:///var/run/docker.sock"
# Или просто удалить эту строку (используется дефолтный путь)

# Перезапустить runner
sudo systemctl restart gitlab-runner

# Проверить
sudo gitlab-runner verify
```

### Ключевые моменты
- GitLab Runner с docker executor требует доступ к Docker socket
- Дефолтный путь: `/var/run/docker.sock`
- `gitlab-runner verify` - проверка работоспособности runner
- Всегда проверять конфигурацию в `/etc/gitlab-runner/config.toml`
- Другие executors: shell, kubernetes, docker+machine

---

## Чек-лист для интервьюера

### Что оценивать

1. **Методология troubleshooting**
   - Собирает ли информацию перед действиями?
   - Логически подходит к решению?
   - Проверяет ли гипотезы?

2. **Технические знания**
   - Знает базовые команды?
   - Понимает как работают системы?
   - Может объяснить root cause?

3. **Практические навыки**
   - Уверенно работает в терминале?
   - Знает где искать логи и конфиги?
   - Использует правильные инструменты?

### Red flags
- Сразу пытается что-то менять без диагностики
- Не проверяет результат после изменений
- Не может объяснить что делает
- Гуглит базовые команды

### Green flags
- Системный подход к диагностике
- Объясняет ход мыслей
- Знает несколько способов решения
- Понимает root cause и может предотвратить
