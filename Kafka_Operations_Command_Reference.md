# SBI ePay 2.0 — Kafka Operations Command Reference
**Environment:** DEV (dev-kafka namespace) | AMQ Streams 3.0.1-2 | Kafka 3.9.0 KRaft  
**Broker Pod:** `dev-kafka-cluster-broker-0`  
**Connect Pod:** `dev-kafka-connect-mq-connect-1`  

---

## 1. INFRASTRUCTURE HEALTH

### 1.1 Pod Status — All Environments
```bash
# DEV
oc get pods -n dev-kafka

# SIT
oc get pods -n sit-kafka

# UAT
oc get pods -n uat-kafka

# INT
oc get pods -n int-kafka
```

### 1.2 Broker Node Placement (verify anti-affinity)
```bash
# DEV — should show broker-0/1/2 on worker1/2/3 respectively
oc get pods -n dev-kafka -o wide | grep broker

# All environments at once
for ns in dev-kafka sit-kafka uat-kafka int-kafka; do
  echo "=== $ns ==="
  oc get pods -n $ns -o wide | grep broker
done
```

### 1.3 Node Memory Usage
```bash
oc adm top node
oc adm top node worker3.dev.sbiepay.sbi
```

### 1.4 Pod Memory/CPU Usage
```bash
oc adm top pod -n dev-kafka
oc adm top pod -n openshift-operators
```

### 1.5 AMQ Streams Operator Health
```bash
oc get pods -n openshift-operators | grep amq-streams
oc describe pod -n openshift-operators \
  $(oc get pods -n openshift-operators | grep amq-streams-cluster | awk '{print $1}') | \
  grep -E "Restart Count|Exit Code|Last State|Limits|Requests"
```

### 1.6 Operator Logs (last 1h)
```bash
oc logs -n openshift-operators \
  $(oc get pods -n openshift-operators | grep amq-streams-cluster | awk '{print $1}') \
  --since=1h | grep -iE "roll|broker|reconcil|restart|error" | tail -30
```

---

## 2. CONNECTOR HEALTH

### 2.1 All NEFT/RTGS Connectors Status
```bash
for c in neft-mq-source neft-mq-sink rtgs-mq-source rtgs-mq-sink; do
  echo "=== $c ==="
  oc exec dev-kafka-connect-mq-connect-1 -n dev-kafka -- \
    curl -s http://localhost:8083/connectors/$c/status | python3 -m json.tool
done
```

### 2.2 All 6 Connectors Status (NEFT + RTGS + MIS)
```bash
for c in neft-mq-source neft-mq-sink rtgs-mq-source rtgs-mq-sink mis-mq-source mis-mq-sink; do
  echo "=== $c ==="
  oc exec dev-kafka-connect-mq-connect-1 -n dev-kafka -- \
    curl -s http://localhost:8083/connectors/$c/status | python3 -m json.tool
done
```

### 2.3 Quick State Check (compact)
```bash
for c in neft-mq-source neft-mq-sink rtgs-mq-source rtgs-mq-sink mis-mq-source mis-mq-sink; do
  echo "=== $c ==="
  oc exec dev-kafka-connect-mq-connect-1 -n dev-kafka -- \
    curl -s http://localhost:8083/connectors/$c/status | python3 -m json.tool | grep "state"
done
```

### 2.4 List All Registered Connectors
```bash
oc exec dev-kafka-connect-mq-connect-1 -n dev-kafka -- \
  curl -s http://localhost:8083/connectors | python3 -m json.tool
```

### 2.5 Specific Connector Config
```bash
oc exec dev-kafka-connect-mq-connect-1 -n dev-kafka -- \
  curl -s http://localhost:8083/connectors/neft-mq-source/config | python3 -m json.tool
```

### 2.6 MQ Connectivity Check
```bash
oc exec dev-kafka-connect-mq-connect-0 -n dev-kafka -- bash -c \
  "timeout 5 bash -c '</dev/tcp/10.176.10.213/2001' && echo OPEN || echo FAIL"
```

---

## 3. EMERGENCY — RESTART CONNECTORS

