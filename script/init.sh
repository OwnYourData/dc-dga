#!/bin/bash

# handle DB settings
if [ "$DC_DB" == "postgres" ]
then
	cp config/database_pg.yml config/database.yml
	cp db/migrate_pg/* db/migrate/
fi
if [ "$DC_DB" == "kubernetes" ]
then
	cp config/database_k8s.yml config/database.yml
	cp db/migrate_pg/* db/migrate/
fi
cp config/locales_dao/* config/locales/
cp public_dao/* public/
cp app/assets/images_dao/* app/assets/images/
cp config/initializers_dao/* config/initializers/
echo "copy complete"
bundle exec rake db:create
bundle exec rake active_storage:install
bundle exec rake active_storage:postgresql:install
bundle exec rake db:migrate
bundle exec rake db:seed
bundle exec rails assets:precompile
/usr/src/app/bin/rails server -b 0.0.0.0