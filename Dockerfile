FROM ubuntu:12.04

# Make sure the package repository is up to date
RUN echo "deb http://archive.ubuntu.com/ubuntu precise main universe" > /etc/apt/sources.list && \
      apt-get update

# Set up the environment
ENV DEBIAN_FRONTEND noninteractive
ENV LANGUAGE en_US.UTF-8
ENV LANG en_US.UTF-8
ENV LC_ALL en_US.UTF-8

# Fix encoding-related bug
# https://bugs.launchpad.net/ubuntu/+source/lxc/+bug/813398
RUN apt-get -qy install language-pack-en && \
      locale-gen en_US.UTF-8 && \
      dpkg-reconfigure locales

# Setup the user
RUN sudo useradd buildbox --shell /bin/bash --create-home

# =====================================
#
# Sudo
#
# =====================================

# Allow passwordless sudo
RUN sudo usermod -a -G sudo buildbox && \
      sudo usermod -a -G sudo buildbox && \
      echo 'ALL ALL = (ALL) NOPASSWD: ALL' >> /etc/sudoers

# =====================================
#
# Node.js
#
# =====================================

RUN apt-get install -y --force-yes python-software-properties && \
      add-apt-repository -y ppa:chris-lea/node.js && \
      apt-get update -y && \
      apt-get install -y --force-yes nodejs

# =====================================
#
# Rbenv
#
# =====================================

RUN apt-get install -y --force-yes build-essential curl openssl libssl-dev git-core vim tklib zlib1g-dev libssl-dev libreadline-gplv2-dev libxml2 libxml2-dev libxslt1-dev && \
      git clone https://github.com/sstephenson/rbenv.git /home/buildbox/.rbenv && \
      echo 'export PATH="$HOME/.rbenv/bin:$PATH"' >> /home/buildbox/.profile && \
      echo 'eval "$(rbenv init -)"' >> /home/buildbox/.profile && \
      git clone https://github.com/sstephenson/ruby-build.git /home/buildbox/.rbenv/plugins/ruby-build && \
      echo 'gem: --no-rdoc --no-ri' >> /home/buildbox/.gemrc && \
      chown -R buildbox:buildbox /home/buildbox && \
      su buildbox /bin/bash --login -c "rbenv install 1.9.3-p545 && rbenv local 1.9.3-p545 && gem install bundler && rbenv rehash" && \
      su buildbox /bin/bash --login -c "rbenv install 2.0.0-p247 && rbenv local 2.0.0-p247 && gem install bundler && rbenv rehash" && \
      su buildbox /bin/bash --login -c "rbenv install 2.1.0 && rbenv local 2.1.0 && gem install bundler && rbenv rehash" && \
      su buildbox /bin/bash --login -c "rbenv install 2.1.1 && rbenv local 2.1.1 && gem install bundler && rbenv rehash" && \
      su buildbox /bin/bash --login -c "rbenv global 2.1.1"

# =====================================
#
# PostgreSQL
#
# =====================================

# Add the PostgreSQL PGP key to verify their Debian packages.
# It should be the same key as https://www.postgresql.org/media/keys/ACCC4CF8.asc
RUN apt-key adv --keyserver keyserver.ubuntu.com --recv-keys B97B0AFCAA1A47F044F244A07FCC7D46ACCC4CF8

# Add PostgreSQL's repository. It contains the most recent stable release
# of PostgreSQL, `9.3`.
RUN echo "deb http://apt.postgresql.org/pub/repos/apt/ precise-pgdg main" > /etc/apt/sources.list.d/pgdg.list

# Update the Ubuntu and PostgreSQL repository indexes
RUN apt-get update

# Install `python-software-properties`, `software-properties-common` and PostgreSQL 9.3
#  There are some warnings (in red) that show up during the build. You can hide
#  them by prefixing each apt-get statement with DEBIAN_FRONTEND=noninteractive
RUN apt-get -y --force-yes -q install python-software-properties software-properties-common libpq-dev postgresql-9.3 postgresql-client-9.3 postgresql-contrib-9.3

# Recreate the cluster to be UTF8
RUN service postgresql stop && \
      pg_dropcluster --stop 9.3 main && \
      pg_createcluster -e UTF8 9.3 main

# Note: The official Debian and Ubuntu images automatically `apt-get clean`
# after each `apt-get`

# Add in our custom pg_hba.conf
ADD postgresql/pg_hba.conf /etc/postgresql/9.3/main/pg_hba.conf

# Set the PGUSER env variable
ENV PGDATA /var/lib/postgresql/9.3/main
ENV PGHOST localhost
ENV PGUSER postgres
ENV PGPORT 5432
ENV PGLOG /var/log/postgresql/postgresql-9.3-main.log
# ENV PGHOME=$PGHOME

# =====================================
#
# PhantomJS
#
# =====================================

