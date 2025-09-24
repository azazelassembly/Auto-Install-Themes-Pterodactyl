#!/usr/bin/env bash
set -euo pipefail

# Цвета
BLUE='\033[0;34m'
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

TMP_DIR="/tmp/ptero_theme_install"
THEME_DIR="$TMP_DIR/pterodactyl"

# Определяем пакетный менеджер и архитектуру
detect_system() {
  if command -v apt >/dev/null 2>&1; then
    PKG_MANAGER="apt"
  elif command -v pacman >/dev/null 2>&1; then
    PKG_MANAGER="pacman"
  else
    echo -e "${RED}Неизвестный пакетный менеджер. Поддерживаются apt и pacman.${NC}"
    exit 1
  fi

  ARCH=$(uname -m)
  echo -e "${BLUE}Detected pkg manager: ${PKG_MANAGER}, arch: ${ARCH}${NC}"
}

# Приветствие
display_welcome() {
  clear
  echo -e ""
  echo -e "${BLUE}[+] =============================================== [+]${NC}"
  echo -e "${BLUE}[+]                АВТОМАТИЧЕСКИЙ УСТАНОВЩИК ТЕМА    [+]${NC}"
  echo -e "${BLUE}[+]                  © Games Hosting               [+]${NC}"
  echo -e "${BLUE}[+] =============================================== [+]${NC}"
  echo -e ""
  echo -e "Этот скрипт создан для облегчения установки темы Птеродактиль"
  echo -e ""
  sleep 2
}

# Установка базовых утилит (jq, wget, unzip, php -> минимально)
install_base_packages() {
  echo -e "${BLUE}[+] Установка базовых пакетов...${NC}"
  if [ "$PKG_MANAGER" = "apt" ]; then
    sudo apt update
    sudo apt install -y wget unzip jq curl sudo ca-certificates build-essential php php-cli php-mbstring php-xml php-zip php-sqlite3
  else
    sudo pacman -Syu --noconfirm
    sudo pacman -S --noconfirm wget unzip jq curl base-devel php php-mbstring php-xml php-zip php-sqlite
  fi
  echo -e "${GREEN}[+] Базовые пакеты установлены.${NC}"
}

# Установка Node.js и Yarn в зависимости от менеджера
install_node_yarn() {
  echo -e "${BLUE}[+] Установка Node.js и Yarn...${NC}"
  if [ "$PKG_MANAGER" = "apt" ]; then
    # NodeSource поддерживает x86_64 и arm64; setup_16.x подойдёт для большинства систем Debian/Ubuntu
    curl -sL https://deb.nodesource.com/setup_16.x | sudo -E bash -
    sudo apt install -y nodejs
    sudo npm i -g yarn
  else
    # Arch: пакеты в репозитории
    sudo pacman -S --noconfirm nodejs npm yarn
    # npm глобальные пакеты с sudo могут создавать проблемы; но оставим установку yarn как есть (Arch уже установил yarn)
  fi
  echo -e "${GREEN}[+] Node.js и Yarn готовы.${NC}"
}

# Проверка лицензионного кода (токена)
check_token() {
  echo -e "${BLUE}[+] Проверьте лицензионный код${NC}"
  read -rp "ВХОДНОЙ ТОКЕН ДОСТУПА: " USER_TOKEN
  if [ "$USER_TOKEN" = "2024" ]; then
    echo -e "${GREEN}ДОСТУП УСПЕШНЫЙ${NC}"
  else
    echo -e "${RED}Неправильный токен! Купить код токена на Games Hosting${NC}"
    echo -e "${YELLOW}TELEGRAM : @GamesHosting${NC}"
    exit 1
  fi
}

# Загрузка и распаковка выбранной темы
download_and_extract_theme() {
  local url="$1"
  mkdir -p "$TMP_DIR"
  cd "$TMP_DIR"
  echo -e "${BLUE}[+] Скачиваем тему: $url${NC}"
  wget -q --show-progress -O "$(basename "$url")" "$url"
  unzip -o "$(basename "$url")" -d "$THEME_DIR"
  echo -e "${GREEN}[+] Тема распакована в ${THEME_DIR}${NC}"
}

