
# How to test Oracle XStream CDC Connector 
## Kafka Connect Node Prep

- install Confluent Platform and Java 17 if not already
```
curl -O https://packages.confluent.io/archive/7.6/confluent-7.6.6.zip
sudo apt install openjdk-17-jre-headless

```  
- install Oracle XStream CDC Connector
```
$CONFLUENT_HOME/bin/onfluent-hub confluentinc/kafka-connect-oracle-xstream-cdc-source:1.0.0
```
- install Oracle Instant Client, download it from Oracle and unzip it
- install libaio1.so
```
# For Ubuntu
sudo apt install libaio1t64
sudo ln -s /usr/lib/x86_64-linux-gnu/libaio.so.1t64 /usr/lib/libaio.so.1
```
- Configure LD_LIBRARY_PATH to run Connect JVM
```
export LD_LIBRARY_PATH=/my/oracle/instantclient
```
or edit systememd service file, add "Enironment=LD_LIBRARY_PATH=/my/oracle/instantclient" into the service script under service section
```
cat /etc/systemd/system/confluent-kafka-connect.service
[Unit]
Description=Apache Kafka Connect - distributed
Documentation=http://docs.confluent.io/
After=network.target confluent-server.target

[Service]
Type=simple
User=ubuntu
Group=ubuntu
#ExecStart=/home/ubuntu/confluent-7.6.6/bin/connect-distributed /home/ubuntu/confluent-7.6.6/etc/kafka/connect-distributed.properties
ExecStart=/home/ubuntu/confluent-7.6.0/bin/connect-distributed /home/ubuntu/confluent-7.6.0/etc/kafka/connect-distributed.properties
TimeoutStopSec=180
Restart=no
Environment=LD_LIBRARY_PATH=/home/ubuntu/instantclient_19_27

[Install]
WantedBy=multi-user.target
```

- Add ojdbc8.jar and xstreams.jar to XStream Connector lib
```
cd cd instantclient_19_27/
cp ojdbc8.jar xstreams.jar $CONFLUENT_HOME/share/confluent-hub-components/confluentinc-kafka-connect-oracle-xstream-cdc-source/lib
```

## Oracle Datbase Prep

- enable GG replication
```
alter system set enable_goldengate_replication=true;
```

- Create tablespace in CDB and PDB 
```
-- Oracle XStream CDC Connector Prep
-- Multi-Tenant Database 

-- PDB: ORCLPDB1
alter session set container=orclpdb1;

CREATE TABLESPACE xstream_tbs DATAFILE '/opt/oracle/oradata/ORCL/ORCLPDB1/xstream_tbs.dbf' 
  SIZE 25M REUSE AUTOEXTEND ON MAXSIZE UNLIMITED;

-- Root CDB
alter session set container=cdb$root;

CREATE TABLESPACE xstream_tbs DATAFILE '/opt/oracle/oradata/ORCL/xstream_tbs.dbf' 
  SIZE 25M REUSE AUTOEXTEND ON MAXSIZE UNLIMITED;

```

- Create database user (two)
```
alter session set container=cdb$root;

CREATE USER c##xstrmadmin IDENTIFIED BY Demo1234 
  DEFAULT TABLESPACE xstream_tbs
  QUOTA UNLIMITED ON xstream_tbs
  CONTAINER=ALL;

GRANT CREATE SESSION, SET CONTAINER TO c##xstrmadmin CONTAINER=ALL;


BEGIN
   DBMS_XSTREAM_AUTH.GRANT_ADMIN_PRIVILEGE(
      grantee                 => 'c##xstrmadmin',
      privilege_type          => 'CAPTURE',
      grant_select_privileges => TRUE,
      container               => 'ALL');
END;
/


CREATE USER c##cfltuser IDENTIFIED BY Demo1234
  DEFAULT TABLESPACE xstream_tbs
  QUOTA UNLIMITED ON xstream_tbs
  CONTAINER=ALL;

GRANT CREATE SESSION, SET CONTAINER TO c##cfltuser CONTAINER=ALL;

GRANT SELECT_CATALOG_ROLE TO c##cfltuser CONTAINER=ALL;
GRANT SELECT ANY TABLE TO c##cfltuser CONTAINER=ALL;
GRANT LOCK ANY TABLE TO c##cfltuser CONTAINER=ALL;
GRANT FLASHBACK ANY TABLE TO c##cfltuser CONTAINER=ALL;
```


