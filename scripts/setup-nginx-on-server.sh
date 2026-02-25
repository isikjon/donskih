#!/usr/bin/env bash
# Запускать НА СЕРВЕРЕ (после ssh root@185.23.35.66).
# Настраивает nginx для раздачи админки по /admin.

set -e

SNIPPET='/etc/nginx/snippets/donskih-admin.conf'
MAIN_CONF=''  # задай путь к конфигу сайта, например /etc/nginx/sites-available/donskih-cdn.ru

mkdir -p /etc/nginx/snippets

cat > "$SNIPPET" << 'NGINX'
    location = /admin {
        return 302 /admin/;
    }
    location /admin/ {
        alias /var/www/donskih-admin/;
        try_files $uri $uri/ /admin/index.html;
        add_header Cache-Control "no-cache";
    }
    location /api/v1/admin/content/upload-video {
        client_max_body_size 2048M;
        proxy_request_buffering off;
        proxy_read_timeout 3600s;
        proxy_send_timeout 3600s;
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
    location /api/v1/admin/content/upload-checklist {
        client_max_body_size 2048M;
        proxy_request_buffering off;
        proxy_read_timeout 600s;
        proxy_send_timeout 600s;
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
NGINX

echo "Created $SNIPPET"

# Найти конфиг с server_name donskih-cdn.ru и вставить include
for f in /etc/nginx/sites-enabled/* /etc/nginx/conf.d/*.conf 2>/dev/null; do
  [[ -f "$f" ]] || continue
  if grep -q "server_name.*donskih" "$f" 2>/dev/null; then
    if grep -q "donskih-admin" "$f" 2>/dev/null; then
      echo "Already included in $f"
    else
      # Вставить include перед закрывающей скобкой server { }
      sed -i '/server_name.*donskih/,/^[[:space:]]*}/ {
        /^[[:space:]]*}/i\        include snippets/donskih-admin.conf;
      }' "$f" 2>/dev/null || true
      echo "Try adding to $f manually: include snippets/donskih-admin.conf; inside server { }"
    fi
    echo "Config file: $f"
    break
  fi
done

nginx -t && systemctl reload nginx && echo "Nginx reloaded. Test: https://donskih-cdn.ru/admin/"
