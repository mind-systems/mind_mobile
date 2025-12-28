#!/bin/bash

# Скрипт автоматического копирования конфигов в зависимости от окружения (dev/prod)
# Копирует GoogleService-Info.plist

PLIST_DIR="${SRCROOT}/Runner"

# Определяем flavor по названию конфигурации
if [[ "${CONFIGURATION}" == *"-dev"* ]]; then
    echo "🔧 Development configuration detected (${CONFIGURATION})"

    # Копируем GoogleService-Info.plist
    if [ -f "${PLIST_DIR}/GoogleService-Info-dev.plist" ]; then
        cp -f "${PLIST_DIR}/GoogleService-Info-dev.plist" "${PLIST_DIR}/GoogleService-Info.plist"
        echo "  ✅ GoogleService-Info-dev.plist → GoogleService-Info.plist"
    else
        echo "  ⚠️  Warning: GoogleService-Info-dev.plist not found"
    fi

elif [[ "${CONFIGURATION}" == *"-prod"* ]]; then
    echo "🚀 Production configuration detected (${CONFIGURATION})"

    # Копируем GoogleService-Info.plist
    if [ -f "${PLIST_DIR}/GoogleService-Info-prod.plist" ]; then
        cp -f "${PLIST_DIR}/GoogleService-Info-prod.plist" "${PLIST_DIR}/GoogleService-Info.plist"
        echo "  ✅ GoogleService-Info-prod.plist → GoogleService-Info.plist"
    else
        echo "  ⚠️  Warning: GoogleService-Info-prod.plist not found"
    fi

else
    echo "⚠️  Unknown configuration: ${CONFIGURATION} - using prod configs by default"
    cp -f "${PLIST_DIR}/GoogleService-Info-prod.plist" "${PLIST_DIR}/GoogleService-Info.plist" 2>/dev/null || true
fi

echo "✅ Configuration files updated successfully"