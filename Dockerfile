FROM debian:bookworm AS base

## passed in from commandline
ARG ENV_NAME

RUN DEBIAN_FRONTEND=noninteractive apt-get update \
  && apt-get install --yes --no-install-recommends \
  python3 \
  python3-venv \
  vim-tiny \
  libmariadb3 \
  libmagic1 \
  wait-for-it \
  && DEBIAN_FRONTEND=noninteractive apt-get clean \
  && rm -rf /var/lib/apt/lists/*

## Use an intermediate image to build dependency wheels:
FROM base AS build

RUN DEBIAN_FRONTEND=noninteractive apt-get update \
  && apt-get install --yes --no-install-recommends \
  python3-pip \
  build-essential \
  libmariadb-dev \
  libpython3-dev

WORKDIR "/build"

COPY ./requirements ./requirements/

RUN mkdir --parents /build/wheels/ \
    && pip wheel --wheel-dir /build/wheels/ -r /build/requirements/$ENV_NAME.txt

## Deployment image
FROM base AS run

WORKDIR "/site"

COPY --from=build /build/wheels /wheels/
RUN python3 -m venv /venv \
    && /venv/bin/pip install --no-cache-dir --no-index --find-links=/wheels/ /wheels/* \
    && rm -rf /wheels/

COPY . /site/
RUN ln -s /site/toolkit/settings_$ENV_NAME.py /site/toolkit/settings.py
RUN adduser --no-create-home --disabled-login --gecos x toolkit
RUN chown -R toolkit:toolkit /site/ \
     && install -D --owner=toolkit --group=toolkit --directory /site/media/diary \
     && install -D --owner=toolkit --group=toolkit --directory /site/media/documents \
     && install -D --owner=toolkit --group=toolkit --directory /site/media/images \
     && install -D --owner=toolkit --group=toolkit --directory /site/media/printedprogramme \
     && install -D --owner=toolkit --group=toolkit --directory /site/media/volunteers

# app/service user, which runs...
USER toolkit
# ... startup script, with the...
ENTRYPOINT [ "/site/containerconfig/tk_run.sh" ]
# ...default param. Can be overriden in docker CLI or compose
CMD [ "gunicorn" ]

VOLUME ["/site/media"]
VOLUME ["/log/"]

EXPOSE 8000
