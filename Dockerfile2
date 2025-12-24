FROM quay.io/strimzi/kafka:0.46.1-kafka-3.9.0

USER root

# Create plugin directory
RUN mkdir -p /opt/kafka/plugins/ibm-mq

# Copy MQ connector jars
COPY kafka-connect-mq-source-*.jar /opt/kafka/plugins/ibm-mq/
COPY kafka-connect-mq-sink-*.jar /opt/kafka/plugins/ibm-mq/
COPY com.ibm.mq.allclient-*.jar /opt/kafka/plugins/ibm-mq/

RUN chown -R 1001:0 /opt/kafka/plugins && chmod -R g+rwX /opt/kafka/plugins

USER 1001
