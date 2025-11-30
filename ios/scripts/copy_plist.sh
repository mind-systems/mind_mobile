#!/bin/bash

# Скрипт автоматического копирования конфигов в зависимости от окружения (dev/prod)
# Копирует Info.plist и GoogleService-Info.plist

PLIST_DIR="${SRCROOT}/Runner"

# Определяем конфигурацию по названию схемы или конфигурации
if [[ "${CONFIGURATION}" == *"Debug"* ]] || [[ "${PRODUCT_BUNDLE_IDENTIFIER}" == *".dev" ]]; then
    echo "🔧 Development configuration detected"

    # Копируем Info.plist
    if [ -f "${PLIST_DIR}/Info-dev.plist" ]; then
        cp -f "${PLIST_DIR}/Info-dev.plist" "${PLIST_DIR}/Info.plist"
        echo "  ✅ Info-dev.plist → Info.plist"
    else
        echo "  ⚠️  Warning: Info-dev.plist not found"
    fi

    # Копируем GoogleService-Info.plist
    if [ -f "${PLIST_DIR}/GoogleService-Info-dev.plist" ]; then
        cp -f "${PLIST_DIR}/GoogleService-Info-dev.plist" "${PLIST_DIR}/GoogleService-Info.plist"
        echo "  ✅ GoogleService-Info-dev.plist → GoogleService-Info.plist"
    else
        echo "  ⚠️  Warning: GoogleService-Info-dev.plist not found"
    fi

elif [[ "${CONFIGURATION}" == *"Release"* ]] || [[ "${CONFIGURATION}" == *"Profile"* ]]; then
    echo "🚀 Production configuration detected"

    # Копируем Info.plist
    if [ -f "${PLIST_DIR}/Info-prod.plist" ]; then
        cp -f "${PLIST_DIR}/Info-prod.plist" "${PLIST_DIR}/Info.plist"
        echo "  ✅ Info-prod.plist → Info.plist"
    else
        echo "  ⚠️  Warning: Info-prod.plist not found"
    fi

    # Копируем GoogleService-Info.plist
    if [ -f "${PLIST_DIR}/GoogleService-Info-prod.plist" ]; then
        cp -f "${PLIST_DIR}/GoogleService-Info-prod.plist" "${PLIST_DIR}/GoogleService-Info.plist"
        echo "  ✅ GoogleService-Info-prod.plist → GoogleService-Info.plist"
    else
        echo "  ⚠️  Warning: GoogleService-Info-prod.plist not found"
    fi

else
    echo "⚠️  Unknown configuration: ${CONFIGURATION} - using prod configs by default"
    cp -f "${PLIST_DIR}/Info-prod.plist" "${PLIST_DIR}/Info.plist" 2>/dev/null || true
    cp -f "${PLIST_DIR}/GoogleService-Info-prod.plist" "${PLIST_DIR}/GoogleService-Info.plist" 2>/dev/null || true
fi

echo "✅ Configuration files updated successfully"