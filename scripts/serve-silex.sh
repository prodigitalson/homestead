mkdir /etc/nginx/ssl 2>/dev/null
openssl genrsa -out "/etc/nginx/ssl/$1.key" 2048 2>/dev/null
openssl req -new -key /etc/nginx/ssl/$1.key -out /etc/nginx/ssl/$1.csr -subj "/CN=$1/O=Vagrant/C=UK" 2>/dev/null
openssl x509 -req -days 365 -in /etc/nginx/ssl/$1.csr -signkey /etc/nginx/ssl/$1.key -out /etc/nginx/ssl/$1.crt 2>/dev/null
block="
server {
    listen ${3:-80};
    listen ${4:-443} ssl;
    server_name $1;
    root \"$2\";

    error_log /var/log/nginx/$1.error.log;
    access_log /var/log/nginx/$1.access.log;

    location / {
        # try to serve file directly, fallback to front controller
        try_files \$uri /index.php\$is_args\$args;
    }

    # If you have 2 front controllers for dev|prod use the following line instead
    location ~ ^/(index|index_dev)\.php(/|\$) {
    # location ~ ^/index\.php(/|\$) {

        # the ubuntu default
        # fastcgi_pass   unix:/var/run/php/phpX.X-fpm.sock;

        # for running on centos (and apparently OOTB Homestead)
        fastcgi_pass   unix:/var/run/php-fpm/www.sock;

        fastcgi_buffers 16 16k;
        fastcgi_buffer_size 32k;

        fastcgi_split_path_info ^(.+\.php)(/.*)\$;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        fastcgi_param HTTPS off;

        # Prevents URIs that include the front controller. This will 404:
        # http://$1/index.php/some-path
        # Enable the internal directive to disable URIs like this
        # internal;
    }

    #return 404 for all php files as we do have a front controller
    location ~ \.php\$ {
        return 404;
    }

    ssl_certificate     /etc/nginx/ssl/$1.crt;
    ssl_certificate_key /etc/nginx/ssl/$1.key;

}
"

echo "$block" > "/etc/nginx/sites-available/$1"
ln -fs "/etc/nginx/sites-available/$1" "/etc/nginx/sites-enabled/$1"
service nginx restart
service php7.0-fpm restart
