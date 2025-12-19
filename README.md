# IBM-MQ---kafka-connection

mq-kafka-connect/
├── Dockerfile
└── jars/
    ├── kafka-connect-mq-source-2.6.0-jar-with-dependencies.jar
    ├── kafka-connect-mq-sink-2.6.0-jar-with-dependencies.jar
    └── com.ibm.mq.allclient-9.3.4.x.jar



Need in the Kafka Connect Image
For IBM MQ → Kafka (Source Connector)
kafka-connect-mq-source-2.6.0-jar-with-dependencies.jar
com.ibm.mq.allclient-9.3.4.x.jar


For Kafka → IBM MQ (Sink Connector)
kafka-connect-mq-sink-2.6.0-jar-with-dependencies.jar


Final JAR Set to Keep in Image (Source + Sink ready)
kafka-connect-mq-source-2.6.0-jar-with-dependencies.jar
kafka-connect-mq-sink-2.6.0-jar-with-dependencies.jar
com.ibm.mq.allclient-9.3.4.x.jar


DK Version – What Is Correct for Production?
✅ Recommended & Safe Choice

JDK 17

Why JDK 17 is the correct choice:

| Reason                | Explanation                        |
| --------------------- | ---------------------------------- |
| Strimzi / AMQ Streams | Officially tested with **Java 17** |
| Kafka 3.6 / 3.7       | Built & tested with Java 17        |
| IBM MQ Client         | Fully compatible with Java 11 & 17 |
| OpenShift             | Java 17 is enterprise-safe         |
| Long-term support     | Java 17 LTS                        |


---------------------------------------------------------------------------------------------------------------------------------------------------------------------------
IBM MQ ↔ Kafka Integration on OpenShift (Bidirectional)
Overview

This document explains how to implement bidirectional integration between IBM MQ and Apache Kafka running on OpenShift using Strimzi Kafka Connect.

The flow supports:

IBM MQ → Kafka (ingestion)

Kafka → IBM MQ (post-processing delivery)

The design reuses the same Kafka Connect runtime already validated for Oracle connectors, following Strimzi best practices.

High-Level Architecture
IBM MQ (IN Queue)
        |
        |  [IBM MQ Source Connector]
        v
Kafka Topic (raw messages)
        |
        |  (Application / Stream Processing)
        v
Kafka Topic (processed messages)
        |
        |  [IBM MQ Sink Connector]
        v
IBM MQ (OUT Queue)


Key points:

Kafka runs on OpenShift in KRaft mode

Kafka Connect runs inside OpenShift

IBM MQ is external

Only DC Kafka runs connectors

DR Kafka receives data via MirrorMaker2

Components Used
Component	Purpose
KafkaConnect CR	Kafka Connect runtime (engine)
KafkaConnector (MQ Source)	IBM MQ → Kafka
KafkaConnector (MQ Sink)	Kafka → IBM MQ
Custom Connect Image	Contains IBM MQ Source & Sink JARs
MQ Credentials Secret	Secure MQ authentication
Design Rules (Important)

One KafkaConnect CR per Connect cluster

One KafkaConnector CR per connector

Source and Sink cannot be combined in a single CR

Use different queues and topics to avoid infinite loops

Example:

MQ.IN.QUEUE        → kafka.raw.topic
kafka.processed.topic → MQ.OUT.QUEUE

1. KafkaConnect CR (Runtime)
Purpose

The KafkaConnect CR defines the Kafka Connect runtime:

Pods and replicas

Kafka authentication and TLS

Internal offset/config/status topics

Custom image with IBM MQ support

This CR is reused from the Oracle DB setup with minimal MQ-specific changes.

KafkaConnect CR Example
apiVersion: kafka.strimzi.io/v1beta2
kind: KafkaConnect
metadata:
  name: kafka-connect
  namespace: <kafka-namespace>