### 3.1 Restart Individual Connector Task
```bash
# neft-mq-sink (runs on connect-0)
oc exec dev-kafka-connect-mq-connect-0 -n dev-kafka -- \
  curl -s -X POST http://localhost:8083/connectors/neft-mq-sink/tasks/0/restart

# neft-mq-source (runs on connect-1)
oc exec dev-kafka-connect-mq-connect-1 -n dev-kafka -- \
  curl -s -X POST http://localhost:8083/connectors/neft-mq-source/tasks/0/restart

# rtgs-mq-source (runs on connect-0)
oc exec dev-kafka-connect-mq-connect-0 -n dev-kafka -- \
  curl -s -X POST http://localhost:8083/connectors/rtgs-mq-source/tasks/0/restart

# rtgs-mq-sink (runs on connect-2)
oc exec dev-kafka-connect-mq-connect-2 -n dev-kafka -- \
  curl -s -X POST http://localhost:8083/connectors/rtgs-mq-sink/tasks/0/restart

# mis-mq-source (runs on connect-1)
oc exec dev-kafka-connect-mq-connect-1 -n dev-kafka -- \
  curl -s -X POST http://localhost:8083/connectors/mis-mq-source/tasks/0/restart

# mis-mq-sink (runs on connect-0)
oc exec dev-kafka-connect-mq-connect-0 -n dev-kafka -- \
  curl -s -X POST http://localhost:8083/connectors/mis-mq-sink/tasks/0/restart
```

### 3.2 Restart Connect Pod (last resort)
```bash
oc delete pod dev-kafka-connect-mq-connect-0 -n dev-kafka
oc delete pod dev-kafka-connect-mq-connect-1 -n dev-kafka
oc delete pod dev-kafka-connect-mq-connect-2 -n dev-kafka
```

### 3.3 Restart Kafka Console UI Pod
```bash
oc delete pod dev-console-console-deployment-577c797ccf-8dz7g -n dev-kafka
```

---

## 4. TOPIC LEVEL

### 4.1 List All Topics
```bash
oc exec dev-kafka-cluster-broker-0 -n dev-kafka -- \
  bin/kafka-topics.sh \
  --bootstrap-server localhost:9092 \
  --list
```

### 4.2 List NEFT/RTGS/MIS Topics Only
```bash
oc exec dev-kafka-cluster-broker-0 -n dev-kafka -- \
  bin/kafka-topics.sh \
  --bootstrap-server localhost:9092 \
  --list | grep -iE "neft|rtgs|mis"
```

### 4.3 Topic Details (partitions, replication, ISR)
```bash
oc exec dev-kafka-cluster-broker-0 -n dev-kafka -- \
  bin/kafka-topics.sh \
  --bootstrap-server localhost:9092 \
  --describe --topic neft.inbound.kafka.topic
```

### 4.4 Consumer Group Lag
```bash
# All groups
oc exec dev-kafka-cluster-broker-0 -n dev-kafka -- \
  bin/kafka-consumer-groups.sh \
  --bootstrap-server localhost:9092 \
  --describe --all-groups 2>/dev/null | grep neft

# Specific group
oc exec dev-kafka-cluster-broker-0 -n dev-kafka -- \
  bin/kafka-consumer-groups.sh \
  --bootstrap-server localhost:9092 \
  --describe --group payment-consumers 2>/dev/null
```

---

## 5. MESSAGE LEVEL

### 5.1 NEFT Inbound — All Messages
```bash
oc exec dev-kafka-cluster-broker-0 -n dev-kafka -- \
  bin/kafka-console-consumer.sh \
  --bootstrap-server localhost:9092 \
  --topic neft.inbound.kafka.topic \
  --from-beginning \
  --max-messages 100
```

### 5.2 NEFT Inbound — With Timestamps
```bash
oc exec dev-kafka-cluster-broker-0 -n dev-kafka -- \
  bin/kafka-console-consumer.sh \
  --bootstrap-server localhost:9092 \
  --topic neft.inbound.kafka.topic \
  --from-beginning \
  --property print.timestamp=true \
  --max-messages 100
```

