# Use Strimzi Kafka Connect base image (Java 17 included)
FROM quay.io/strimzi/kafka:0.41.0-kafka-3.7.0

USER root

# Create plugin directory for IBM MQ connectors
RUN mkdir -p /opt/kafka/plugins/ibm-mq

# Copy IBM MQ Source & Sink connector JARs + MQ client
COPY jars/*.jar /opt/kafka/plugins/ibm-mq/

# Fix permissions for OpenShift (non-root user 1001)
RUN chown -R 1001:0 /opt/kafka/plugins && \
    chmod -R g+rwX /opt/kafka/plugins

# Switch back to non-root user
USER 1001
