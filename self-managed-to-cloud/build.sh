export version=7.9.2
docker build . -t yangqi2004/connect-oracle-xstream:$version
docker push yangqi2004/connect-oracle-xstream:$version
