## To move SCN forward to skip some DML changes you will need to follow this steps

* Stop connector
```
curl localhost:8083/connectors/rac-xstream-A1104/offsets
curl -X PUT localhost:8083/connectors/rac-xstream-A1104/stop
```

* Stop outbound by force
```
BEGIN
DBMS_XSTREAM_ADM.STOP_OUTBOUND(
   server_name => 'XOUT',
   force => TRUE);
END;
/

select * from gv$session where module = 'XStream';
```

* change the outbound start_scn
```
select current_scn from v$database;

-- move forward scn 
BEGIN
  DBMS_XSTREAM_ADM.ALTER_OUTBOUND(
    server_name => 'xout',
    start_scn    => 58857034);
END;
/
```


* start the outbound
```
BEGIN
DBMS_XSTREAM_ADM.START_OUTBOUND(
   server_name => 'XOUT' );
END;
/

-- start_scn will NOT be updated 
select * from DBA_XSTREAM_OUTBOUND o, dba_capture c
where o.capture_name = c.capture_name;
```

* change the offset and start the connector
```
curl -X PATCH -H "Content-Type: application/json" localhost:8083/connectors/rac-xstream-A1104/offsets -d \
 '{
   "offsets": [
     {
       "partition": {
         "server": "A1104"
       },
       "offset": {
         "scn": "58857034",
         "snapshot": "INITIAL",
         "snapshot_completed": true
       }
     }
   ]
 }'

curl -X POST localhost:8083/connectors/rac-xstream-A1104/restart?includeTasks=true
curl -X PUT localhost:8083/connectors/rac-xstream-A1104/resume
```
