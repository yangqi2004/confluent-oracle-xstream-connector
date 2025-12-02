# Use TAG to ignore the DML changes 

## setup XStream to ignore any DML LCR with tag
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
- add rules to capture changes in schema and DML/DDL without tag
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
## Test
Once the xstream is setup, the sql client run this to generate transaction with tag and the transaction will be ignored and not captured by the xstream process.

The Oracle Database User need to be granted EXECTURE_CATALOG_ROLE in order to set tag. ( grant EXECTURE_CATALOG_ROLE to hr)

```
SQL> EXEC DBMS_STREAMS_ADM.SET_TAG(tag => HEXTORAW('17'));

PL/SQL procedure successfully completed.

-- this DML will NOT be captured
SQL> update hr.employees set phone_number = '000-111-1207';

107 rows updated.

SQL> commit;

-- this will clear the tag, and all the following transactions will be captured
SQL> EXEC DBMS_STREAMS_ADM.SET_TAG();
PL/SQL procedure successfully completed.

-- this DML will be captured 
SQL> update hr.employees set phone_number = '000-111-1208';

107 rows updated.
SQL> commit;


```
The DDL with tags will be ignored as well. so if you need to capture DDL, make sure to clear tag before you run the DDL. 

```
SQL> EXEC DBMS_STREAMS_ADM.SET_TAG(tag => HEXTORAW('17'));

PL/SQL procedure successfully completed.

SQL> desc emp
 Name					   Null?    Type
 ----------------------------------------- -------- ----------------------------
 EMPLOYEE_ID					    NUMBER(6)
 FIRST_NAME					    VARCHAR2(20)
 LAST_NAME				   NOT NULL VARCHAR2(25)
 EMAIL					   NOT NULL VARCHAR2(25)
 PHONE_NUMBER				   NOT NULL VARCHAR2(20)
 HIRE_DATE				   NOT NULL DATE
 JOB_ID 				   NOT NULL VARCHAR2(10)
 SALARY 					    NUMBER(8,2)
 COMMISSION_PCT 				    NUMBER(2,2)
 MANAGER_ID					    NUMBER(6)
 DEPARTMENT_ID					    NUMBER(4)
 ADDRESS					    VARCHAR2(300)
 ADDRESS_NEW					    VARCHAR2(300)
 ADDRESS_ND					    VARCHAR2(300)
 NOTES						    VARCHAR2(100)
 NOTES_NEW					    VARCHAR2(300)
 SSN					   NOT NULL VARCHAR2(15)
 LAST_UPDATE					    DATE
 LAST_UPDATE_NEW				    DATE

SQL> alter table emp add ai_notes varchar2(100);

Table altered.

SQL> EXEC DBMS_STREAMS_ADM.SET_TAG()

PL/SQL procedure successfully completed.

SQL> alter table emp add ai_notes_new varchar2(100);

Table altered.
```
In this sample, the xstream process will only capture the second DDL.


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

