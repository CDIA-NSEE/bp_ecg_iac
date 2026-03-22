"""DAG for bp_ecg raw extractor pipeline.

Polls bp-ecg-{env}-images bucket for new .png.zst objects and triggers
the raw extractor to decompress, OCR, parse PDF, and write to Iceberg.

Uses Airflow 3 TaskFlow API — imports from airflow.sdk (not airflow.decorators).
"""

from __future__ import annotations

import json
import logging
from datetime import datetime, timedelta

import boto3
from airflow.models import Connection
from airflow.sdk import dag, task

log = logging.getLogger(__name__)


def _get_minio_connection() -> dict[str, str]:
    """Retrieve MinIO connection parameters from Airflow connection 'minio_default'."""
    conn: Connection = Connection.get_connection_from_secrets("minio_default")
    return {
        "endpoint_url": f"http://{conn.host}:{conn.port}",
        "aws_access_key_id": conn.login or "",
        "aws_secret_access_key": conn.password or "",
    }


def _get_bucket_name() -> str:
    """Read bucket name from Airflow Variable or fall back to default."""
    try:
        from airflow.models import Variable

        return Variable.get("bp_ecg_images_bucket", default_var="bp-ecg-dev-images")
    except Exception:
        return "bp-ecg-dev-images"


@dag(
    dag_id="bp_ecg_raw_extractor",
    schedule="@hourly",
    start_date=datetime(2024, 1, 1),
    catchup=False,
    max_active_runs=1,
    tags=["bp-ecg", "raw-extractor"],
    doc_md="""
    # bp_ecg Raw Extractor DAG

    Polls the MinIO images bucket for new `.png.zst` objects created within the
    current data interval, then processes each file through the raw extractor
    pipeline using dynamic task mapping.

    **Connection required:** `minio_default` (S3 type)
    - Host: MinIO endpoint hostname
    - Port: MinIO API port (9000)
    - Login: access key
    - Password: secret key
    """,
)
def bp_ecg_raw_extractor() -> None:
    """Define the bp_ecg raw extractor DAG."""

    @task
    def list_new_objects(
        data_interval_start: datetime | None = None,
        data_interval_end: datetime | None = None,
    ) -> list[str]:
        """List .png.zst objects in the images bucket created during the data interval.

        Returns a list of S3 object keys to be processed by the dynamic task map.
        """
        minio_conn = _get_minio_connection()
        bucket = _get_bucket_name()

        s3_client = boto3.client(
            "s3",
            endpoint_url=minio_conn["endpoint_url"],
            aws_access_key_id=minio_conn["aws_access_key_id"],
            aws_secret_access_key=minio_conn["aws_secret_access_key"],
        )

        paginator = s3_client.get_paginator("list_objects_v2")
        new_keys: list[str] = []

        for page in paginator.paginate(Bucket=bucket):
            for obj in page.get("Contents", []):
                key: str = obj["Key"]
                last_modified: datetime = obj["LastModified"]

                # Filter to objects created within the data interval
                if data_interval_start and data_interval_end:
                    # Make aware if needed
                    obj_ts = last_modified.replace(tzinfo=None)
                    start_ts = data_interval_start.replace(tzinfo=None) if hasattr(data_interval_start, "tzinfo") else data_interval_start
                    end_ts = data_interval_end.replace(tzinfo=None) if hasattr(data_interval_end, "tzinfo") else data_interval_end

                    if start_ts <= obj_ts < end_ts and key.endswith(".png.zst"):
                        new_keys.append(key)
                elif key.endswith(".png.zst"):
                    new_keys.append(key)

        log.info(
            "Found %d new objects in bucket '%s' for interval [%s, %s)",
            len(new_keys),
            bucket,
            data_interval_start,
            data_interval_end,
        )
        return new_keys

    @task(retries=2, retry_delay=timedelta(seconds=30))
    def process_file(object_key: str) -> dict[str, str]:
        """Process a single .png.zst file through the raw extractor pipeline.

        Invokes ``process_file_sync`` from ``bp_ecg_raw_extractor`` directly
        in the same process (no subprocess overhead).  The extractor handles
        decompression, OCR, PDF parsing, and Iceberg writing.

        Returns a result dict with processing status and metadata.
        """
        from bp_ecg_raw_extractor.config import Settings
        from bp_ecg_raw_extractor.processing.file_processor import process_file_sync

        log.info("Processing object: %s", object_key)
        settings = Settings()  # type: ignore[call-arg]
        result = process_file_sync(object_key, settings)
        log.info("Successfully processed: %s — %s", object_key, result)
        return {
            "object_key": object_key,
            "status": "success",
            "rows": str(result.get("rows", 0)),
        }

    @task
    def validate_output(results: list[dict[str, str]]) -> None:
        """Validate that all files were processed successfully.

        Raises AirflowException if any file failed processing, which will
        mark the DAG run as failed for alerting.
        """
        if not results:
            log.info("No files to validate (empty batch)")
            return

        successes = [r for r in results if r.get("status") == "success"]
        errors = [r for r in results if r.get("status") in ("error", "timeout")]

        log.info(
            "Validation summary: %d succeeded, %d failed out of %d total",
            len(successes),
            len(errors),
            len(results),
        )

        if errors:
            error_summary = json.dumps(errors, indent=2)
            from airflow.exceptions import AirflowException
            raise AirflowException(
                f"{len(errors)} file(s) failed processing:\n{error_summary}"
            )

        log.info("All %d files validated successfully", len(successes))

    # DAG wiring: list → dynamic map → validate
    keys = list_new_objects()
    file_results = process_file.expand(object_key=keys)  # dynamic task mapping
    validate_output(file_results)


# Instantiate the DAG
bp_ecg_raw_extractor()
