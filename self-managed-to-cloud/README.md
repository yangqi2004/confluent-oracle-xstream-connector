
# How to test Oracle XStream CDC Connector 
1. Kafka Connect Node Prep
- install Confluent Platform 
- install Oracle XStream CDC Connector
- install Oracle Instant Client
- install libaio1.so
```
download instantclient
sudo ln -s /usr/lib/x86_64-linux-gnu/libaio.so.1t64 /usr/lib/libaio.so.1
```
- Configure LD_LIBRARY_PATH to run Connect JVM

2. Oracle Datbase Prep

-- enable GG replication
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




-- ./xio -ob_svr xout -ob_db orcl -ob_usr c##xstrmadmin -ob_pwd Demo1234 


-- grant select on hr.employees to c##xstrmadmin;
-- GRANT FLASHBACK on hr.employees to c##xstrmadmin;

-- kafka-topics --bootstrap-server kafka-ext:9092 --create --topic cflt.HR.EMPLOYEES


-- avro schema changed after this (added default null for both key and value)

create table emp as select * from employees;
grant select on emp to c##xstrmadmin;
GRANT FLASHBACK on emp to c##xstrmadmin;
ALTER TABLE emp ADD SUPPLEMENTAL LOG DATA (ALL) COLUMNS;

grant select on jobs to c##xstrmadmin;
GRANT FLASHBACK on jobs to c##xstrmadmin;
ALTER TABLE jobs ADD SUPPLEMENTAL LOG DATA (ALL) COLUMNS;


-- Connector flow 

SELECT current_scn FROM v$DATABASE;
-- snapshot
select * from table as of current_scn;
-- streaming
XStreamUtility.convertSCNToPosition(oracle.sql.NUMBER scn, XStreamUtility.POS_VERSION_V2);
xstreamOut.receiveLCRCallback(new LcrEventHandler(), XStreamOut.DEFAULT_MODE)
```


## XStream Monitoring
```
select * from dba_roles where role like 'GG%';
select * from dba_tab_privs where TABLE_NAME = 'DBMS_XSTREAM_ADM';

SELECT * FROM DBA_GG_SUPPORTED_PACKAGES;

SELECT /*+PARAM('_module_action_old_length',0)*/ ACTION,
       SID,
       SERIAL#,
       PROCESS,
       SUBSTR(PROGRAM,INSTR(PROGRAM,'(')+1,4) PROCESS_NAME
  FROM V$SESSION
  WHERE MODULE ='XStream';
  
  SELECT STREAMS_NAME,
       PROCESS_TYPE,
       EVENT_NAME,
       DESCRIPTION,
       EVENT_TIME
  FROM DBA_REPLICATION_PROCESS_EVENTS;
  
SELECT SERVER_NAME, 
       CONNECT_USER, 
       CAPTURE_USER, 
       CAPTURE_NAME,
       SOURCE_DATABASE,
       QUEUE_OWNER,
       QUEUE_NAME
  FROM ALL_XSTREAM_OUTBOUND;
  
SELECT APPLY_NAME, 
       STATUS,
       ERROR_NUMBER,
       ERROR_MESSAGE
  FROM DBA_APPLY
  WHERE PURPOSE = 'XStream Out'; 
  
  SELECT SERVER_NAME,
       XIDUSN ||'.'|| 
       XIDSLT ||'.'||
       XIDSQN "Transaction ID",
       COMMITSCN,
       COMMIT_POSITION,
       LAST_SENT_POSITION,
       MESSAGE_SEQUENCE
  FROM V$XSTREAM_OUTBOUND_SERVER;
  
SELECT SERVER_NAME,
       TOTAL_TRANSACTIONS_SENT,
       TOTAL_MESSAGES_SENT,
       (BYTES_SENT/1024)/1024 BYTES_SENT,
       (ELAPSED_SEND_TIME/100) ELAPSED_SEND_TIME,
       LAST_SENT_MESSAGE_NUMBER,
       TO_CHAR(LAST_SENT_MESSAGE_CREATE_TIME,'HH24:MI:SS MM/DD/YY') 
          LAST_SENT_MESSAGE_CREATE_TIME
  FROM V$XSTREAM_OUTBOUND_SERVER;
  
SELECT SERVER_NAME,
       SOURCE_DATABASE,
       PROCESSED_LOW_POSITION,
       TO_CHAR(PROCESSED_LOW_TIME,'HH24:MI:SS MM/DD/YY') PROCESSED_LOW_TIME
FROM ALL_XSTREAM_OUTBOUND_PROGRESS;

