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



