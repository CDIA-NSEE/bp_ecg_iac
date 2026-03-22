connector.name=iceberg
iceberg.catalog.type=rest
iceberg.rest-catalog.uri=http://nessie:19120/iceberg

# Trino handles S3 I/O directly with the REST catalog — credentials go here, not in Nessie
fs.native-s3.enabled=true
s3.endpoint=http://minio:9000
s3.aws-access-key=${minio_root_user}
s3.aws-secret-key=${minio_root_password}
s3.path-style-access=true
s3.region=us-east-1
