import json
import os
import time
from datetime import datetime, timezone
from decimal import Decimal, InvalidOperation
from typing import Any, Dict, Optional

import boto3
from botocore.exceptions import ClientError
from pydantic import BaseModel, ValidationError, field_validator
from aws_lambda_powertools import Logger
from aws_lambda_powertools.utilities.typing import LambdaContext

logger = Logger()

PAYMENT_EVENT_TABLE = os.environ.get("PAYMENT_EVENT_TABLE", "PaymentEvent")
PAYMENT_ORDER_TABLE = os.environ.get("PAYMENT_ORDER_TABLE", "PaymentOrder")
PAYMENT_EXECUTION_QUEUE_URL = os.environ.get("PAYMENT_EXECUTION_QUEUE_URL", "")

dynamodb = boto3.resource("dynamodb")
sqs = boto3.client("sqs")
payment_event_table = dynamodb.Table(PAYMENT_EVENT_TABLE)
payment_order_table = dynamodb.Table(PAYMENT_ORDER_TABLE)


def log_business_event(msg: str, event_type: str, checkout_id: str, outcome: str, stage: str = "INITIALIZATION", data: dict = None):
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


def simulate_error(simulate: Optional[Dict[str, Any]] = None) -> None:
    if not simulate:
        return

    config = simulate.get("initializer", {})

    if latency := config.get("latency"):
        logger.info("Simulating initializer latency", latency_seconds=latency)
        time.sleep(float(latency))

    if config.get("error"):
        error_msg = config.get("message", "Simulated initializer error")
        logger.error("Simulating initializer error", error=error_msg)
        raise RuntimeError(error_msg)


class BuyerInfo(BaseModel):
    user_id: str
    email: str


class PaymentOrder(BaseModel):
    payment_order_id: str
    seller_account: str
    amount: str
    currency: str

    @field_validator('amount')
    @classmethod
    def validate_amount(cls, v: str) -> str:
        try:
            if Decimal(v) < 0:
                raise ValueError("Amount must be non-negative")
            return v
        except (ValueError, ArithmeticError):
            raise ValueError(f"Invalid amount format: {v}")


class PaymentEvent(BaseModel):
    checkout_id: str
    buyer_info: BuyerInfo
    credit_card_info: Dict[str, Any]
    payment_orders: list[PaymentOrder]

    @property
    def total_amount(self) -> str:
        return str(sum(Decimal(o.amount) for o in self.payment_orders))

    @property
    def currency(self) -> str:
        return self.payment_orders[0].currency if self.payment_orders else "USD"

    @property
    def seller_info(self) -> Dict[str, str]:
        return {o.payment_order_id: o.seller_account for o in self.payment_orders}


def process_payment(payment: PaymentEvent, simulate: Optional[Dict] = None) -> Dict:
    log_business_event(
        msg="Payment checkout initiated",
        event_type="payment.checkout.initiated",
        checkout_id=payment.checkout_id,
        outcome="VALIDATED",
        stage="INITIALIZATION",
        data={
            "amount.total": payment.total_amount,
            "amount.currency": payment.currency,
            "order.count": len(payment.payment_orders)
        }
    )

    payment_event_table.put_item(Item={
        "checkout_id": payment.checkout_id,
        "buyer_info": payment.buyer_info.model_dump(),
        "seller_info": payment.seller_info,
        "credit_card_info": payment.credit_card_info,
        "is_payment_done": False,
    })

    with payment_order_table.batch_writer() as batch:
        for order in payment.payment_orders:
            batch.put_item(Item={
                "payment_order_id": order.payment_order_id,
                "buyer_account": payment.buyer_info.user_id,
                "amount": order.amount,
                "currency": order.currency,
                "checkout_id": payment.checkout_id,
                "payment_order_status": "NOT_STARTED",
                "ledger_updated": False,
                "wallet_updated": False,
            })

    simulate_error(simulate)

    sqs.send_message(
        QueueUrl=PAYMENT_EXECUTION_QUEUE_URL,
        MessageBody=json.dumps({
            "checkout_id": payment.checkout_id,
            "total_amount": payment.total_amount,
            "currency": payment.currency,
            "credit_card_info": payment.credit_card_info,
            "simulate": simulate or {},
        })
    )

    log_business_event(
        msg="Payment sent to execution queue",
        event_type="payment.checkout.queued",
        checkout_id=payment.checkout_id,
        outcome="QUEUED",
        stage="INITIALIZATION",
        data={
            "amount.total": payment.total_amount,
            "amount.currency": payment.currency,
            "order.count": len(payment.payment_orders)
        }
    )

    return {"payment_event": payment.model_dump(), "message": "Payment event initiated"}


def build_response(status_code: int, body: Any) -> Dict:
    return {
        "statusCode": status_code,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps(body, default=str)
    }


def format_validation_errors(errors: list) -> list:
    return [
        {
            "field": ".".join(str(loc) for loc in e.get("loc", [])),
            "message": e.get("msg", "").replace("Value error, ", ""),
            "value": e.get("input")
        }
        for e in errors
    ]


@logger.inject_lambda_context
def handler(event: Dict[str, Any], context: LambdaContext) -> Dict[str, Any]:
    try:
        body = json.loads(event.get("body", "{}"))
        checkout_id = body.get("checkout_id", "UNKNOWN")
    except json.JSONDecodeError:
        return build_response(400, {"error": "Invalid JSON"})

    orders = body.get("payment_orders", [])
    try:
        total = str(sum(Decimal(str(o.get("amount", 0))) for o in orders)) if orders else "0"
        currency = orders[0].get("currency", "UNKNOWN") if orders else "UNKNOWN"
    except (TypeError, ValueError, InvalidOperation):
        total, currency = "0", "UNKNOWN"

    log_business_event(
        msg="Payment request received",
        event_type="payment.request.received",
        checkout_id=checkout_id,
        outcome="RECEIVED",
        stage="REQUEST",
        data={
            "amount.total": total,
            "amount.currency": currency,
            "order.count": len(orders)
        }
    )

    try:
        payment = PaymentEvent.model_validate(body)
        result = process_payment(payment, body.get("simulate"))
        return build_response(202, result)

    except ValidationError as err:
        logger.warning("Validation failed", validation_errors=err.errors())
        log_business_event(
            msg="Payment validation failed",
            event_type="payment.checkout.rejected",
            checkout_id=checkout_id,
            outcome="REJECTED",
            stage="VALIDATION",
            data={
                "error.code": "VALIDATION_ERROR",
                "error.message": str(err.errors()[:3]),
                "order.count": len(orders)
            }
        )
        return build_response(400, {"error": "Validation failed", "details": format_validation_errors(err.errors())})

    except ClientError as err:
        logger.exception("AWS service error", error_type=type(err).__name__)
        return build_response(500, {"error": "Service unavailable", "message": str(err)})

    except RuntimeError as err:
        logger.exception("Processing error", error_type=type(err).__name__)
        return build_response(500, {"error": "Processing failed", "message": str(err)})

    except Exception as err:
        logger.exception("Unexpected error", error_type=type(err).__name__)
        return build_response(500, {"error": "Internal server error"})