### 5.3 NEFT Inbound — Latest Messages (real-time watch)
```bash
oc exec dev-kafka-cluster-broker-0 -n dev-kafka -- \
  bin/kafka-console-consumer.sh \
  --bootstrap-server localhost:9092 \
  --topic neft.inbound.kafka.topic \
  --offset latest \
  --partition 0
```

### 5.4 NEFT Outbound — All Responses
```bash
oc exec dev-kafka-cluster-broker-0 -n dev-kafka -- \
  bin/kafka-console-consumer.sh \
  --bootstrap-server localhost:9092 \
  --topic neft.outbound.kafka.topic \
  --from-beginning \
  --property print.timestamp=true \
  --max-messages 100
```

### 5.5 NEFT Outbound — Latest (real-time watch)
```bash
oc exec dev-kafka-cluster-broker-0 -n dev-kafka -- \
  bin/kafka-console-consumer.sh \
  --bootstrap-server localhost:9092 \
  --topic neft.outbound.kafka.topic \
  --offset latest \
  --partition 0
```

### 5.6 RTGS Inbound — All Messages with Timestamps
```bash
oc exec dev-kafka-cluster-broker-0 -n dev-kafka -- \
  bin/kafka-console-consumer.sh \
  --bootstrap-server localhost:9092 \
  --topic rtgs.inbound.kafka.topic \
  --from-beginning \
  --property print.timestamp=true \
  --max-messages 100
```

### 5.7 MIS Inbound — All Messages
```bash
oc exec dev-kafka-cluster-broker-0 -n dev-kafka -- \
  bin/kafka-console-consumer.sh \
  --bootstrap-server localhost:9092 \
  --topic neft.mis.inbound.kafka.topic \
  --from-beginning \
  --max-messages 20
```

### 5.8 MIS Outbound — All Responses
```bash
oc exec dev-kafka-cluster-broker-0 -n dev-kafka -- \
  bin/kafka-console-consumer.sh \
  --bootstrap-server localhost:9092 \
  --topic neft.mis.outbound.kafka.topic \
  --from-beginning \
  --max-messages 20
```

### 5.9 MIS Inbound — Latest (real-time watch)
```bash
oc exec dev-kafka-cluster-broker-0 -n dev-kafka -- \
  bin/kafka-console-consumer.sh \
  --bootstrap-server localhost:9092 \
  --topic neft.mis.inbound.kafka.topic \
  --offset latest \
  --partition 0
```

### 5.10 Search for Specific Transaction ID
```bash
# Replace HDFCH01076994361 with your transaction ID
oc exec dev-kafka-cluster-broker-0 -n dev-kafka -- \
  bin/kafka-console-consumer.sh \
  --bootstrap-server localhost:9092 \
  --topic neft.inbound.kafka.topic \
  --from-beginning \
  --max-messages 100 | grep -a "HDFCH01076994361"
```

### 5.11 Produce Test Message to Outbound Topic
```bash
oc exec dev-kafka-cluster-broker-0 -n dev-kafka -- \
  bin/kafka-console-producer.sh \
  --bootstrap-server localhost:9092 \
  --topic neft.mis.outbound.kafka.topic
# Then type message and press Enter. Ctrl+C to exit.
```

---

## 6. LOGS

### 6.1 Connect Pod Logs — Errors Only
```bash
oc logs dev-kafka-connect-mq-connect-0 -n dev-kafka --tail=50 | grep -iE "error|fail|exception"
oc logs dev-kafka-connect-mq-connect-1 -n dev-kafka --tail=50 | grep -iE "error|fail|exception"
oc logs dev-kafka-connect-mq-connect-2 -n dev-kafka --tail=50 | grep -iE "error|fail|exception"
```

### 6.2 MIS Connector Logs
```bash
# mis-mq-source logs
oc logs dev-kafka-connect-mq-connect-1 -n dev-kafka --tail=50 | \
  grep -iE "mis|NeftMISC|error|fail"

# mis-mq-sink logs
oc logs dev-kafka-connect-mq-connect-2 -n dev-kafka --tail=50 | \
  grep -iE "mis|NeftMISC|error|fail"
```

