Создай полную инфраструктуру для практических задач на собеседованиях DevOps инженеров на VK Cloud.

# КОНТЕКСТ

Нужно развернуть VM с 4 "сломанными" задачами для troubleshooting на собесах. Каждая задача 7-10 минут.
Главное требование: МАКСИМАЛЬНО ПРОСТОЙ ДЕПЛОЙ — один раз настроил credentials и дальше просто `./deploy.sh`

# АВТОРИЗАЦИЯ VK CLOUD — УПРОЩЁННАЯ СХЕМА

## Как работает авторизация

VK Cloud использует username/password + project_id. Credentials можно:
1. Скачать готовый provider.tf с портала: https://mcs.mail.ru/app/project → Terraform tab → "Download VKCS provider file"
2. Или задать через переменные окружения

## Реализация — через .env файл

Создать файл `.env` который загружается автоматически. Пользователь заполняет его ОДИН РАЗ.
```bash
# .env - заполнить один раз, дальше не трогать
export TF_VAR_vkcs_username="user@example.com"
export TF_VAR_vkcs_password="your-password"
export TF_VAR_vkcs_project_id="your-project-id"
```

## Скрипт deploy.sh должен:
1. Проверить наличие .env
2. Если нет — предложить создать из шаблона
3. Автоматически загрузить переменные: `source .env`
4. Запустить terraform apply
5. Запустить ansible

# TERRAFORM — VK CLOUD PROVIDER

## Provider configuration:
```hcl
terraform {
  required_version = ">= 1.0.0"
  required_providers {
    vkcs = {
      source  = "vk-cs/vkcs"
      version = "~> 0.7.0"
    }
  }
}

provider "vkcs" {
  username   = var.vkcs_username
  password   = var.vkcs_password
  project_id = var.vkcs_project_id
  region     = var.vkcs_region
}
```

## Ресурсы:

### Сеть:
```hcl
data "vkcs_networking_network" "extnet" {
  name = "ext-net"
}

resource "vkcs_networking_network" "interview" {
  name = "interview-network"
}

resource "vkcs_networking_subnet" "interview" {
  name       = "interview-subnet"
  network_id = vkcs_networking_network.interview.id
  cidr       = "192.168.199.0/24"
}

resource "vkcs_networking_router" "interview" {
  name                = "interview-router"
  admin_state_up      = true
  external_network_id = data.vkcs_networking_network.extnet.id
}

resource "vkcs_networking_router_interface" "interview" {
  router_id = vkcs_networking_router.interview.id
  subnet_id = vkcs_networking_subnet.interview.id
}
```

### Security Group (SSH, HTTP, 8080):
```hcl
resource "vkcs_networking_secgroup" "interview" {
  name        = "interview-sg"
  description = "Security group for interview VM"
}

resource "vkcs_networking_secgroup_rule" "ssh" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = vkcs_networking_secgroup.interview.id
}

resource "vkcs_networking_secgroup_rule" "http" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 80
  port_range_max    = 80
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = vkcs_networking_secgroup.interview.id
}

resource "vkcs_networking_secgroup_rule" "http_alt" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 8080
  port_range_max    = 8080
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = vkcs_networking_secgroup.interview.id
}
```

