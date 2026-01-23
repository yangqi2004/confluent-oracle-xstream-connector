# How to test it
## Add the jar file to connect-plugin folder
- compile and copy the jar file to connect plugin.path
```
mvn clean package
cp /home/qyang/work-cflt/custom-smt/RegexRoute/target/RegexRouter-1.0-SNAPSHOT.jar /home/qyang/confluent-7.9.0/share/confluent-hub-components/smt/
plugin.path = /usr/share/java, /home/qyang/confluent-7.9.0/share/confluent-hub-components
```

## Configure Connector SMT
- Replace "." with "-"
```
     "transforms": "change",
     "transforms.change.type": "io.confluent.qyang.connect.smt.RegexRouter",
     "transforms.change.regex": "\\.",
     "transforms.change.replacement": "-",
```