SELECT APPLY_NAME,
       PARAMETER, 
       VALUE,
       SET_BY_USER  
  FROM ALL_APPLY_PARAMETERS a, ALL_XSTREAM_OUTBOUND o
  WHERE a.APPLY_NAME=o.SERVER_NAME
  ORDER BY a.PARAMETER;
  
  SELECT CAPTURE_NAME,
       STATE,
       TOTAL_MESSAGES_CAPTURED,
       TOTAL_MESSAGES_ENQUEUED 
  FROM V$XSTREAM_CAPTURE;
  
  SELECT r.CONSUMER_NAME,
       r.SOURCE_DATABASE,
       r.SEQUENCE#, 
       r.NAME, 
       r.DICTIONARY_BEGIN, 
       r.DICTIONARY_END 
  FROM DBA_REGISTERED_ARCHIVED_LOG r, ALL_CAPTURE c
  WHERE r.CONSUMER_NAME = c.CAPTURE_NAME;
  
  SELECT r.CONSUMER_NAME,
       r.SOURCE_DATABASE,
       r.SEQUENCE#, 
       r.NAME 
  FROM DBA_REGISTERED_ARCHIVED_LOG r, ALL_CAPTURE c
  WHERE r.CONSUMER_NAME =  c.CAPTURE_NAME AND
        r.NEXT_SCN      >= c.REQUIRED_CHECKPOINT_SCN;
        
        SELECT r.CONSUMER_NAME,
       r.NAME, 
       r.FIRST_SCN,
       r.NEXT_SCN,
       r.PURGEABLE 
  FROM DBA_REGISTERED_ARCHIVED_LOG r, ALL_CAPTURE c
  WHERE r.CONSUMER_NAME = c.CAPTURE_NAME;
  
  SELECT c.CAPTURE_NAME,
       PARAMETER,
       VALUE,
       SET_BY_USER
  FROM ALL_CAPTURE_PARAMETERS c, ALL_XSTREAM_OUTBOUND o
  WHERE c.CAPTURE_NAME=o.CAPTURE_NAME
  ORDER BY PARAMETER;
  
  SELECT CAPTURE_NAME, APPLIED_SCN FROM ALL_CAPTURE;
  
  SELECT CAPTURE_NAME,
       ((SYSDATE - CAPTURE_MESSAGE_CREATE_TIME)*86400) LATENCY_SECONDS,
       ((SYSDATE - CAPTURE_TIME)*86400) LAST_STATUS,
       TO_CHAR(CAPTURE_TIME, 'HH24:MI:SS MM/DD/YY') CAPTURE_TIME,       
       TO_CHAR(CAPTURE_MESSAGE_CREATE_TIME, 'HH24:MI:SS MM/DD/YY') CREATE_TIME
  FROM V$XSTREAM_CAPTURE;
  
  SELECT CAPTURE_NAME, ATTRIBUTE_NAME, INCLUDE 
  FROM ALL_CAPTURE_EXTRA_ATTRIBUTES
  ORDER BY CAPTURE_NAME;
```


## Enable Tableflow
```
ALTER TABLE `Qi.cluster_4.AWS.HR.EMPLOYEES` SET (
  'value.format' = 'avro-registry',
  'changelog.mode' = 'append'
);

ALTER TABLE `Qi`.`cluster_4`.`AWS.HR.EMPLOYEES` SET (
ALTER TABLE `Qi`.`cluster_4`.`fm-hr-employees` SET (
  'value.format' = 'avro-registry',
  'changelog.mode' = 'append'
);
```

## Tableflow don't like upper case topics
Use SMT to change the topic name from upper case to lower case

```
        "transforms" = "route"
        "transforms.route.type" =  "io.confluent.connect.cloud.transforms.TopicRegexRouter"
        "transforms.route.regex" =  "fm.HR.EMPLOYEES"
        "transforms.route.replacement" = "fm-hr-employees"
```
Use SMT to rewrite the data 
```
        "transforms" = "route,unwrap"
        "transforms.unwrap.type" = "io.debezium.transforms.ExtractNewRecordState"
        "transforms.unwrap.add.fields" ="op,table,lsn,source.ts_ms"
        "transforms.unwrap.add.headers" = "db"
        "transforms.unwrap.delete.handling.mode"="rewrite"
```

## Use Trino to access iceberg
Start trino docker container
```
docker run -d \
  --name trino \
  -p 8080:8080 \
  -v ./catalog:/etc/trino/catalog \
  trinodb/trino
```
Query the data in trino
```
docker exec -it trino trino
show tables from tableflow."lkc-xzpgpz";
desc tableflow."lkc-xzpgpz"."fm-hr-employees";
select before.phone_number, after.phone_number from  tableflow."lkc-xzpgpz"."fm-hr-employees" where op ='u';
```


### Restart Capture process after database restart
If you see ORA-1031 error in Capture Process
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

** Manually start the outbound and capture process
```
BEGIN
  DBMS_CAPTURE_ADM.START_CAPTURE(
    capture_name => 'xs_capture');
END;
/


BEGIN
  DBMS_XSTREAM_ADM.START_OUTBOUND(
    server_name => 'xs_outbound');
END;
/
```