### VM Instance:
```hcl
data "vkcs_compute_flavor" "interview" {
  name = "Basic-1-2-20"  # 1 vCPU, 2 GB RAM, 20 GB disk
}

data "vkcs_images_image" "ubuntu" {
  visibility = "public"
  default    = true
  properties = {
    mcs_os_distro  = "ubuntu"
    mcs_os_version = "24.04"
  }
}

resource "vkcs_compute_keypair" "interview" {
  name       = "interview-key"
  public_key = file(var.ssh_public_key_path)
}

resource "vkcs_compute_instance" "interview" {
  name              = "devops-interview"
  flavor_id         = data.vkcs_compute_flavor.interview.id
  key_pair          = vkcs_compute_keypair.interview.name
  security_groups   = [vkcs_networking_secgroup.interview.name]
  availability_zone = var.availability_zone

  block_device {
    uuid                  = data.vkcs_images_image.ubuntu.id
    source_type           = "image"
    destination_type      = "volume"
    volume_type           = "ceph-ssd"
    volume_size           = 20
    boot_index            = 0
    delete_on_termination = true
  }

  network {
    uuid = vkcs_networking_network.interview.id
  }

  depends_on = [
    vkcs_networking_router_interface.interview
  ]
}

resource "vkcs_networking_floatingip" "interview" {
  pool = "ext-net"
}

resource "vkcs_compute_floatingip_associate" "interview" {
  floating_ip = vkcs_networking_floatingip.interview.address
  instance_id = vkcs_compute_instance.interview.id
}
```

### Variables:
```hcl
variable "vkcs_username" {
  description = "VK Cloud username (email)"
  type        = string
  sensitive   = true
}

variable "vkcs_password" {
  description = "VK Cloud password"
  type        = string
  sensitive   = true
}

variable "vkcs_project_id" {
  description = "VK Cloud Project ID"
  type        = string
}

variable "vkcs_region" {
  description = "VK Cloud region"
  type        = string
  default     = "RegionOne"
}

variable "availability_zone" {
  description = "Availability zone"
  type        = string
  default     = "GZ1"  # или MS1, ME1 в зависимости от региона
}

variable "ssh_public_key_path" {
  description = "Path to SSH public key"
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}
```

### Outputs:
```hcl
output "vm_ip" {
  value = vkcs_networking_floatingip.interview.address
}

output "ssh_command" {
  value = "ssh ubuntu@${vkcs_networking_floatingip.interview.address}"
}
```

---

# 4 ЗАДАЧИ ДЛЯ TROUBLESHOOTING

## Задача 1: Docker — Port недоступен + найти compose

### Легенда:
"Разработчик жалуется, что приложение не отвечает на порту 8080. Контейнер запущен, но curl возвращает connection refused. Найди проблему и конфиг."

### Что ломаем:
- Приложение слушает 127.0.0.1:8080 вместо 0.0.0.0:8080
- compose.yaml в нестандартном месте: /opt/apps/webapp/deploy/

### Реализация:
```yaml
# /opt/apps/webapp/deploy/compose.yaml
services:
  webapp:
    image: python:3.11-slim
    container_name: webapp
    ports:
      - "8080:8080"
    command: python -m http.server 8080 --bind 127.0.0.1  # BUG!
    working_dir: /app
    volumes:
      - ./html:/app
```

### Симптомы:
```bash
$ docker ps                 # контейнер running
$ curl localhost:8080       # connection refused
```

### Решение:
```bash
docker exec webapp netstat -tlnp  # видит 127.0.0.1:8080
docker inspect webapp --format '{{index .Config.Labels "com.docker.compose.project.config_files"}}'
# Исправить --bind 127.0.0.1 на --bind 0.0.0.0
```

---

## Задача 2: DNS не работает

### Легенда:
"curl google.com не работает, но ping по IP работает. Почини."

### Что ломаем:
- /etc/resolv.conf содержит nameserver 10.255.255.1 (не существует)
- systemd-resolved остановлен

### Симптомы:
```bash
$ ping 8.8.8.8      # работает
$ ping google.com   # Temporary failure in name resolution
```

### Решение:
```bash
cat /etc/resolv.conf           # видит 10.255.255.1
echo "nameserver 8.8.8.8" > /etc/resolv.conf
# или systemctl start systemd-resolved
```

---

## Задача 3: Kubernetes — CrashLoopBackOff

### Легенда:
"Под постоянно рестартится, разработчики говорят что приложение работает."

### Что ломаем:
- Probe path /health, а приложение отдаёт на /healthz

