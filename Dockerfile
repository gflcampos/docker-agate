#
# agate Dockerfile
#
# https://github.com/obiba/docker-agate
#

# Pull base image
FROM openjdk:8

LABEL OBiBa <dev@obiba.org>

# grab gosu for easy step-down from root
# see https://github.com/tianon/gosu/blob/master/INSTALL.md
ENV GOSU_VERSION 1.10
ENV GOSU_KEY B42F6819007F00F88E364FD4036A9C25BF357DD4
RUN set -ex; \
  \
  fetchDeps=' \
    ca-certificates \
    wget \
  '; \
  apt-get update; \
  apt-get install -y --no-install-recommends $fetchDeps; \
  rm -rf /var/lib/apt/lists/*; \
  \
  dpkgArch="$(dpkg --print-architecture | awk -F- '{ print $NF }')"; \
  wget -O /usr/local/bin/gosu "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$dpkgArch"; \
  wget -O /usr/local/bin/gosu.asc "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$dpkgArch.asc"; \
  \
# verify the signature
  export GNUPGHOME="$(mktemp -d)"; \
  timeout 30s  gpg --keyserver pgp.mit.edu --recv-keys "$GOSU_KEY" || \
  timeout 30s  gpg --keyserver keyserver.pgp.com --recv-keys "$GOSU_KEY" || \
  timeout 30s  gpg --keyserver ha.pool.sks-keyservers.net --recv-keys "$GOSU_KEY"; \
  gpg --batch --verify /usr/local/bin/gosu.asc /usr/local/bin/gosu; \
  rm -rf "$GNUPGHOME" /usr/local/bin/gosu.asc; \
  \
  chmod +x /usr/local/bin/gosu; \
# verify that the binary works
  gosu nobody true;

ENV LANG C.UTF-8
ENV LANGUAGE C.UTF-8
ENV LC_ALL C.UTF-8

ENV AGATE_ADMINISTRATOR_PASSWORD=password
ENV AGATE_HOME=/srv
ENV JAVA_OPTS=-Xmx2G
ENV NVM_VERSION=v0.33.11
ENV NODE_VERSION=4.4.0
ENV MVN_VERSION=3.5.3

# Build Agate
RUN \
  # Install all tools for building agate
  #
  apt-get update && \
  apt-get install -y daemon nodejs devscripts rpm devscripts fakeroot debhelper software-properties-common && \
  add-apt-repository -y ppa:chris-lea/node.js && \
  curl -o- https://raw.githubusercontent.com/creationix/nvm/${NVM_VERSION}/install.sh | bash && \
  export NVM_DIR="$HOME/.nvm" && \
  [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  && \
  [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  && \
  nvm install ${NODE_VERSION} && \
  npm install -g grunt-cli bower && \
  echo '{ "allow_root": true }' > /root/.bowerrc && \
  #
  # Download master and MAVEN
  #
  mkdir -p /tmp/nightly-agate && \
  cd /tmp/nightly-agate && \
  curl -L http://apache.mirror.rafal.ca/maven/maven-3/${MVN_VERSION}/binaries/apache-maven-3.5.3-bin.tar.gz | tar xz && \
  curl -L https://github.com/obiba/agate/archive/master.tar.gz | tar zx && \
  #
  # Build all and the RPM and DEB packages
  #
  cd agate-master && \
  ../apache-maven-${MVN_VERSION}/bin/mvn install && \
  ../apache-maven-${MVN_VERSION}/bin/mvn install -Prelease && \
  #
  # Install Agate
  #
  DEBIAN_FRONTEND=noninteractive dpkg -i ./agate-dist/target/agate*.deb && \
  #
  # Clean up
  #
  cd /tmp && \
  rm -rf nightly-agate && \
  apt-get purge -y devscripts rpm devscripts fakeroot debhelper software-properties-common

RUN chmod +x /usr/share/agate/bin/agate

COPY bin /opt/agate/bin

RUN chmod +x -R /opt/agate/bin
RUN chown -R agate /opt/agate

VOLUME /srv

# http and https
EXPOSE 8081 8444

# Define default command.
COPY ./docker-entrypoint.sh /
ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["app"]
