
# How to test Oracle XStream CDC Connector 
## Kafka Connect Node Prep

- install Confluent Platform if not already following this steps[cp install](https://docs.confluent.io/platform/current/installation/installing_cp/rhel-centos.html#systemd-rhel-centos-install)

```
[ec2-user@ip-10-0-1-40 ~]$ sudo vi /etc/yum.repos.d/confluent.repo
[Confluent]
name=Confluent repository
baseurl=https://packages.confluent.io/rpm/8.1
gpgcheck=1
gpgkey=https://packages.confluent.io/rpm/8.1/archive.key
enabled=1

[Confluent-Clients]
name=Confluent Clients repository
baseurl=https://packages.confluent.io/clients/rpm/centos/$releasever/$basearch
gpgcheck=1
gpgkey=https://packages.confluent.io/clients/rpm/archive.key
enabled=1

[ec2-user@ip-10-0-1-40 ~]$ sudo yum clean all && sudo yum install confluent-platform
sudo dnf install java-17-openjdk.x86_64
```  

- install Oracle XStream CDC Connector
```
[ec2-user@ip-10-0-1-40 instantclient_19_29]$ sudo confluent-hub install confluentinc/kafka-connect-oracle-xstream-cdc-source:latest
The component can be installed in any of the following Confluent Platform installations:
  1. / (installed rpm/deb package)
  2. / (where this tool is installed)
Choose one of these to continue the installation (1-2):
1
Do you want to install this into /usr/share/confluent-hub-components? (yN) y


Component's license:
Confluent Software Evaluation License
https://www.confluent.io/software-evaluation-license
I agree to the software license agreement (yN) y

Downloading component Kafka Connect Oracle XStream Connector 1.3.0, provided by Confluent, Inc. from Confluent Hub and installing into /usr/share/confluent-hub-components
Detected Worker's configs:
  1. Standard: /etc/kafka/connect-distributed.properties
  2. Standard: /etc/kafka/connect-standalone.properties
  3. Standard: /etc/schema-registry/connect-avro-distributed.properties
  4. Standard: /etc/schema-registry/connect-avro-standalone.properties
Do you want to update all detected configs? (yN) y

Adding installation directory to plugin path in the following files:
  /etc/kafka/connect-distributed.properties
  /etc/kafka/connect-standalone.properties
  /etc/schema-registry/connect-avro-distributed.properties
  /etc/schema-registry/connect-avro-standalone.properties

Completed
[ec2-user@ip-10-0-1-40 instantclient_19_29]$ ls /usr/share/confluent-hub-components
confluentinc-kafka-connect-oracle-xstream-cdc-source
```

- install libaio1.so and libnsl on RedHat  9.5
```
sudo dnf install libaio
sudo dnf install libnsl
```

- install Oracle Instant Client, download it from Oracle and unzip it
```
wget https://download.oracle.com/otn_software/linux/instantclient/1929000/instantclient-basic-linux.x64-19.29.0.0.0dbru.zip
unzip instantclient-basic-linux.x64-19.29.0.0.0dbru.zip

```
- check all the library are installed and available for Oracle Instant Client
```
[ec2-user@ip-10-0-1-40 instantclient_19_29]$ pwd
/home/ec2-user/instantclient_19_29
[ec2-user@ip-10-0-1-40 instantclient_19_29]$ export LD_LIBRARY_PATH=/home/ec2-user/instantclient_19_29
[ec2-user@ip-10-0-1-40 instantclient_19_29]$ ldd libclntsh.so
	linux-vdso.so.1 (0x00007ffc9d58c000)
	libnnz19.so => /home/ec2-user/instantclient_19_29/libnnz19.so (0x00007f2d6c800000)
	libdl.so.2 => /lib64/libdl.so.2 (0x00007f2d7144d000)
	libm.so.6 => /lib64/libm.so.6 (0x00007f2d71372000)
	libpthread.so.0 => /lib64/libpthread.so.0 (0x00007f2d7136d000)
	libnsl.so.1 => /lib64/libnsl.so.1 (0x00007f2d71350000)
	librt.so.1 => /lib64/librt.so.1 (0x00007f2d7134b000)
	libaio.so.1 => /lib64/libaio.so.1 (0x00007f2d71346000)
	libresolv.so.2 => /lib64/libresolv.so.2 (0x00007f2d71332000)
	libc.so.6 => /lib64/libc.so.6 (0x00007f2d6c400000)
	/lib64/ld-linux-x86-64.so.2 (0x00007f2d71458000)
	libclntshcore.so.19.1 => /home/ec2-user/instantclient_19_29/libclntshcore.so.19.1 (0x00007f2d6be00000)

```


- Configure LD_LIBRARY_PATH to run Connect 

edit systememd service file, add "Enironment=LD_LIBRARY_PATH=/my/oracle/instantclient" into the service script under service section
```
[ec2-user@ip-10-0-1-40 lib]$ cat /usr/lib/systemd/system/confluent-kafka-connect.service

[Unit]
Description=Apache Kafka Connect - distributed
Documentation=http://docs.confluent.io/
After=network.target confluent-server.target

[Service]
Type=simple
User=cp-kafka-connect
Group=confluent
ExecStart=/usr/bin/connect-distributed /etc/kafka/connect-distributed.properties
TimeoutStopSec=180
Restart=no
Environment=LD_LIBRARY_PATH=/home/ec2-user/instantclient_19_29


[Install]
WantedBy=multi-user.target


```

- Add ojdbc8.jar and xstreams.jar to XStream Connector lib
```
cd instantclient_19_29/
cp ojdbc8.jar xstreams.jar /usr/share/confluent-hub-components/confluentinc-kafka-connect-oracle-xstream-cdc-source/lib
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