# Копирование темы и билд
apply_theme_and_build() {
  local theme_name="$1"
  if [ ! -d "$THEME_DIR" ]; then
    echo -e "${RED}Тема не найдена: $THEME_DIR${NC}"
    return 1
  fi

  echo -e "${BLUE}[+] Копирование темы в /var/www/pterodactyl ...${NC}"
  sudo mkdir -p /var/www/pterodactyl
  sudo cp -rfT "$THEME_DIR" /var/www/pterodactyl

  echo -e "${BLUE}[+] Установка зависимостей и сборка темы...${NC}"
  cd /var/www/pterodactyl || { echo -e "${RED}Не удалось перейти в /var/www/pterodactyl${NC}"; return 1; }

  # Если в проекте нет package.json, пропускаем node-часть
  if [ -f package.json ]; then
    # Установка react-feather, если нужно
    if ! grep -q "react-feather" package.json 2>/dev/null; then
      yarn add react-feather || true
    fi
    # миграции и сборка (php и yarn должны быть установлены)
    if command -v php >/dev/null 2>&1; then
      php artisan migrate --force || true
    fi
    if command -v yarn >/dev/null 2>&1; then
      yarn build:production || true
    fi
    if command -v php >/dev/null 2>&1; then
      php artisan view:clear || true
    fi
  else
    echo -e "${YELLOW}В /var/www/pterodactyl нет package.json — пропускаем npm/yarn шаги.${NC}"
  fi

  # Очистка
  sudo rm -rf "$TMP_DIR"
  echo -e "${GREEN}[+] Тема успешно применена.${NC}"
}