- enable supplement log
```
-- SUPPLEMENT LOG - ROOT
-- ALTER DATABASE ADD SUPPLEMENTAL LOG DATA (PRIMARY KEY, UNIQUE) COLUMNS;
ALTER DATABASE ADD SUPPLEMENTAL LOG DATA;

-- PDBORCL1
-- ALTER DATABASE ADD SUPPLEMENTAL LOG DATA (PRIMARY KEY, UNIQUE) COLUMNS;
alter session set container=orclpdb1;
ALTER DATABASE ADD SUPPLEMENTAL LOG DATA;
```

- enable full supplement log for the tables of interest
```
ALTER TABLE hr.employees ADD SUPPLEMENTAL LOG DATA (ALL) COLUMNS;
```

- create xstream outbound server
- Sets the confluent user as the connect user for the outbound server

```
conn c##xstrmadmin/Demo1234 
alter session set container=cdb$root;



BEGIN
DBMS_XSTREAM_ADM.DROP_OUTBOUND(
   server_name => 'xout');
END;
/


DECLARE
  tables  varchar2(4096);
  schemas varchar2(4096);
BEGIN

    tables  := 'hr.employees,hr.jobs';
    schemas := NULL;
  

  DBMS_XSTREAM_ADM.CREATE_OUTBOUND(
    server_name     =>  'xout',
    source_container_name => 'ORCLPDB1',
    table_names     =>  tables,
    schema_names    =>  schemas);
END;
/


DECLARE
  tables  DBMS_UTILITY.UNCL_ARRAY;
  schemas DBMS_UTILITY.UNCL_ARRAY;
BEGIN

    tables(1)  := 'hr.employees';
    tables(2)  := 'hr.jobs';
    tables(3)  := NULL;
    schemas(1) := NULL;
  

  DBMS_XSTREAM_ADM.CREATE_OUTBOUND(
    server_name     =>  'xout',
    source_container_name => 'ORCLPDB1',
    table_names     =>  tables,
    schema_names    =>  schemas);
END;
/

BEGIN
  DBMS_XSTREAM_ADM.ALTER_OUTBOUND(
     server_name  => 'xout',
     connect_user => 'c##cfltuser');
END;
/

SELECT CAPTURE_NAME FROM ALL_XSTREAM_OUTBOUND WHERE SERVER_NAME = 'XOUT';

BEGIN
  DBMS_CAPTURE_ADM.ALTER_CAPTURE(
    capture_name              => 'CAP$_XOUT_19',
    checkpoint_retention_time => 7);
END;
/
```

** if only grant on tables 
```
grant select on hr.employees to c##cfltuser;
GRANT FLASHBACK on hr.employees to c##cfltuser;
```

**For Oracle RAC 
```
DECLARE
  v_capture_name varchar2(32);
BEGIN
  select capture_name into v_capture_name from dba_xstream_outbound where server_name = 'XOUT';
  DBMS_CAPTURE_ADM.SET_PARAMETER(
    capture_name => v_capture_name,
    parameter    => 'use_rac_service',
    value        => 'Y');
END;
/

SELECT inst_id, service_id, name, network_name FROM gv$SERVICES WHERE NAME LIKE '%XOUT%';
```

** Configureation is done !



- Restart the outbound process if stopped
```
DECLARE
  v_capture_name varchar2(32);
BEGIN
  select capture_name into v_capture_name from dba_xstream_outbound 
  where server_name = 'XOUT';

  DBMS_CAPTURE_ADM.START_CAPTURE(
    capture_name => v_capture_name);
END;
/

BEGIN
DBMS_XSTREAM_ADM.STOP_OUTBOUND(
   server_name => "XOUT', 
   force  => true );
END;
/

BEGIN
DBMS_XSTREAM_ADM.START_OUTBOUND(
   server_name => "XOUT' 
   );
END;
/

```

### How to monitor the Oracle XStreaam Status - Key Process Status
```
SELECT STATE FROM V$XSTREAM_CAPTURE; 
SELECT state FROM V$PROPAGATION_RECEIVER;
select state from v$xstream_apply_reader;
SELECT * FROM V$SGASTAT WHERE POOL = 'streams pool' order by bytes desc;
SELECT STATE FROM V$XSTREAM_CAPTURE; 
SELECT state FROM V$PROPAGATION_RECEIVER;
select state from v$xstream_apply_reader;
SELECT * FROM V$SGASTAT WHERE POOL = 'streams pool' order by bytes desc;
SELECT a.TOTAL_MEMORY_ALLOCATED/(a.CURRENT_SIZE/100) as used_size_inPercentage , a.* FROM V$STREAMS_POOL_STATISTICS a;

```
Done!
