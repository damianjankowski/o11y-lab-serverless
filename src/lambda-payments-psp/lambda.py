import json
import random
import time
from typing import Any, Dict

from aws_lambda_powertools import Logger
from aws_lambda_powertools.utilities.typing import LambdaContext

logger = Logger()

ERROR_CODES = ["INSUFFICIENT_FUNDS", "CARD_DECLINED", "EXPIRED_CARD", "INVALID_CARD", "FRAUD_SUSPECTED"]
FAILED_PAYMENT_IDS = set()


def build_response(status_code: int, body: Any) -> Dict:
    return {
        "statusCode": status_code,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps(body)
    }


@logger.inject_lambda_context
def handler(event: Dict[str, Any], context: LambdaContext) -> Dict[str, Any]:
    try:
        body = json.loads(event.get("body", "{}")) if isinstance(event.get("body"), str) else event.get("body", {})
        payment_id = body.get("payment_id")
        amount = body.get("amount")
        currency = body.get("currency")
        simulate = body.get("simulate", {})
        
        if not all([payment_id, amount, currency]):
            logger.error("Missing required fields", has_payment_id=bool(payment_id), has_amount=bool(amount), has_currency=bool(currency))
            return build_response(400, {"error": "Missing required fields: payment_id, amount, currency"})
        
        logger.append_keys(payment_id=payment_id)
        logger.info("PSP processing payment", amount=amount, currency=currency)
        
        time.sleep(random.uniform(0.1, 0.4))
        
        psp_config = simulate.get("psp", {})
        status = "success"
        error_code = None
        
        if psp_config.get("server_error") and payment_id not in FAILED_PAYMENT_IDS:
            FAILED_PAYMENT_IDS.add(payment_id)
            logger.error("Simulating server error", amount=amount, currency=currency)
            return build_response(500, {"error": "PSP service temporarily unavailable"})

        if psp_config.get("error") and payment_id not in FAILED_PAYMENT_IDS:
            FAILED_PAYMENT_IDS.add(payment_id)
            status = "failed"
            error_code = psp_config.get("error_code") or random.choice(ERROR_CODES)
            logger.warning("Simulating payment failure", error_code=error_code)
        
        response_body = {"payment_id": payment_id, "status": status}
        if error_code:
            response_body["error_code"] = error_code
        
        logger.info("Payment processed", status=status, amount=amount, currency=currency)
        return build_response(200, response_body)
    
    except json.JSONDecodeError:
        logger.exception("Invalid JSON in request body")
        return build_response(400, {"error": "Invalid JSON in request body"})
    
    except Exception:
        logger.exception("PSP internal error")
        return build_response(500, {"error": "PSP service unavailable"})