# Удаление темы (repair)
uninstall_theme() {
  echo -e "${BLUE}[+] Удаление темы (восстановление)${NC}"
  bash <(curl -s https://raw.githubusercontent.com/Nur4ik00p/Auto-Install-Thema-Pterodactyl/main/repair.sh) || true
  echo -e "${GREEN}[+] Удаление выполнено.${NC}"
}

# Создать узел (интерактивно)
create_node() {
  echo -e "${BLUE}[+] Создание узла (node) — интерактивно${NC}"
  read -rp "Введите название локации: " location_name
  read -rp "Введите описание местоположения: " location_description
  read -rp "Введите домен: " domain
  read -rp "Введите имя узла: " node_name
  read -rp "Введите ОЗУ (в МБ): " ram
  read -rp "Введите максимальный объём диска (в МБ): " disk_space
  read -rp "Введите Локация айди: " locid

  cd /var/www/pterodactyl || { echo -e "${RED}Каталог /var/www/pterodactyl не найден${NC}"; return 1; }

  php artisan p:location:make <<EOF || true
$location_name
$location_description
EOF

  php artisan p:node:make <<EOF || true
$node_name
$location_description
$locid
https
$domain
yes
no
no
$ram
$ram
$disk_space
$disk_space
100
8080
2022
/var/lib/pterodactyl/volumes
EOF

  echo -e "${GREEN}[+] Узел и локация созданы (если команды artisan доступны).${NC}"
}

# Настройка wings (минимально)
configure_wings() {
  read -rp "Введите токен для wings: " wings_token
  # Тут простая демонстрация — в реальности надо корректно добавлять токен в конфиг wings
  echo -e "${BLUE}Попытка запустить wings (systemd) и экспортировать токен в окружение...${NC}"
  # Пример (не меняет файлы конфигов, пользователь должен вручную внести токен)
  if systemctl --version >/dev/null 2>&1; then
    sudo systemctl restart wings || sudo systemctl start wings || true
    echo -e "${GREEN}[+] wings перезапущен (если он установлен).${NC}"
  else
    echo -e "${YELLOW}systemd не обнаружен — пропускаем перезапуск wings.${NC}"
  fi
}

# Создать аккаунт (hackback_panel) — мы оставляем функционал создания пользователя через artisan
create_panel_account() {
  read -rp "Введите email для аккаунта: " email
  read -rp "Введите имя пользователя: " username
  read -rp "Введите пароль: " passwd
  cd /var/www/pterodactyl || { echo -e "${RED}Каталог /var/www/pterodactyl не найден${NC}"; return 1; }

  php artisan p:user:make <<EOF || true
yes
$email
$username
$username
$username
$passwd
EOF

  echo -e "${GREEN}[+] Аккаунт добавлен (если artisan доступен).${NC}"
}

# Изменить пароль VPS (локально)
change_vps_password() {
  read -rp "Введите имя пользователя для смены пароля (или нажмите Enter для root): " target
  target=${target:-root}
  read -rsp "Введите новый пароль: " pw
  echo
  echo -rsp "Подтвердите новый пароль: " pw2
  echo
  if [ "$pw" != "$pw2" ]; then
    echo -e "${RED}Пароли не совпадают.${NC}"
    return 1
  fi
  echo "${target}:${pw}" | sudo chpasswd
  echo -e "${GREEN}[+] Пароль изменён для пользователя ${target}.${NC}"
}

# Меню выбора темы
install_theme_menu() {
  while true; do
    echo -e ""
    echo -e "${BLUE}Выберите тему для установки:${NC}"
    echo "1) stellar"
    echo "2) billing"
    echo "3) enigma"
    echo "x) Назад"
    read -rp "Введите 1/2/3/x: " SELECT_THEME
    case "$SELECT_THEME" in
      1)
        THEME_URL="https://github.com/Nur4ik00p/Auto-Install-Thema-Pterodactyl/raw/main/stellar.zip"
        download_and_extract_theme "$THEME_URL"
        apply_theme_and_build "stellar"
        return
        ;;
      2)
        THEME_URL="https://github.com/Nur4ik00p/Auto-Install-Thema-Pterodactyl/raw/main/billing.zip"
        download_and_extract_theme "$THEME_URL"
        apply_theme_and_build "billing"
        return
        ;;
      3)
        THEME_URL="https://github.com/Nur4ik00p/Auto-Install-Thema-Pterodactyl/raw/main/enigma.zip"
        download_and_extract_theme "$THEME_URL"
        apply_theme_and_build "enigma"
        return
        ;;
      x|X)
        return
        ;;
      *)
        echo -e "${RED}Неверный выбор, повторите.${NC}"
        ;;
    esac
  done
}

# Главная логика
main() {
  detect_system
  display_welcome
  check_token
  install_base_packages
  install_node_yarn

  while true; do
    echo -e ""
    echo -e "${BLUE}МЕНЮ:${NC}"
    echo "1) Установить темы"
    echo "2) Удаление тем (repair)"
    echo "3) Настройка wings (минимально)"
    echo "4) Создать узлы"
    echo "5) Удаление/переустановка панели (installer)"
    echo "6) Быстрая установка Stellar (скачать и применить)"
    echo "7) Создать аккаунт панели"
    echo "8) Изменить пароль VPS"
    echo "x) Выход"
    read -rp "Выберите опцию: " MENU_CHOICE
    case "$MENU_CHOICE" in
      1) install_theme_menu ;;
      2) uninstall_theme ;;
      3) configure_wings ;;
      4) create_node ;;
      5)
        echo -e "${BLUE}Запуск официального инсталлятора Pterodactyl (если доступен)${NC}"
        bash <(curl -s https://pterodactyl-installer.se) || true
        ;;
      6)
        THEME_URL="https://github.com/Nur4ik00p/Auto-Install-Thema-Pterodactyl/raw/main/stellar.zip"
        download_and_extract_theme "$THEME_URL"
        apply_theme_and_build "stellar"
        ;;
      7) create_panel_account ;;
      8) change_vps_password ;;
      x|X) echo "Выход."; exit 0 ;;
      *) echo -e "${RED}Неверный выбор.${NC}" ;;
    esac
  done
}

# Запуск
main