### Реализация:
```yaml
# ConfigMap - nginx отдаёт /healthz
location /healthz { return 200 'OK'; }

# Deployment - probe на /health (НЕПРАВИЛЬНО!)
readinessProbe:
  httpGet:
    path: /health  # должно быть /healthz
```

### Симптомы:
```bash
$ kubectl -n interview get pods    # CrashLoopBackOff
$ kubectl -n interview describe pod webapp-xxx
# Events: Readiness probe failed: HTTP probe failed with statuscode: 404
```

### Решение:
```bash
kubectl -n interview describe pod    # видит probe failed 404
kubectl -n interview exec webapp-xxx -- curl localhost/healthz  # 200 OK
kubectl -n interview edit deployment webapp  # исправить /health → /healthz
```

---

## Задача 4: GitLab Runner — Jobs не выполняются

### Легенда:
"Runner зарегистрирован, jobs падают сразу. Разберись."

### Что ломаем:
- gitlab-runner работает
- executor = docker в config.toml
- Docker daemon ОСТАНОВЛЕН

### Симптомы:
```bash
$ systemctl status gitlab-runner   # active (running)
$ cat /etc/gitlab-runner/config.toml  # executor = "docker"
$ docker ps                        # Cannot connect to Docker daemon
```

### Решение:
```bash
systemctl start docker
```

---

# ANSIBLE — РОЛИ ДЛЯ КАЖДОЙ ЗАДАЧИ

## Структура:

devops-interview-tasks/
├── .env.example                 # Шаблон credentials
├── .env                         # Credentials (не в git!)
├── .gitignore                   # .env, *.tfstate, etc
├── README.md
├── docs/
│   ├── TASKS.md                 # Описания задач
│   └── SOLUTIONS.md             # Решения
├── terraform/
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   └── versions.tf
├── ansible/
│   ├── ansible.cfg
│   ├── inventory/
│   │   └── hosts.yml            # Генерируется
│   ├── playbooks/
│   │   └── setup-all.yml
│   └── roles/
│       ├── common/
│       │   └── tasks/main.yml
│       ├── docker-broken/
│       │   ├── tasks/main.yml
│       │   └── templates/compose.yaml.j2
│       ├── dns-broken/
│       │   └── tasks/main.yml
│       ├── k8s-broken/
│       │   └── tasks/main.yml
│       └── gitlab-broken/
│           ├── tasks/main.yml
│           └── templates/config.toml.j2
└── scripts/
├── deploy.sh
└── destroy.sh



---

# ВАЖНО

1. DNS задача СТРОГО ПОСЛЕДНЯЯ в playbook — иначе apt сломается
2. k3s использовать с --disable=traefik
3. GitLab Runner — fake token для демо, не нужна реальная регистрация
4. .env должен быть в .gitignore
5. deploy.sh должен сам создавать .env из .env.example если его нет
6. Terraform генерирует ansible inventory автоматически

---

# ФОРМАТ ВЫВОДА

Создай ВСЕ файлы с полным содержимым:
- terraform/*.tf
- ansible/ansible.cfg + все roles + playbooks
- scripts/deploy.sh, destroy.sh (executable)
- .env.example, .gitignore
- README.md, docs/TASKS.md, docs/SOLUTIONS.md

Файлы должны быть ГОТОВЫ К ИСПОЛЬЗОВАНИЮ. После создания выведи:
1. Структуру проекта (tree)
2. Инструкцию: как заполнить .env и запустить ./deploy.sh
PROMPT END

Использование
bash# 1. Открыть Claude Code
claude

# 2. Скопировать весь prompt выше и вставить

# 3. Claude Code создаст проект

# 4. Настроить credentials (ОДИН РАЗ)
cd devops-interview-tasks
./scripts/deploy.sh
# Скрипт создаст .env из шаблона
vim .env
# Заполнить: username, password, project_id

# 5. Деплой (перед каждым собесом)
./scripts/deploy.sh

# 6. После собеса
./scripts/destroy.sh