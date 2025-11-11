#!/bin/bash
#Exit immediately on error, treating unset variables as error.
set -eu

#Empty string as argument if none given - may be redundant?
COMMAND=${1:-}

# Need to decide which DB to use rather than this else nonesense.
if [[ -v DB_HOST && -v DB_PORT && -n $DB_HOST && -n $DB_PORT ]] ; then
  if ! wait-for-it $DB_HOST:$DB_PORT --timeout=360 ; then
    echo "Database host not available"
    exit 3
  fi
elif ! [[ -S /var/run/mysqld/mysqld.sock ]] ; then
  echo "Database socket not available"
  exit 3
fi

case "$COMMAND" in
    gunicorn)
        echo "Running database migrations"
        /venv/bin/python3 /site/manage.py migrate
        #Temp secret key used, not great?
        SECRET_KEY="X" /venv/bin/python3 /site/manage.py collectstatic --noinput --settings=toolkit.settings
        exec /venv/bin/gunicorn wsgi --bind 0.0.0.0:8000 --chdir /site
        ;;
    mailerd)
        exec /venv/bin/python3 /site/manage.py mailerd
        ;;
    localdev)
        echo "Running database migrations"
        /venv/bin/python3 /site/manage.py migrate
        SECRET_KEY="X" /venv/bin/python3 /site/manage.py collectstatic --noinput --settings=toolkit.settings
        export DJANGO_SETTINGS_MODULE=toolkit.settings
        /venv/bin/python3 /site/manage.py runserver 0.0.0.0:8000
        ;;
    *)
        echo "Unknown option; expected gunicorn, mailerd or localdev"
        exit 5
        ;;
esac
