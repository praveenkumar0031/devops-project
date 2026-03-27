FROM nginx:alpine

# Add charset configuration (same as your friend)
RUN sed -i 's/index  index.html index.htm;/index  index.html index.htm;\n    charset utf-8;/' /etc/nginx/conf.d/default.conf

# Copy your files
COPY index.html /usr/share/nginx/html/
COPY we.mp4 /usr/share/nginx/html/

# Expose port
EXPOSE 80