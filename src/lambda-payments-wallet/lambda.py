import json
import os
import time
from datetime import datetime, timezone
from decimal import Decimal
from typing import Any, Dict, Optional
import boto3
from botocore.exceptions import ClientError
from pydantic import BaseModel
from aws_lambda_powertools import Logger
from aws_lambda_powertools.utilities.batch import BatchProcessor, EventType, process_partial_response
from aws_lambda_powertools.utilities.typing import LambdaContext

logger = Logger()

PAYMENT_EVENT_TABLE = os.environ.get("PAYMENT_EVENT_TABLE", "PaymentEvent")
PAYMENT_ORDER_TABLE = os.environ.get("PAYMENT_ORDER_TABLE", "PaymentOrder")
WALLET_TABLE = os.environ.get("WALLET_TABLE", "Wallet")

dynamodb = boto3.resource("dynamodb")
payment_event_table = dynamodb.Table(PAYMENT_EVENT_TABLE)
payment_order_table = dynamodb.Table(PAYMENT_ORDER_TABLE)
wallet_table = dynamodb.Table(WALLET_TABLE)

def log_business_event(msg: str, event_type: str, checkout_id: str, outcome: str, stage: str = "SETTLEMENT", data: dict = None):
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

class PaymentResultMessage(BaseModel):
    checkout_id: str
    status: str
    error_code: Optional[str] = None
    simulate: Optional[Dict[str, Any]] = None

def simulate_error(simulate: Optional[Dict[str, Any]] = None) -> None:
    if not simulate:
        return
    
    config = simulate.get("wallet", {})
    
    if latency := config.get("latency"):
        logger.info("Simulating wallet latency", latency_seconds=latency)
        time.sleep(float(latency))
    
    if config.get("error"):
        error_msg = config.get("message", "Simulated wallet error")
        logger.error("Simulating wallet error", error=error_msg)
        raise RuntimeError(error_msg)

def process_payment_result(message: PaymentResultMessage) -> Dict[str, Any]:
    simulate_error(message.simulate)
    
    try:
        response = payment_order_table.query(
            IndexName="checkout_id-index",
            KeyConditionExpression="checkout_id = :checkout_id",
            ExpressionAttributeValues={":checkout_id": message.checkout_id}
        )
        payment_orders = response.get("Items", [])
        
        if not payment_orders:
            logger.warning("No payment orders found", checkout_id=message.checkout_id)
            return {
                "checkout_id": message.checkout_id,
                "status": message.status,
                "processed_orders": 0
            }
        
        if message.status == "SUCCESS":
            payment_event = payment_event_table.get_item(Key={"checkout_id": message.checkout_id})
            if "Item" not in payment_event:
                raise ValueError(f"Payment event not found: {message.checkout_id}")
            
            seller_info = payment_event["Item"].get("seller_info", {})
            seller_mapping = json.loads(seller_info) if isinstance(seller_info, str) else seller_info
            
            for order in payment_orders:
                payment_order_id = order["payment_order_id"]
                seller_account = seller_mapping.get(payment_order_id)
                
                if not seller_account:
                    raise ValueError(f"Missing seller_account for payment_order {payment_order_id}")
                
                wallet_table.update_item(
                    Key={"merchant_id": seller_account},
                    UpdateExpression="ADD balance :amount SET currency = :currency, updated_at = :timestamp",
                    ExpressionAttributeValues={
                        ":amount": Decimal(str(order["amount"])),
                        ":currency": order["currency"],
                        ":timestamp": Decimal(str(time.time()))
                    }
                )
                
                payment_order_table.update_item(
                    Key={"payment_order_id": payment_order_id},
                    UpdateExpression="SET payment_order_status = :status, wallet_updated = :wallet_updated",
                    ExpressionAttributeValues={
                        ":status": "SUCCESS",
                        ":wallet_updated": True
                    }
                )

                log_business_event(
                    msg="Payment order settled",
                    event_type="payment.order.settled",
                    checkout_id=message.checkout_id,
                    outcome="SUCCESS",
                    stage="SETTLEMENT",
                    data={
                        "payment_order.id": payment_order_id,
                        "amount.total": order["amount"],
                        "amount.currency": order["currency"],
                        "merchant.id": seller_account
                    }
                )
            
            payment_event_table.update_item(
                Key={"checkout_id": message.checkout_id},
                UpdateExpression="SET is_payment_done = :done",
                ExpressionAttributeValues={":done": True}
            )

            log_business_event(
                msg="Payment checkout settled",
                event_type="payment.checkout.settled",
                checkout_id=message.checkout_id,
                outcome="SUCCESS",
                stage="SETTLEMENT",
                data={
                    "amount.total": sum(Decimal(str(order["amount"])) for order in payment_orders),
                    "amount.currency": payment_orders[0]["currency"] if payment_orders else "USD",
                    "order.count": len(payment_orders)
                }
            )
            
        elif message.status == "FAILED":
            payment_event_response = payment_event_table.get_item(Key={"checkout_id": message.checkout_id})
            payment_event_item = payment_event_response.get("Item", {})
            seller_info = payment_event_item.get("seller_info", {})
            seller_mapping = json.loads(seller_info) if isinstance(seller_info, str) else seller_info
            
            for order in payment_orders:
                payment_order_id = order["payment_order_id"]
                seller_account = seller_mapping.get(payment_order_id, "UNKNOWN")
                
                payment_order_table.update_item(
                    Key={"payment_order_id": payment_order_id},
                    UpdateExpression="SET payment_order_status = :status",
                    ExpressionAttributeValues={":status": "FAILED"}
                )
                
                log_business_event(
                    msg="Payment order failed",
                    event_type="payment.order.failed",
                    checkout_id=message.checkout_id,
                    outcome="FAILURE",
                    stage="SETTLEMENT",
                    data={
                        "payment_order.id": payment_order_id,
                        "amount.total": order["amount"],
                        "amount.currency": order["currency"],
                        "merchant.id": seller_account,
                        "error.code": message.error_code or "PSP_ERROR",
                        "error.category": "PSP"
                    }
                )
        
        return {
            "checkout_id": message.checkout_id,
            "status": message.status,
            "processed_orders": len(payment_orders)
        }
        
    except ClientError as err:
        logger.exception("DynamoDB operation failed", error_type=type(err).__name__)
        raise RuntimeError(f"Database operation failed: {err}") from err
    except ValueError as err:
        logger.exception("Data integrity error", error_type=type(err).__name__)
        raise

def record_handler(record: Dict[str, Any]) -> None:
    message_body = record.get("body", "{}")
    data = json.loads(message_body) if isinstance(message_body, str) else message_body
    payment_result = PaymentResultMessage.model_validate(data)
        
    if payment_result.simulate:
        logger.info("Simulate config received from SQS", simulate_config=payment_result.simulate)
    
    process_payment_result(payment_result)

batch_processor = BatchProcessor(event_type=EventType.SQS)

@logger.inject_lambda_context
def handler(event: Dict[str, Any], context: LambdaContext) -> Dict[str, Any]:
    return process_partial_response(
        event=event,
        record_handler=record_handler,
        processor=batch_processor,
        context=context
    )
