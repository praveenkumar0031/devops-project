FROM nginx:alpine

# This line tells Nginx to explicitly send "Content-Type: text/html; charset=utf-8"
RUN sed -i 's/index  index.html index.htm;/index  index.html index.htm;\n    charset utf-8;/' /etc/nginx/conf.d/default.conf

COPY index.html /usr/share/nginx/html/
COPY style.css /usr/share/nginx/html/
COPY script.js /usr/share/nginx/html/

EXPOSE 80