#!/usr/bin/env bash

# runs through django unit tests from within a container

source /venv/bin/activate
SECRET_KEY="X" ./manage.py test --settings=toolkit.test_settings $*
