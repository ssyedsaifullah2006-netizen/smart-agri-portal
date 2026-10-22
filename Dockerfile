# Build and push a deliberately broken v-faulty image (missing index.html)
docker build -t syedsaifullah/smart-agri-portal:v-faulty -f - . <<EOF
FROM nginx:alpine
RUN rm -f /usr/share/nginx/html/index.html
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
EOF

docker push syedsaifullah/smart-agri-portal:v-faulty

# Deploy the faulty version to Kubernetes
kubectl set image deployment/smart-agri-deployment smart-agri-container=syedsaifullah/smart-agri-portal:v-faulty --record=true