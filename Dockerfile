FROM nginx:alpine
COPY index.html /usr/share/nginx/html/index.html
EXPOSE 80
HEALTHCHECK --interval=10s --timeout=3s --start-period=5s --retries=3 \
  CMD wget -q -O /dev/null http://localhost:80/ || exit 1
CMD ["nginx", "-g", "daemon off;"]