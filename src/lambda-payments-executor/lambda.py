import json
import os
import time
from datetime import datetime, timezone
from typing import Any, Dict, Optional
import boto3
from botocore.exceptions import ClientError
import requests

from pydantic import BaseModel, ValidationError
from aws_lambda_powertools import Logger
from aws_lambda_powertools.utilities.batch import BatchProcessor, EventType, process_partial_response
from aws_lambda_powertools.utilities.typing import LambdaContext

logger = Logger()

# otel config
# import atexit
# from opentelemetry import metrics
# from opentelemetry.sdk.metrics import MeterProvider, Counter, Histogram, UpDownCounter, ObservableCounter, ObservableUpDownCounter
# from opentelemetry.sdk.metrics.export import PeriodicExportingMetricReader, AggregationTemporality
# from opentelemetry.exporter.otlp.proto.http.metric_exporter import OTLPMetricExporter
# from opentelemetry.sdk.resources import Resource, SERVICE_NAME

# manual span instrumentation
from opentelemetry import trace

# _otel_meter_provider = None
# try:
#     resource = Resource.create({SERVICE_NAME: os.environ.get("OTEL_SERVICE_NAME", "o11y-payments-executor")})
#     exporter = OTLPMetricExporter(
#         preferred_temporality={
#             Counter: AggregationTemporality.DELTA,
#             UpDownCounter: AggregationTemporality.CUMULATIVE,
#             Histogram: AggregationTemporality.DELTA,
#             ObservableCounter: AggregationTemporality.DELTA,
#             ObservableUpDownCounter: AggregationTemporality.CUMULATIVE,
#         }
#     )
#     reader = PeriodicExportingMetricReader(exporter=exporter, export_interval_millis=5000)
#     _otel_meter_provider = MeterProvider(resource=resource, metric_readers=[reader])
#     metrics.set_meter_provider(_otel_meter_provider)
#     atexit.register(_otel_meter_provider.shutdown)
# except Exception as e:
#     logger.warning(f"OpenTelemetry SDK initialization failed (metrics disabled): {e}")

# meter = metrics.get_meter_provider().get_meter("o11y-payments-executor", "1.0.0")
# tpv_counter = meter.create_counter(name="payment.tpv", description="Total Payment Volume", unit="1")

# dynatrace layer auto-captures this
tracer = trace.get_tracer("o11y-payments-executor", "1.0.0")

PAYMENT_RESULTS_QUEUE_URL = os.environ.get("PAYMENT_RESULTS_QUEUE_URL")
PSP_URL = os.environ.get("PSP_URL")

sqs = boto3.client("sqs")

def log_business_event(msg: str, event_type: str, checkout_id: str, outcome: str, stage: str = "EXECUTION", data: dict = None):
    """Emit structured Business Event log for Dynatrace extraction."""
    logger.info(msg,
        event_type=event_type,
        event_provider="payment-service",
        event_version="1.0",
        biz_checkout_id=checkout_id,
        biz_timestamp=datetime.now(timezone.utc).isoformat(),
        outcome=outcome,
        stage=stage,
        **(data or {})
    )

class ExecutionMessage(BaseModel):
    checkout_id: str
    total_amount: str
    currency: str
    credit_card_info: Dict[str, Any]
    simulate: Optional[Dict[str, Any]] = None

def simulate_error(simulate: Optional[Dict[str, Any]] = None) -> None:
    if not simulate:
        return

    config = simulate.get("executor", {})

    if latency := config.get("latency"):
        logger.info("Simulating executor latency", latency_seconds=latency)
        time.sleep(float(latency))

    if config.get("error"):
        error_msg = config.get("message", "Simulated error")
        logger.error("Simulating executor error", error=error_msg)
        raise RuntimeError(error_msg)