RUN cd /tmp && curl -L -O https://bitbucket.org/ariya/phantomjs/downloads/phantomjs-1.9.7-linux-x86_64.tar.bz2 && \
      tar xjf /tmp/phantomjs-1.9.7-linux-x86_64.tar.bz2 -C /tmp && \
      mv /tmp/phantomjs-1.9.7-linux-x86_64/bin/phantomjs /usr/local/bin

# =====================================
#
# Webkit
#
# =====================================

RUN apt-get -y --force-yes -q install libqtwebkit-dev

# =====================================
#
# ImageMagick
#
# =====================================

RUN apt-get -y --force-yes -q install imagemagick libjpeg8-dev libpng12-dev

# =====================================
#
# Redis
#
# =====================================

RUN cd /tmp && curl -L -O http://download.redis.io/redis-stable.tar.gz && \
      tar xvzf /tmp/redis-stable.tar.gz -C /tmp && \
      cd /tmp/redis-stable && make && make install && \
      mkdir /etc/redis && \
      mkdir /var/lib/redis
ADD redis/redis /etc/init.d/redis
ADD redis/redis.conf /etc/redis/redis.conf
RUN chmod 755 /etc/init.d/redis

# =====================================
#
# MySQL
#
# =====================================

RUN apt-get -y --force-yes -q install mysql-server mysql-client libmysqlclient-dev

# =====================================
#
# Java
#
# =====================================

RUN apt-get update -y && apt-get -y --no-install-recommends -q install openjdk-7-jdk

# =====================================
#
# Python + AWS CLI
#
# =====================================

RUN apt-get update -y && apt-get -y --force-yes -q install python-pip && pip install awscli

# =====================================
#
# Scala + SBT
#
# =====================================

RUN cd /tmp && curl -L -O http://www.scala-lang.org/files/archive/scala-2.11.0.deb && dpkg -i scala-2.11.0.deb
RUN cd /tmp && curl -L -O http://dl.bintray.com/sbt/debian/sbt-0.13.2.deb && dpkg -i sbt-0.13.2.deb

# =====================================
#
# Sphinx
#
# =====================================

RUN apt-get -y --force-yes -q install sphinxsearch

# =====================================
#
# Random Packages
#
# =====================================

RUN apt-get -y --force-yes -q install wget ntp

# =====================================
#
# XVFB
#
# =====================================

RUN apt-get -y --force-yes -q install xvfb x11-xkb-utils xfonts-100dpi xfonts-75dpi xfonts-scalable xfonts-cyrillic

# =====================================
#
# ChromeDriver
# https://code.google.com/p/selenium/wiki/ChromeDriver#Requirements
#
# =====================================

RUN apt-get -y --force-yes -q install wget unzip && \
      cd /tmp && curl -L -O http://chromedriver.storage.googleapis.com/2.9/chromedriver_linux64.zip && \
      unzip /tmp/chromedriver_linux64.zip -d /usr/local/bin && \
      chmod a+x /usr/local/bin/chromedriver

# =====================================
#
# Chrome
#
# =====================================

RUN apt-get -y --force-yes -q install wget && \
      wget -q -O - https://dl-ssl.google.com/linux/linux_signing_key.pub | sudo apt-key add - && \
      echo "deb http://dl.google.com/linux/chrome/deb/ stable main" >> /etc/apt/sources.list.d/google-chrome.list && \
      echo "deb http://security.ubuntu.com/ubuntu precise-security main" >> /etc/apt/sources.list && \
      apt-get update && \
      apt-get install -y --force-yes -q google-chrome-stable

# =====================================
#
# Firefox
#
# =====================================

RUN apt-get -y --force-yes -q install firefox

# =====================================
#
# Buildbox Agent
#
# =====================================

# Install the agent
RUN apt-get install -y --force-yes curl && \
      mkdir -p "/home/buildbox/.buildbox" && \
      VERSION="0.2-beta.1" DESTINATION="/home/buildbox/.buildbox" bash -c "`curl -sL https://raw.github.com/buildboxhq/buildbox-agent/master/install.sh`"

# Add our custom boostrap.sh command
ADD bootstrap.sh /home/buildbox/.buildbox/bootstrap.sh

# The rest of the setup
RUN chmod +x /home/buildbox/.buildbox/bootstrap.sh && \
      chown -R buildbox:buildbox /home/buildbox/.buildbox && \
      ln -s /home/buildbox/.buildbox/buildbox-agent /usr/local/bin && \
      ln -s /home/buildbox/.buildbox/buildbox-artifact /usr/local/bin && \
      ln -s /home/buildbox/.buildbox/buildbox-data /usr/local/bin

# =====================================
#
# SSH
#
# =====================================

RUN mkdir -p /home/buildbox/.ssh && \
      chown -R buildbox:buildbox /home/buildbox/.ssh
ADD ssh/known_hosts /etc/ssh/ssh_known_hosts
RUN chmod 644 /etc/ssh/ssh_known_hosts

# =====================================
#
# Defaults
#
# =====================================

# Drop privileges so commands can only be run as buildbox
ENV HOME /home/buildbox
WORKDIR /home/buildbox
USER buildbox
