# The connector supports capture changes from mview (Streaming mode only)
## Add mview to XStream outbound and connector
```
BEGIN
  DBMS_XSTREAM_ADM.ALTER_OUTBOUND(
    server_name    => 'xout',
    table_names    => 'hr.employees_mv',
    
    add            => TRUE,
    inclusion_rule => TRUE);
END;
/

```
## Create the mview

```
-- prereq
-- grant CREATE MATERIALIZED VIEW to hr;
-- mview log for fash refresh
-- CREATE MATERIALIZED VIEW LOG ON hr.employees;

drop MATERIALIZED VIEW employees_mv;

-- mview fash refresh on commit
CREATE MATERIALIZED VIEW employees_mv
BUILD IMMEDIATE
REFRESH FAST ON STATEMENT USING TRUSTED CONSTRAINT
ENABLE QUERY REWRITE
AS
SELECT
    e.rowid as emp_rid, e.*, j.job_title
FROM
    employees e, jobs j
where e.job_id = j.job_id;

-- manual refresh
BEGIN
  DBMS_MVIEW.refresh('hr.employees_mv');
END;
/

EXEC DBMS_MVIEW.REFRESH('employees_mv', 'F');

-- test

insert into employees 
values(employees_seq.nextval,
   'Qi','Yang','qyang@confluent.io','2026013000', sysdate, 'MK_REP', 5000, 0, 201,20 );
```
