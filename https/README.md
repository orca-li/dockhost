# Utils

```bash
sudo apt update
sudo apt install certbot python3-certbot-nginx
```

# Config

```nginx
# sudo vim /etc/nginx/sites-enabled/default
server {
    listen 80;
    server_name твой_домен;

    location / {
        return 301 https://$host$request_uri;
    }
}

server {
    listen 443 ssl;
    server_name твой_домен;

    ssl_certificate /etc/letsencrypt/live/твой_домен/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/твой_домен/privkey.pem;

    location / {
        proxy_pass http://192.168.0.100;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-Proto https;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
}
```

# Enable

```
sudo certbot --nginx -d твой_домен_или_IP_белого_сервера
sudo systemctl reload nginx
```
