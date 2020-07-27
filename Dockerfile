FROM nginx
COPY . /var/www/kubernetes
COPY kubernetes.conf /etc/nginx/conf.d
