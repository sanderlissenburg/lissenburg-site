# Login to docker hub
echo "$DOCKER_PASSWORD" | docker login -u "$DOCKER_ID" --password-stdin

# Pull old images to fill cache
docker pull lissenburg/lissenburg-client
docker pull lissenburg/admin-php-fpm
docker pull lissenburg/admin-nginx

# Build and push images to docker
docker build -t lissenburg/lissenburg-client -f ./client/docker/nginx/Dockerfile ./client
docker push lissenburg/lissenburg-client

echo touch ./admin/.env
echo "APP_ENV=$APP_ENV" >> ./admin/.env
echo "DATABASE_URL=mysql://$DB_USER:$DB_PASSWORD@mysql:3306/$DB_DATABASE?serverVersion=8.0" >> ./admin/.env
echo "APP_DEBUG=0" >> ./admin/.env

echo touch ./deploy/vps/.env
echo "DB_USER=$DB_USER" >> ./deploy/vps/.env
echo "DB_PASSWORD=$DB_PASSWORD" >> ./deploy/vps/.env
echo "DB_DATABASE=$DB_DATABASE" >> ./deploy/vps/.env

docker build -f=admin/docker/php-fpm/Dockerfile -t lissenburg/admin-php-fpm --target php-fpm ./admin
docker build -f=admin/docker/php-fpm/Dockerfile -t lissenburg/admin-nginx --target nginx ./admin
docker push lissenburg/admin-php-fpm
docker push lissenburg/admin-nginx

# Deploy to vps
ssh $SSH_USER@$SSH_HOST 'mkdir -p ~/www/lissenburg/'
scp -r ./deploy/vps/* $SSH_USER@$SSH_HOST:~/www/lissenburg/
scp ./deploy/vps/.env $SSH_USER@$SSH_HOST:~/www/lissenburg/.env
ssh $SSH_USER@$SSH_HOST 'cd ~/www/lissenburg/ && touch acme.json && chmod 600 acme.json'
#  -c <(docker-compose config) instead of  -c docker-compose.yaml, otherwise .env vars will not be applied
ssh $SSH_USER@$SSH_HOST 'cd ~/www/lissenburg/ && docker-compose pull && docker stack deploy -c <(docker-compose config) lissenburg'
ssh $SSH_USER@$SSH_HOST 'docker run --rm --network mysql lissenburg/admin-php-fpm bin/console doctrine:database:create --if-not-exists'
ssh $SSH_USER@$SSH_HOST 'docker run --rm --network mysql lissenburg/admin-php-fpm bin/console doctrine:m:m --no-interaction'
