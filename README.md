# hackathon-ksql
Hackathon for KSQL and Confluent Cloud. The idea is to play around with KSQL.

## Agenda afternoon (3 hours):
  * Welcome and short introduction into KSQL
  * Introduction into the Hands-on environment
  * Hands-On - let's do coding
  
[Go to proceedings / Playbook](https://github.com/ora0600/hackathon-ksql/blob/master/README.md#atm-fraud-detection-afternoon)

### Pre-reqs:

  * A Confluent docker setup for Fraud detection is prepared and can be deployed to AWS via terraform for each attendee
  * Attendee need only SSH tools and must be able to access Port 22 into the internet(Firewall)
  * All GUIs are tunneled via SSH, e.g. for Control Center
```
ssh -i ~/keys/your-key.pem -N -L 9022:ip-<IP private>.eu-central-1.compute.internal:9021 ec2-user@<PUBIP)
```
  * All attendees will get the private SSH key as well Public IP to connect the environment

## Agenda Evening
  * Welcome and short intro into the evening
  * short presentation around KSQL
  * short introduction into the demo setup: Confluent Platform connected to Confluent Cloud Clusters
  * Tasks, Guidelines
  * Coding
  * Prices, party
  
[Go to proceedings / Playbook](https://github.com/ora0600/hackathon-ksql/blob/master/README.md#confluent-cloud-and-ksql-rest-proxy-control-center-evening)


### Pre-reqs:
  * Attendees will get access to Confluent Cloud (API Keys), Schema Registry (API Keys) and maybe AWS evironment
  * Some scripts are prepared to make the coding easier
  * Attendee need only SSH tools and must be able to access Port 22 into the internet(Firewall)
  * All attendees will get the private SSH key as well Public IP to connect the aws environment if necessary

# Proceeding and Coding
For both time slots a kind of preparation and Hands-on is prepared. But the attendees can do what ever useful.

## ATM Fraud detection (afternoon)
This nice solution von developed from Robin Moffat. You can follow the Blog Entry, and Sources Description from Robin or take the play book
 * [Blog](https://www.confluent.io/blog/atm-fraud-detection-apache-kafka-ksql)
 * [Sources](https://github.com/confluentinc/demo-scene/tree/master/ksql-atm-fraud-detection)

I did collect the most important statement in the following Play BooK:
Login Information will be send to attendees
login into Compute instance
```
ssh -i ~/keys/hackathon-temp-key.pem ec2-user@<PUB IP>
```
FYI: tunnel control center
```
ssh -i ~/keys/hackathon-temp-key.pem -N -L 9022:ip-<private IP>.eu-central-1.compute.internal ec2-user@<PUBIP>
```
First check versions
```
java -version
docker-compose --version
docker version
```
Switch to the working directory
```
cd /home/ec2-user/software/hackathon-ksql-master
```
Bring up the complete stack
```
docker-compose up -d
docker-compose ps
```
Launch the ksql cli
```
docker-compose exec ksql-cli bash -c 'echo -e "\n\n⏳ Waiting for KSQL to be available before launching CLI\n"; while [ $(curl -s -o /dev/null -w %{http_code} http://ksql-server:8088/) -eq 000 ] ; do echo -e $(date) "KSQL Server HTTP state: " $(curl -s -o /dev/null -w %{http_code} http://ksql-server:8088/) " (waiting for 200)" ; sleep 5 ; done; ksql http://ksql-server:8088'
```
in ksql exeute the following commands
```
list topics;
PRINT 'atm_txns_gess' FROM BEGINNING;
```
Register the topic as a KSQL stream:
```
CREATE STREAM ATM_TXNS_GESS (account_id VARCHAR,
                            atm VARCHAR,
                            location STRUCT<lon DOUBLE,
                                            lat DOUBLE>,
                            amount INT,
                            timestamp VARCHAR,
                            transaction_id VARCHAR)
            WITH (KAFKA_TOPIC='atm_txns_gess',
            VALUE_FORMAT='JSON',
            TIMESTAMP='timestamp',
            TIMESTAMP_FORMAT='yyyy-MM-dd HH:mm:ss X');
```
Query the created stream
```
SELECT TIMESTAMPTOSTRING(ROWTIME, 'HH:mm:ss'), ACCOUNT_ID, ATM, AMOUNT
        FROM ATM_TXNS_GESS
        LIMIT 5;
```
create a clone of that stream
```
CREATE STREAM ATM_TXNS_GESS_02 WITH (PARTITIONS=1) AS
        SELECT * FROM ATM_TXNS_GESS;                    
```
Join the stream (two in practice, but logically still just a single Kafka topic). Also calculate time between two events (useful for spotting past-joins, not future).
```
SELECT S1.ACCOUNT_ID,
        TIMESTAMPTOSTRING(S1.ROWTIME, 'HH:mm:ss') AS S1_TS,
        TIMESTAMPTOSTRING(S2.ROWTIME, 'HH:mm:ss') AS S2_TS,
        (S2.ROWTIME - S1.ROWTIME)/1000 AS TIME_DIFF_SEC,
        S1.TRANSACTION_ID ,S2.TRANSACTION_ID
FROM   ATM_TXNS_GESS S1
       INNER JOIN ATM_TXNS_GESS_02 S2
        WITHIN 10 MINUTES
        ON S1.ACCOUNT_ID = S2.ACCOUNT_ID
LIMIT 40;
```
Filter out : direct matches to self, those in the same location, Joins to past-dated events.
```
SELECT S1.ACCOUNT_ID,
        TIMESTAMPTOSTRING(S1.ROWTIME, 'HH:mm:ss') AS S1_TS,
        TIMESTAMPTOSTRING(S2.ROWTIME, 'HH:mm:ss') AS S2_TS,
        (S2.ROWTIME - S1.ROWTIME)/1000 AS TIME_DIFF_SEC,
        S1.ATM, S2.ATM,
        S1.TRANSACTION_ID ,S2.TRANSACTION_ID
FROM   ATM_TXNS_GESS S1
       INNER JOIN ATM_TXNS_GESS_02 S2
        WITHIN (0 MINUTES, 10 MINUTES)
        ON S1.ACCOUNT_ID = S2.ACCOUNT_ID
WHERE   S1.TRANSACTION_ID != S2.TRANSACTION_ID
  AND   (S1.location->lat != S2.location->lat OR
         S1.location->lon != S2.location->lon)
  AND   S2.ROWTIME != S1.ROWTIME
LIMIT 20;
```
Derive distance between ATMs & calculate required speed:
```
SELECT S1.ACCOUNT_ID,
        TIMESTAMPTOSTRING(S1.ROWTIME, 'HH:mm:ss') AS S1_TS,
        TIMESTAMPTOSTRING(S2.ROWTIME, 'HH:mm:ss') AS S2_TS,
        (CAST(S2.ROWTIME AS DOUBLE) - CAST(S1.ROWTIME AS DOUBLE)) / 1000 / 60 AS MINUTES_DIFFERENCE,
        CAST(GEO_DISTANCE(S1.location->lat, S1.location->lon, S2.location->lat, S2.location->lon, 'KM') AS INT) AS DISTANCE_BETWEEN_TXN_KM,
        GEO_DISTANCE(S1.location->lat, S1.location->lon, S2.location->lat, S2.location->lon, 'KM') / ((CAST(S2.ROWTIME AS DOUBLE) - CAST(S1.ROWTIME AS DOUBLE)) / 1000 / 60 / 60) AS KMH_REQUIRED,
        S1.ATM, S2.ATM
FROM   ATM_TXNS_GESS S1
       INNER JOIN ATM_TXNS_GESS_02 S2
        WITHIN (0 MINUTES, 10 MINUTES)
        ON S1.ACCOUNT_ID = S2.ACCOUNT_ID
WHERE   S1.TRANSACTION_ID != S2.TRANSACTION_ID
  AND   (S1.location->lat != S2.location->lat OR
         S1.location->lon != S2.location->lon)
  AND   S2.ROWTIME != S1.ROWTIME
LIMIT 20;
```
Persist as a new stream:
```
CREATE STREAM ATM_POSSIBLE_FRAUD
    WITH (PARTITIONS=1) AS
SELECT S1.ROWTIME AS TX1_TIMESTAMP, S2.ROWTIME AS TX2_TIMESTAMP,
        GEO_DISTANCE(S1.location->lat, S1.location->lon, S2.location->lat, S2.location->lon, 'KM') AS DISTANCE_BETWEEN_TXN_KM,
        (S2.ROWTIME - S1.ROWTIME) AS MILLISECONDS_DIFFERENCE,
        (CAST(S2.ROWTIME AS DOUBLE) - CAST(S1.ROWTIME AS DOUBLE)) / 1000 / 60 AS MINUTES_DIFFERENCE,
        GEO_DISTANCE(S1.location->lat, S1.location->lon, S2.location->lat, S2.location->lon, 'KM') / ((CAST(S2.ROWTIME AS DOUBLE) - CAST(S1.ROWTIME AS DOUBLE)) / 1000 / 60 / 60) AS KMH_REQUIRED,
        S1.ACCOUNT_ID AS ACCOUNT_ID,
        S1.TRANSACTION_ID AS TX1_TRANSACTION_ID, S2.TRANSACTION_ID AS TX2_TRANSACTION_ID,
        S1.AMOUNT AS TX1_AMOUNT, S2.AMOUNT AS TX2_AMOUNT,
        S1.ATM AS TX1_ATM, S2.ATM AS TX2_ATM,
        CAST(S1.location->lat AS STRING) + ',' + CAST(S1.location->lon AS STRING) AS TX1_LOCATION,
        CAST(S2.location->lat AS STRING) + ',' + CAST(S2.location->lon AS STRING) AS TX2_LOCATION
FROM   ATM_TXNS_GESS S1
       INNER JOIN ATM_TXNS_GESS_02 S2
        WITHIN (0 MINUTES, 10 MINUTES)
        ON S1.ACCOUNT_ID = S2.ACCOUNT_ID
WHERE   S1.TRANSACTION_ID != S2.TRANSACTION_ID
  AND   (S1.location->lat != S2.location->lat OR
         S1.location->lon != S2.location->lon)
  AND   S2.ROWTIME != S1.ROWTIME;
```
View the resulting transactions:  
```
SELECT ACCOUNT_ID,
        TIMESTAMPTOSTRING(TX1_TIMESTAMP, 'yyyy-MM-dd HH:mm:ss') AS TX1_TS,
        TIMESTAMPTOSTRING(TX2_TIMESTAMP, 'HH:mm:ss') AS TX2_TS,
        TX1_ATM, TX2_ATM,
        DISTANCE_BETWEEN_TXN_KM, MINUTES_DIFFERENCE
FROM ATM_POSSIBLE_FRAUD;
```
examine Customer data:
```
SET 'auto.offset.reset' = 'earliest';
CREATE STREAM ACCOUNTS_STREAM WITH (KAFKA_TOPIC='asgard.demo.accounts', VALUE_FORMAT='AVRO');
CREATE STREAM ACCOUNTS_REKEYED WITH (PARTITIONS=1) AS SELECT * FROM ACCOUNTS_STREAM PARTITION BY ACCOUNT_ID;
```
This select statement is simply to make sure that we have time for the ACCOUNTS_REKEYED topic
to be created before we define a table against it
```
SELECT * FROM ACCOUNTS_REKEYED LIMIT 1;
CREATE TABLE ACCOUNTS WITH (KAFKA_TOPIC='ACCOUNTS_REKEYED',VALUE_FORMAT='AVRO',KEY='ACCOUNT_ID');
SELECT ACCOUNT_ID, FIRST_NAME, LAST_NAME, EMAIL, PHONE FROM ACCOUNTS WHERE ACCOUNT_ID='a42';
```
Open another terminal and Launch mysql cli
```
ssh -i ~/keys/hackathon-temp-key.pem ec2-user@<PUBIP>
cd /home/ec2-user/software/hackathon-ksql-master
docker-compose exec mysql bash -c 'mysql -u $MYSQL_USER -p$MYSQL_PASSWORD demo'
```
in cli show tables
```
SHOW TABLES;
SELECT ACCOUNT_ID, FIRST_NAME, LAST_NAME, EMAIL, PHONE FROM accounts LIMIT 5;
```
update the data, you should the changes in ksql open select stream
```
UPDATE accounts SET EMAIL='none' WHERE ACCOUNT_ID='a42';
UPDATE accounts SET EMAIL='robin@rmoff.net' WHERE ACCOUNT_ID='a42';
UPDATE accounts SET EMAIL='robin@confluent.io' WHERE ACCOUNT_ID='a42';
```
go back to ksql terminal
explore stream/table difference:
```
SELECT ACCOUNT_ID, FIRST_NAME, LAST_NAME, EMAIL, PHONE FROM ACCOUNTS_STREAM WHERE ACCOUNT_ID='a42';
```
Write enriched data to new stream:
```
CREATE STREAM ATM_POSSIBLE_FRAUD_ENRICHED WITH (PARTITIONS=1) AS
SELECT A.ACCOUNT_ID AS ACCOUNT_ID,
      A.TX1_TIMESTAMP, A.TX2_TIMESTAMP,
      A.TX1_AMOUNT, A.TX2_AMOUNT,
      A.TX1_ATM, A.TX2_ATM,
      A.TX1_LOCATION, A.TX2_LOCATION,
      A.TX1_TRANSACTION_ID, A.TX2_TRANSACTION_ID,
      A.DISTANCE_BETWEEN_TXN_KM,
      A.MILLISECONDS_DIFFERENCE,
      A.MINUTES_DIFFERENCE,
      A.KMH_REQUIRED,
      B.FIRST_NAME + ' ' + B.LAST_NAME AS CUSTOMER_NAME,
      B.EMAIL AS CUSTOMER_EMAIL,
      B.PHONE AS CUSTOMER_PHONE,
      B.ADDRESS AS CUSTOMER_ADDRESS,
      B.COUNTRY AS CUSTOMER_COUNTRY
FROM ATM_POSSIBLE_FRAUD A
     INNER JOIN ACCOUNTS B
     ON A.ACCOUNT_ID = B.ACCOUNT_ID;
```
View enriched data:
```
SELECT ACCOUNT_ID, CUSTOMER_NAME, CUSTOMER_PHONE,
        TIMESTAMPTOSTRING(TX1_TIMESTAMP, 'yyyy-MM-dd HH:mm:ss') AS TX1_TS,
        TIMESTAMPTOSTRING(TX2_TIMESTAMP, 'HH:mm:ss') AS TX2_TS,
        TX1_ATM, TX2_ATM,
        DISTANCE_BETWEEN_TXN_KM, MINUTES_DIFFERENCE
FROM ATM_POSSIBLE_FRAUD_ENRICHED;
```
customer data enrichment → Neo4j
do the join
```
CREATE STREAM ATM_TXNS_GESS_ENRICHED WITH (PARTITIONS=1) AS
SELECT A.ACCOUNT_ID AS ACCOUNT_ID,
        A.TIMESTAMP AS TIMESTAMP,
        A.AMOUNT AS AMOUNT,
        A.ATM AS ATM,
        A.LOCATION AS LOCATION,
        A.TRANSACTION_ID AS TRANSACTION_ID,
        B.FIRST_NAME + ' ' + B.LAST_NAME AS CUSTOMER_NAME,
        B.EMAIL AS CUSTOMER_EMAIL,
        B.PHONE AS CUSTOMER_PHONE,
        B.ADDRESS AS CUSTOMER_ADDRESS,
        B.COUNTRY AS CUSTOMER_COUNTRY
FROM ATM_TXNS_GESS A
     INNER JOIN ACCOUNTS B
     ON A.ACCOUNT_ID = B.ACCOUNT_ID;
```
tunnel control center
open Control Center in your brower http://localhost:9022
```
ssh -i ~/keys/hackathon-temp-key.pem -N -L 9022:ip-<priv IP>.eu-central-1.compute.internal:9021 ec2-user@<pub IP>>
```
Doc checks in Control Center 
 * check topics
 * check Streams, Tables, persistant queries
 * check connect clusters, sink and sources
tunnel to [kibana](http://localhost:5601/app/kibana#/dashboard/atm-transactions?_g=(refreshInterval:(pause:!f,value:30000),time:(from:now-15m,mode:quick,to:now)))
(u.U. Probleme mit Elasticsearch wegen max open files and max virtual memory)
```
ssh -i ~/keys/hackathon-temp-key.pem -N -L 5601:ip-i<Priv IP>.eu-central-1.compute.internal:5601 ec2-user@<PUBIP>
```
Tunnel to [neo4j](http://localhost:7474/browser/)
(geht nicht wegen WebSocket. Local sollte das aber gehen):
```
ssh -i ~/keys/hackathon-temp-key.pem -N -L 7474:ip-<Priv IP>.eu-central-1.compute.internal:7474 ec2-user@<Pup IP
```
login: neo4j / connect) and run query:
```
MATCH p=(n)-->() WHERE exists(n.customer_name) RETURN p LIMIT 2
```

## Confluent Cloud and KSQL, REST Proxy, Control Center (Evening)</h2>
The creation of the AWS environment will be done by Confluent. We will bring Confluent Platform into AWS and attendees will get their own environment -  [Code and description](https://github.com/ora0600/cpe53-singlenodeonaws)
Then one task would be to connect the Confluent Cloud Cluster with the local installation (or the AWS setup). This is described here - [Configure local Confluent Platform /Apache Kafka components to use Confluent Cloud Cluster](https://github.com/ora0600/local-Confluent-Platform2ConfluentCloud)
Additionally attendees can execute a couple of recipes

  * [KSQL Tumbeling Window](https://kafka-tutorials.confluent.io/create-tumbling-windows/ksql.html)
  * [KSQL Recipes](https://www.confluent.io/stream-processing-cookbook/)


Have fun and all the best</p>
  
