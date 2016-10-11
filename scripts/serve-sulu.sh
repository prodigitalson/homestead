mkdir /etc/nginx/ssl 2>/dev/null
openssl genrsa -out "/etc/nginx/ssl/$1.key" 2048 2>/dev/null
openssl req -new -key /etc/nginx/ssl/$1.key -out /etc/nginx/ssl/$1.csr -subj "/CN=$1/O=Vagrant/C=UK" 2>/dev/null
openssl x509 -req -days 365 -in /etc/nginx/ssl/$1.csr -signkey /etc/nginx/ssl/$1.key -out /etc/nginx/ssl/$1.crt 2>/dev/null

block="server {
    listen ${3:-80};
    listen ${4:-443} ssl;
    server_name $1;
    root \"$2\";

    error_log /var/log/nginx/$1.error.log;
    access_log /var/log/nginx/$1.access.log;

    # strip app.php/ prefix if it is present
    rewrite ^/app\.php/?(.*)\$ /\$1 permanent;

    location /admin {
        index admin.php;
        try_files \$uri @rewriteadmin;
    }

    location @rewriteadmin {
        rewrite ^(.*)\$ /admin.php/\$1 last;
    }

    location / {
      index website.php;
      try_files \$uri @rewritewebsite;
    }

    # expire
    location ~* \.(?:ico|css|js|gif|jpe?g|png)\$ {
        try_files \$uri /website.php/\$1;
        access_log off;
        expires 30d;
        add_header Pragma public;
        add_header Cache-Control \"public\";
    }

    location @rewritewebsite {
        rewrite ^(.*)\$ /website.php/\$1 last;
    }

    # pass the PHP scripts to FastCGI server from upstream phpfcgi
    location ~ ^/(website|admin|app|app_dev|config)\.php(/|\$) {
        include fastcgi_params;
        fastcgi_pass unix:/var/run/php5-fpm.sock;
        fastcgi_buffers 16 16k;
        fastcgi_buffer_size 32k;
        fastcgi_split_path_info ^(.+\.php)(/.*)\$;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        fastcgi_param SYMFONY_ENV dev;
    }

    ssl_certificate     /etc/nginx/ssl/$1.crt;
    ssl_certificate_key /etc/nginx/ssl/$1.key;
}
"

echo "$block" > "/etc/nginx/sites-available/$1"
ln -fs "/etc/nginx/sites-available/$1" "/etc/nginx/sites-enabled/$1"
service nginx restart
service php7.0-fpm restart
