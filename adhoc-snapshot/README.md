Enable Adhoc Snapshtting for the cc Oracle XStream CDC Connector
- create kafka topic oracle-xstream-signals
- add configure 
```
"signal.enabled.channels": "kafka",
"signal.kafka.topic": "oracle-xstream-signals",
```
- after the connector starts, produce the signal messages to the topic 
```
Key : topic_prefix
Value:
{ 
  "type":"execute-snapshot", 
  "data": 
   { 
	"type": "BLOCKING", 
	"data-collections": ["ORCL.HR.EMP"] 
   } 
}


```