spec:
  replicas: 3

  image: <registry>/kafka-connect-mq:v2

  bootstrapServers: <kafka-bootstrap-service>:9093

  config:
    group.id: kafka-connect-cluster
    offset.storage.topic: kafka-connect-offsets
    config.storage.topic: kafka-connect-configs
    status.storage.topic: kafka-connect-status

    key.converter: org.apache.kafka.connect.storage.StringConverter
    value.converter: org.apache.kafka.connect.converters.ByteArrayConverter
    value.converter.schemas.enable: "false"

    offset.storage.replication.factor: 3
    config.storage.replication.factor: 3
    status.storage.replication.factor: 3

  authentication:
    type: scram-sha-512
    username: kafka-connect-user
    passwordSecret:
      secretName: kafka-connect-user
      password: password

  tls:
    trustedCertificates:
      - secretName: <kafka-cluster>-cluster-ca-cert
        certificate: ca.crt

  externalConfiguration:
    volumes:
      - name: mq-credentials
        secret:
          secretName: mq-credentials

  template:
    pod:
      volumeMounts:
        - name: mq-credentials
          mountPath: /opt/kafka/external-configuration/mq-credentials
          readOnly: true

What This Achieves

Kafka Connect pods start with JDK 21

IBM MQ Source & Sink plugins are loaded

Secure Kafka and MQ authentication

Ready to host multiple connectors

2. KafkaConnector CR – IBM MQ Source (MQ → Kafka)
Purpose

This connector:

Reads messages from an IBM MQ input queue

Publishes them to a Kafka raw topic

KafkaConnector – MQ Source
apiVersion: kafka.strimzi.io/v1beta2
kind: KafkaConnector
metadata:
  name: ibm-mq-source
  namespace: <kafka-namespace>
  labels:
    strimzi.io/cluster: kafka-connect
spec:
  class: com.ibm.eventstreams.connect.mqsource.MQSourceConnector
  tasksMax: 1
  config:
    mq.queue.manager: QM1
    mq.connection.name.list: "<MQ_HOST>(1414)"
    mq.channel.name: DEV.APP.SVRCONN
    mq.queue: MQ.IN.QUEUE

    mq.user.name: ${file:/opt/kafka/external-configuration/mq-credentials/mq.username}
    mq.password: ${file:/opt/kafka/external-configuration/mq-credentials/mq.password}

    topic: kafka.raw.topic

    mq.message.body.format: string
    mq.record.builder: com.ibm.eventstreams.connect.mqsource.builders.DefaultRecordBuilder

    value.converter: org.apache.kafka.connect.converters.ByteArrayConverter
    value.converter.schemas.enable: "false"

    mq.poll.interval: "1000"
    mq.batch.size: "10"

Result

Messages are consumed from IBM MQ

Written to Kafka raw topic

Offsets stored safely in Kafka

Topic is replicated to DR via MM2

3. KafkaConnector CR – IBM MQ Sink (Kafka → MQ)
Purpose

This connector:

Consumes processed Kafka messages

Writes them back to an IBM MQ output queue

KafkaConnector – MQ Sink
apiVersion: kafka.strimzi.io/v1beta2
kind: KafkaConnector
metadata:
  name: ibm-mq-sink
  namespace: <kafka-namespace>
  labels:
    strimzi.io/cluster: kafka-connect
spec:
  class: com.ibm.eventstreams.connect.mqsink.MQSinkConnector
  tasksMax: 1
  config:
    topics: kafka.processed.topic

    mq.queue.manager: QM1
    mq.connection.name.list: "<MQ_HOST>(1414)"
    mq.channel.name: DEV.APP.SVRCONN
    mq.queue: MQ.OUT.QUEUE

    mq.user.name: ${file:/opt/kafka/external-configuration/mq-credentials/mq.username}
    mq.password: ${file:/opt/kafka/external-configuration/mq-credentials/mq.password}

    mq.message.body.format: string

    value.converter: org.apache.kafka.connect.converters.ByteArrayConverter
    value.converter.schemas.enable: "false"

Result

Processed Kafka messages are delivered to IBM MQ

Kafka acts as buffer and replay layer

MQ outages do not lose data

Operational Benefits

Independent control of source and sink

Easy pause/resume of either direction

Kafka provides durability and replay

Clean DR handling via MirrorMaker2

Clear support boundary (IBM MQ vs Kafka)

Summary

IBM MQ → Kafka → IBM MQ is implemented using:

1 KafkaConnect CR

2 KafkaConnector CRs (Source + Sink)

Design reuses proven Oracle Kafka Connect pattern

Secure, scalable, and DR-ready

Fully aligned with Strimzi best practices

End of Document


