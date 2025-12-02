## Use TAG to ignore the DML changes 

- setup XStream to ignore any DML LCR with tag
- create xstream  
```
DECLARE
  tables  varchar2(4096);
  schemas varchar2(4096);
BEGIN

    tables  := NULL;
    schemas := NULL;

  DBMS_XSTREAM_ADM.CREATE_OUTBOUND(
    server_name     =>  'xout',
    table_names     =>  tables,
    schema_names    =>  schemas);
END;
/


BEGIN
  DBMS_XSTREAM_ADM.ALTER_OUTBOUND(
     server_name  => 'xout',
     connect_user => 'cfltuser');
END;
/
```
- add rules to capture changes in schema and only DML with out tag
```
select * from dba_capture;

BEGIN
  DBMS_XSTREAM_ADM.ADD_SCHEMA_RULES(
    schema_name            => 'HR',
    streams_type          => 'capture',
    streams_name          => 'CAP$_XOUT_174',
    queue_name            => 'Q$_XOUT_175',
    include_dml           => TRUE,
    include_ddl           => TRUE,
    include_tagged_lcr => FALSE);
END;
/

SELECT * FROM DBA_XSTREAM_RULES;

```
- Once the xstream is setup, the sql client run this to generate transaction with tag and the transaction will be ignored and not captured by the xstream process.

The Oracle Database User need to be granted EXECTURE_CATALOG_ROLE in order to set tag. ( grant EXECTURE_CATALOG_ROLE to hr)

```
SQL> EXEC DBMS_STREAMS_ADM.SET_TAG(tag => HEXTORAW('17'));

PL/SQL procedure successfully completed.

SQL> update hr.employees set phone_number = '000-111-1207';

107 rows updated.

SQL> commit;

```


You can use this to remove the rule, after the testing
```
BEGIN
  DBMS_XSTREAM_ADM.REMOVE_RULE(
    rule_name => 'HR178',
        streams_type      => 'capture',
    streams_name          => 'CAP$_XOUT_174'
    );
    
END;
/
```