def process_payment_execution(message: ExecutionMessage) -> None:
    simulate_error(message.simulate)
    
    if not PSP_URL:
        raise RuntimeError("PSP_URL environment variable not set")

    psp_payload = {
        "payment_id": message.checkout_id,
        "amount": message.total_amount,
        "currency": message.currency
    }
    
    if message.simulate:
        psp_payload["simulate"] = message.simulate
        logger.info("Passing simulate config to PSP", simulate_config=message.simulate)
    
    start_time = time.time()
    
    try:
        with tracer.start_as_current_span("psp.call") as span:
            span.set_attribute("psp.url", PSP_URL)
            span.set_attribute("payment.checkout_id", message.checkout_id)
            response = requests.post(
                f"{PSP_URL}/process",
                json=psp_payload,
                timeout=30
            )
            span.set_attribute("http.status_code", response.status_code)

        duration = time.time() - start_time
        
        if response.status_code >= 500:
            log_business_event(
                msg="PSP server error",
                event_type="payment.psp.response",
                checkout_id=message.checkout_id,
                outcome="FAILURE",
                stage="PSP_INTEGRATION",
                data={
                    "amount.total": message.total_amount,
                    "amount.currency": message.currency,
                    "psp.response.status": "FAILED",
                    "psp.response.error_code": "PSP_SERVER_ERROR",
                    "psp.latency.ms": int(duration * 1000),
                    "error.category": "PSP"
                }
            )
            raise RuntimeError(f"PSP returned {response.status_code}")

        psp_response = response.json()
        error_code = psp_response.get("error_code")
        status = "SUCCESS" if psp_response.get("status") == "success" else "FAILED"

    except requests.exceptions.RequestException as err:
        duration = time.time() - start_time
        log_business_event(
            msg="PSP connection error",
            event_type="payment.psp.response",
            checkout_id=message.checkout_id,
            outcome="FAILURE",
            stage="PSP_INTEGRATION",
            data={
                "amount.total": message.total_amount,
                "amount.currency": message.currency,
                "psp.response.status": "FAILED",
                "psp.response.error_code": "CONNECTION_ERROR",
                "psp.latency.ms": int(duration * 1000),
                "error.category": "PSP"
            }
        )
        raise

    log_business_event(
        msg="PSP response received",
        event_type="payment.psp.response",
        checkout_id=message.checkout_id,
        outcome="SUCCESS" if status == "SUCCESS" else "FAILURE",
        stage="PSP_INTEGRATION",
        data={
            "amount.total": message.total_amount,
            "amount.currency": message.currency,
            "psp.response.status": status,
            "psp.response.error_code": error_code,
            "psp.latency.ms": int(duration * 1000)
        }
    )

    # if status == "SUCCESS":
    #     try:
    #         tpv_counter.add(
    #             float(message.total_amount),
    #             attributes={"currency": message.currency}
    #         )
    #     except Exception as e:
    #         logger.warning(f"Failed to record TPV metric: {e}")
    
    try:
        results_message = {
            "checkout_id": message.checkout_id,
            "status": status,
            "error_code": error_code,
            "simulate": message.simulate or {},
        }
        
        sqs.send_message(
            QueueUrl=PAYMENT_RESULTS_QUEUE_URL,
            MessageBody=json.dumps(results_message)
        )
        
        log_business_event(
            msg="Payment sent to wallet queue",
            event_type="payment.wallet.queued",
            checkout_id=message.checkout_id,
            outcome="SUCCESS" if status == "SUCCESS" else "FAILURE",
            stage="EXECUTION",
            data={
                "amount.total": message.total_amount,
                "amount.currency": message.currency,
                "payment.status": status,
                "error.code": error_code
            }
        )
    except ClientError as err:
        logger.exception("Failed to send payment result to results queue",
            error_type=type(err).__name__,
            queue_url=PAYMENT_RESULTS_QUEUE_URL
        )
        raise RuntimeError(f"Error while sending payment result to results queue: {err}") from err

def record_handler(record: Dict[str, Any]) -> None:
    message_body = record.get("body", "{}")
    data = json.loads(message_body) if isinstance(message_body, str) else message_body
    execution_message = ExecutionMessage.model_validate(data)
    process_payment_execution(execution_message)

batch_processor = BatchProcessor(event_type=EventType.SQS)

@logger.inject_lambda_context
def handler(event: Dict[str, Any], context: LambdaContext) -> Dict[str, Any]:
    # try:
    return process_partial_response(
        event=event,
        record_handler=record_handler,
        processor=batch_processor,
        context=context
    )
    # finally:
    #     if _otel_meter_provider:
    #         try:
    #             _otel_meter_provider.force_flush(timeout_millis=1000)
    #         except Exception:
    #             pass