### 6.3 NEFT Connector Logs
```bash
oc logs dev-kafka-connect-mq-connect-0 -n dev-kafka --tail=50 | \
  grep -iE "neft|NeftInbound|NeftOutBound|error|fail"
```

### 6.4 Cruise Control Logs
```bash
oc logs dev-kafka-cluster-cruise-control-d949867dd-qmxmn -n dev-kafka --tail=50 | \
  grep -iE "error|fail|goal|balance"
```

### 6.5 Broker Logs
```bash
oc logs dev-kafka-cluster-broker-0 -n dev-kafka --tail=50 | \
  grep -iE "error|leader|partition"
```

### 6.6 Previous Pod Logs (after restart)
```bash
oc logs dev-kafka-connect-mq-connect-0 -n dev-kafka --previous | tail -50
```

---

## 7. QUICK REFERENCE — TOPIC & QUEUE MAPPING

| Direction | Queue (IBM MQ) | Kafka Topic |
|---|---|---|
| IPH → Us (NEFT in) | NeftInboundQueue | neft.inbound.kafka.topic |
| Us → IPH (NEFT out) | NeftOutBoundQueue | neft.outbound.kafka.topic |
| IPH → Us (RTGS in) | RTGSInboundQueue | rtgs.inbound.kafka.topic |
| Us → IPH (RTGS out) | RTGSOutBoundQueue | rtgs.outbound.kafka.topic |
| IPH → Us (MIS in) | NeftMISCInboundQueue | neft.mis.inbound.kafka.topic |
| Us → IPH (MIS out) | NeftMISCOutBoundQueue | neft.mis.outbound.kafka.topic |

**MQ Connectivity Details (DEV):**
- NEFT: QM=`SBI_NEFT`, Host=`10.176.10.213:2001`, Channel=`SBIEPAY2.SVRCONN`
- RTGS: QM=`SBI_RTGS`, Host=`10.176.10.213:2005`, Channel=`SBIEPAY2.SVRCONN`
- MIS: QM=`SBI_NEFT`, Host=`10.176.10.213:2001`, Channel=`SBIEPAY2.SVRCONN`

---

## 8. OPERATOR LEVEL

### 8.1 Patch AMQ Operator Memory (CSV — not Deployment)
```bash
oc patch csv amqstreams.v3.0.1-2 -n openshift-operators --type=json -p='[
  {"op": "replace", "path": "/spec/install/spec/deployments/0/spec/template/spec/containers/0/resources/limits/memory", "value": "1Gi"},
  {"op": "replace", "path": "/spec/install/spec/deployments/0/spec/template/spec/containers/0/resources/requests/memory", "value": "512Mi"},
  {"op": "replace", "path": "/spec/install/spec/deployments/0/spec/template/spec/containers/0/resources/limits/cpu", "value": "2"},
  {"op": "replace", "path": "/spec/install/spec/deployments/0/spec/template/spec/containers/0/resources/requests/cpu", "value": "500m"}
]'
```

### 8.2 Delete Stuck MirrorMaker2 CRs
```bash
oc delete kafkamirrormaker2 sit-kafka-mirror-maker -n sit-kafka
oc delete kafkamirrormaker2 uat-kafka-mirror-maker -n uat-kafka
oc delete kafkamirrormaker2 int-kafka-mirror-maker -n int-kafka
```

### 8.3 Check Kafka CR Generation
```bash
oc get kafka dev-kafka-cluster -n dev-kafka -o yaml | \
  grep -E "generation|resourceVersion|lastTransitionTime"
```

### 8.4 Check KafkaNodePool Anti-Affinity
```bash
oc get kafkanodepool broker -n dev-kafka -o yaml | grep -A20 "affinity"
```

### 8.5 Verify Broker Labels
```bash
oc get pods -n dev-kafka -l strimzi.io/pool-name=broker
```

### 8.6 Helm History
```bash
helm history epay-common -n dev-epay-common | tail -5
helm history epay-common -n sit-epay-common | tail -5
```

### 8.7 Helm Deployed Values
```bash
helm get values epay-common -n dev-epay-common | grep -A15 "affinity"
helm get values epay-common -n dev-epay-common | grep -A20 "kafkaConnect"
```
