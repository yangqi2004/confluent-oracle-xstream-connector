# How to Setup Oracle Connection Manager as Proxy to Oracle RAC behind the Firewall for Confluent XStream CDC Connector
![cman diagram](/image/cc-cman-rac.png?raw=true "Diagram")

## Install Oracle Connection Manager
Follow this [https://www.ateam-oracle.com/post/deploying-connection-manager-as-a-proxy-for-oracle-services] to install the Oracle Connection Manager. You will need to download
Oracle Database Client from OTN.

## Configure Oracle Connection Manager
- The cman listener will allow any nodes to register services
- The cman lisener will allow any  client to connect to any services
```
cat $TNS_ADMIN/cman.ora
CMAN_cman =
   (CONFIGURATION=
    (ADDRESS=(PROTOCOL=TCP)(HOST=cman)(port=1521))
    (rule_list= (rule= (src=*)(dst=*)(srv=*)(act=accept)) )
   )

VALID_NODE_CHECKING_REGISTRATION = on
REGISTRATION_INVITED_NODES = 192.168.1.*
VALID_NODE_CHECKING_REGISTRATION_cman_cman = on
REGISTRATION_INVITED_NODES_cman_cman = 192.168.1.*

cmctl start
cmctl show services
```
## Register Service to Connection Manager
Add listener_scan and listener_cman to tnsnames.ora on RAC Instances
```
[oracle@rac2 grid_base]$ cat /app/database/network/admin/tnsnames.ora

listener_scan=
 (DESCRIPTION=
  (ADDRESS_LIST=
   (ADDRESS=(PROTOCOL=tcp)(HOST=rac-scan)(PORT=1521))))

listener_cman=
 (DESCRIPTION=
  (ADDRESS_LIST=
   (ADDRESS=(PROTOCOL=tcp)(HOST=192.168.1.88)(PORT=1521))))
```

```
sqlplus '/as sysdba'
alter system set remote_listener = 'listener_scan,listener_cman' ;
```
## Reference
 - Install Oracle Connection Manager[https://www.ateam-oracle.com/post/deploying-connection-manager-as-a-proxy-for-oracle-services]
 - https://vitvar.com/2022/04/oracle-rac-db-behind-nginx-proxy/
 - https://blog.oracle-ninja.com/2016/02/23/configuring-vncr-for-11-2-0-4-oracle-rac/
