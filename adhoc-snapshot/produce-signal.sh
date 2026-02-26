
#echo 'RAC={ "type":"execute-snapshot", "data": { "type": "BLOCKING", "data-collections": ["ORCL.HR.EMPLOYEES"] } }' | confluent kafka topic produce --delimiter "=" --parse-key  oracle-xstream-signals
echo 'RAC={ "type":"execute-snapshot", "data": { "type": "BLOCKING", "data-collections": ["ORCL.HR.EMP"] } }' | confluent kafka topic produce --delimiter "=" --parse-key  oracle-xstream-signals


