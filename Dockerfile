#Stage 1 - Build Vue frontend
FROM python:3.12-alpine3.19 AS build

#Install build dependencies
RUN apk add git yarn

#Set environment variables
ENV PYTHONUNBUFFERED 1
ENV DOCKER true

#Create app dir and copy files in
RUN mkdir /opt/recipes
WORKDIR /opt/recipes
COPY . ./

#Build Vue frontend
WORKDIR /opt/recipes/vue
RUN yarn install --frozen-lockfile && yarn build

#Remove development dependencies from requirements.txt
WORKDIR /opt/recipes
RUN sed -i '/# Development/,$d' requirements.txt

#Install app dependencies
RUN \
    if [ `apk --print-arch` = "armv7" ]; then \
    printf "[global]\nextra-index-url=https://www.piwheels.org/simple\n" > /etc/pip.conf ; \
    fi
RUN apk add --no-cache --virtual .build-deps gcc musl-dev postgresql-dev zlib-dev jpeg-dev libwebp-dev openssl-dev libffi-dev cargo openldap-dev python3-dev && \
    echo -n "INPUT ( libldap.so )" > /usr/lib/libldap_r.so && \
    python -m venv venv && \
    /opt/recipes/venv/bin/python -m pip install --upgrade pip && \
    venv/bin/pip install wheel==0.42.0 && \
    venv/bin/pip install setuptools_rust==1.9.0 && \
    venv/bin/pip install -r requirements.txt --no-cache-dir &&\
    apk --purge del .build-deps

#Print version details
RUN /opt/recipes/venv/bin/python version.py

#Clean up
WORKDIR /opt/recipes
RUN find . -type d -name "node_modules" | xargs rm -rf && \
    rm -rf npm-debug.log Dockerfile* docker-compose* .dockerignore .gitignore README.md LICENSE .vscode .env .env.template .github .idea .prettierignore \
           LICENSE.md docs update.sh .pytest_cache cookbook/tests mediafiles staticfiles db.sqlite3 pytest.ini mkdocs.yml vue/babel.config* vue/package.json \
           vue/tsconfig.json vue/src/utils/openapi && \
    find ./vue -type f -name "*.vue" | xargs rm && \
    find ./vue -type f -name "*.ts" | xargs rm && \
    find . -type d -name ".openapi-generator" | xargs rm -rf && \
    find . -type d -name ".git" | xargs rm -rf

#Stage 2 - Deploy
FROM python:3.12-alpine3.19

#Install dependencies
RUN apk add --no-cache postgresql-libs postgresql-client gettext zlib libjpeg libwebp libxml2-dev libxslt-dev openldap git

#Set environment variables
ENV PYTHONUNBUFFERED 1
ENV DOCKER true

#Expose port 8080
EXPOSE 8080

#Copy app files from build stage and set working directory
COPY --from=build /opt/recipes /opt/recipes
WORKDIR /opt/recipes

# commented for now https://github.com/TandoorRecipes/recipes/issues/3478
#HEALTHCHECK --interval=30s \
#            --timeout=5s \
#            --start-period=10s \
#            --retries=3 \
#            CMD [ "/usr/bin/wget", "--no-verbose", "--tries=1", "--spider", "http://127.0.0.1:8080/openapi" ]

#Start the app
RUN chmod +x boot.sh
ENTRYPOINT ["/opt/recipes/boot.sh"]
