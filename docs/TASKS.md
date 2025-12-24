# Задачи для собеседования

Этот документ содержит описания задач для кандидатов.

---

## Задача 1: Docker - Port недоступен

**Время:** 7-10 минут

**Легенда для кандидата:**
> Разработчик жалуется, что приложение не отвечает на порту 8080.
> Контейнер запущен, но curl возвращает connection refused.
> Найди проблему и почини.

**Что проверить:**
```bash
docker ps                     # контейнер running
curl localhost:8080           # connection refused
```

**Дополнительное задание:**
> Найди где лежит конфигурация docker-compose для этого приложения.

**Ожидаемые навыки:**
- Работа с Docker
- Debugging сетевых проблем
- Понимание разницы между 127.0.0.1 и 0.0.0.0
- Умение находить конфигурации

---

## Задача 2: DNS не работает

**Время:** 5-7 минут

**Легенда для кандидата:**
> curl google.com не работает, но ping по IP работает.
> Почини DNS.

**Что проверить:**
```bash
ping 8.8.8.8       # работает
ping google.com    # Temporary failure in name resolution
curl google.com    # не работает
```

**Ожидаемые навыки:**
- Понимание работы DNS
- Знание /etc/resolv.conf
- Работа с systemd-resolved (опционально)

---

## Задача 3: Kubernetes - CrashLoopBackOff

**Время:** 7-10 минут

**Легенда для кандидата:**
> Под постоянно рестартится.
> Разработчики говорят, что приложение работает.
> Разберись почему под не стартует.

**Что проверить:**
```bash
kubectl -n interview get pods      # CrashLoopBackOff или не Ready
kubectl -n interview describe pod  # смотреть Events
```

**Ожидаемые навыки:**
- Работа с kubectl
- Понимание probes (liveness/readiness)
- Умение читать describe и events
- Debugging pods

---

## Задача 4: GitLab Runner - Jobs не выполняются

**Время:** 5-7 минут

**Легенда для кандидата:**
> GitLab Runner зарегистрирован, но jobs падают сразу после старта.
> Разберись в чём проблема.

**Что проверить:**
```bash
systemctl status gitlab-runner    # active (running)
cat /etc/gitlab-runner/config.toml  # executor = "docker"
gitlab-runner verify              # ошибка подключения к docker
```

**Ожидаемые навыки:**
- Понимание GitLab CI/CD
- Работа с GitLab Runner
- Понимание executor types
- Debugging systemd сервисов

---

## Порядок задач

Рекомендуемый порядок для собеседования:

1. **DNS** (простая) - разогрев
2. **Docker** (средняя) - основная
3. **Kubernetes** (средняя-сложная) - основная
4. **GitLab Runner** (простая) - завершение

Можно выбрать 2-3 задачи в зависимости от уровня кандидата и времени.

---

## Оценка

| Уровень | Ожидания |
|---------|----------|
| Junior | DNS + Docker с подсказками |
| Middle | 3 задачи самостоятельно |
| Senior | Все 4 задачи быстро, объясняет root cause |
