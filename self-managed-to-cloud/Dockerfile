FROM confluentinc/cp-server-connect-base:7.9.2
USER root

RUN yum --nodocs -q update -y --disablerepo=temurin-jdk && yum --nodocs --disablerepo=temurin-jdk -q install -y wget unzip libaio libnsl2 

RUN ln -s /lib64/libnsl.so.2 /lib64/libnsl.so.1

RUN   confluent-hub install --no-prompt confluentinc/kafka-connect-oracle-xstream-cdc-source:latest

COPY  instantclient-basic-linux.x64-19.26.0.0.0dbru.zip  /tmp/instantclient-basic-linux.x64-19.26.0.0.0dbru.zip

RUN   cd /tmp && unzip  /tmp/instantclient-basic-linux.x64-19.26.0.0.0dbru.zip 

RUN   mv /tmp/instantclient_19_26 /usr/share/confluent-hub-components/confluentinc-kafka-connect-oracle-xstream-cdc-source/lib/

RUN   cd /usr/share/confluent-hub-components/confluentinc-kafka-connect-oracle-xstream-cdc-source/lib/instantclient_19_26 \
  && cp  ojdbc8.jar xstreams.jar /usr/share/confluent-hub-components/confluentinc-kafka-connect-oracle-xstream-cdc-source/lib

ENV   LD_LIBRARY_PATH="/usr/share/confluent-hub-components/confluentinc-kafka-connect-oracle-xstream-cdc-source/lib/instantclient_19_26"

USER root





