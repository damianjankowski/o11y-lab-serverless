import argparse
import os
import random
import time
from uuid import uuid4

import dotenv
import requests

if os.path.exists(".env"):
    dotenv.load_dotenv()

TOTAL_REQUESTS = 100
MIN_DELAY_SEC = 2.0
MAX_DELAY_SEC = 8.0

# percentage of requests with errors
INIT_ERROR_PCT = 0.2
EXEC_ERROR_PCT = 0.1
PSP_SERVER_ERROR_PCT = 0
WALLET_ERROR_PCT = 0.1
PSP_BUSINESS_ERROR_PCT = 3
VALIDATION_ERROR_PCT = 2

URL = os.getenv("HOST")
TOTAL_REQUESTS = int(os.getenv("TOTAL_REQUESTS", TOTAL_REQUESTS))
MIN_DELAY_SEC = float(os.getenv("MIN_DELAY_SEC", MIN_DELAY_SEC))
MAX_DELAY_SEC = float(os.getenv("MAX_DELAY_SEC", MAX_DELAY_SEC))

INIT_ERROR_PCT = float(os.getenv("INIT_ERROR_PCT", INIT_ERROR_PCT))
EXEC_ERROR_PCT = float(os.getenv("EXEC_ERROR_PCT", EXEC_ERROR_PCT))
PSP_SERVER_ERROR_PCT = float(os.getenv("PSP_SERVER_ERROR_PCT", PSP_SERVER_ERROR_PCT))
PSP_BUSINESS_ERROR_PCT = float(
    os.getenv("PSP_BUSINESS_ERROR_PCT", PSP_BUSINESS_ERROR_PCT)
)
WALLET_ERROR_PCT = float(os.getenv("WALLET_ERROR_PCT", WALLET_ERROR_PCT))
VALIDATION_ERROR_PCT = float(os.getenv("VALIDATION_ERROR_PCT", VALIDATION_ERROR_PCT))

PSP_ERROR_CODES = [
    "INSUFFICIENT_FUNDS",
    "CARD_DECLINED",
    "EXPIRED_CARD",
    "INVALID_CARD",
    "FRAUD_SUSPECTED",
]


def get_error_indices(error_pct, total):
    """Generate random indices for error simulation."""
    num_errors = int(total * error_pct / 100)
    if num_errors == 0:
        return set()
    return set(random.sample(range(total), num_errors))


SELLER_ACCOUNTS = [
    "seller-acct-001",
    "seller-acct-002",
    "seller-acct-003",
    "seller-acct-004",
    "seller-acct-005",
    "seller-acct-006",
    "seller-acct-007",
    "seller-acct-008",
    "seller-acct-009",
    "seller-acct-010",
]


def create_invalid_payment():
    """Create a payment with validation errors."""
    error_type = random.choice(
        ["missing_checkout_id", "invalid_amount", "missing_buyer_info", "invalid_email"]
    )

    payment = {
        "checkout_id": f"chk-{uuid4().hex[:12]}",
        "buyer_info": {
            "user_id": f"buyer-{uuid4().hex[:8]}",
            "email": f"customer-{uuid4().hex[:6]}@example.com",
        },
        "credit_card_info": {"payment_token": f"tok_{uuid4().hex[:12]}"},
        "payment_orders": [
            {
                "payment_order_id": f"po-{uuid4().hex[:12]}",
                "seller_account": random.choice(SELLER_ACCOUNTS),
                "amount": f"{random.uniform(10, 100):.0f}",
                "currency": "USD",
            }
        ],
    }

    if error_type == "missing_checkout_id":
        del payment["checkout_id"]
    elif error_type == "invalid_amount":
        payment["payment_orders"][0]["amount"] = "invalid_amount"
    elif error_type == "missing_buyer_info":
        del payment["buyer_info"]
    elif error_type == "invalid_email":
        payment["buyer_info"]["email"] = "not-an-email"

    return payment, error_type


def create_payment(request_num, error_sets, is_validation_error=False):
    """Create a payment request, optionally with simulated errors."""
    if is_validation_error:
        payment, error_type = create_invalid_payment()
        return payment, [f"validation:{error_type}"]

    payment = {
        "checkout_id": f"chk-{uuid4().hex[:12]}",
        "buyer_info": {
            "user_id": f"buyer-{uuid4().hex[:8]}",
            "email": f"customer-{uuid4().hex[:6]}@example.com",
        },
        "credit_card_info": {"payment_token": f"tok_{uuid4().hex[:12]}"},
        "payment_orders": [
            {
                "payment_order_id": f"po-{uuid4().hex[:12]}",
                "seller_account": random.choice(SELLER_ACCOUNTS),
                "amount": f"{random.uniform(10, 100):.0f}",
                "currency": "USD",
            }
            for _ in range(random.randint(1, 2))
        ],
    }

    simulate = {}
    errors = []

    error_checks = [
        (
            "initializer",
            "initializer",
            error_sets.get("initializer", set()),
            {"error": True},
        ),
        ("executor", "executor", error_sets.get("executor", set()), {"error": True}),
        (
            "psp_server",
            "psp",
            error_sets.get("psp_server", set()),
            {"server_error": True},
        ),
        (
            "psp_business",
            "psp",
            error_sets.get("psp_business", set()),
            {"error": True, "error_code": random.choice(PSP_ERROR_CODES)},
        ),
        ("wallet", "wallet", error_sets.get("wallet", set()), {"error": True}),
    ]

    for error_name, simulate_key, indices, config in error_checks:
        if request_num in indices:
            if simulate_key in simulate:
                simulate[simulate_key].update(config)
            else:
                simulate[simulate_key] = config
            errors.append(error_name)

    if simulate:
        payment["simulate"] = simulate

    return payment, errors


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Payments simple checker with error simulation"
    )
    parser.add_argument("--errors", action="store_true", help="Enable error simulation")
    args = parser.parse_args()

    if not args.errors:
        INIT_ERROR_PCT = 0.0
        EXEC_ERROR_PCT = 0.0
        PSP_SERVER_ERROR_PCT = 0.0
        PSP_BUSINESS_ERROR_PCT = 0.0
        WALLET_ERROR_PCT = 0.0
        VALIDATION_ERROR_PCT = 0.0

    error_sets = {
        "initializer": get_error_indices(INIT_ERROR_PCT, TOTAL_REQUESTS),
        "executor": get_error_indices(EXEC_ERROR_PCT, TOTAL_REQUESTS),
        "psp_server": get_error_indices(PSP_SERVER_ERROR_PCT, TOTAL_REQUESTS),
        "psp_business": get_error_indices(PSP_BUSINESS_ERROR_PCT, TOTAL_REQUESTS),
        "wallet": get_error_indices(WALLET_ERROR_PCT, TOTAL_REQUESTS),
        "validation": get_error_indices(VALIDATION_ERROR_PCT, TOTAL_REQUESTS),
    }

    print("=== Payment Simulation Plan ===")
    print(f"Total requests: {TOTAL_REQUESTS}")
    print(f"URL: {URL}")
    print(f"Inter-request delay (random): {MIN_DELAY_SEC:.2f}s - {MAX_DELAY_SEC:.2f}s")
    print()
    print("Expected errors:")
    print(
        f"  Validation errors:      {len(error_sets['validation'])} ({VALIDATION_ERROR_PCT}%)"
    )
    print(
        f"  Initializer errors:     {len(error_sets['initializer'])} ({INIT_ERROR_PCT}%)"
    )
    print(
        f"  Executor errors:        {len(error_sets['executor'])} ({EXEC_ERROR_PCT}%)"
    )
    print(
        f"  PSP server (500) errors:{len(error_sets['psp_server'])} ({PSP_SERVER_ERROR_PCT}%)"
    )
    print(
        f"  PSP business errors:    {len(error_sets['psp_business'])} ({PSP_BUSINESS_ERROR_PCT}%)"
    )
    print(
        f"  Wallet errors:          {len(error_sets['wallet'])} ({WALLET_ERROR_PCT}%)"
    )
    print("\n=== Starting Payment Simulation ===\n")

    success_count = 0
    actual_errors = {
        "validation": 0,
        "initializer": 0,
        "executor": 0,
        "psp_server": 0,
        "psp_business": 0,
        "wallet": 0,
    }

    for i in range(TOTAL_REQUESTS):
        print(f"--- Request {i + 1}/{TOTAL_REQUESTS} ---")

        is_validation_error = i in error_sets["validation"]
        payment, errors = create_payment(i, error_sets, is_validation_error)

        if errors:
            print(f"Simulating errors: {', '.join(errors)}")
            for error in errors:
                error_key = error.split(":")[0] if ":" in error else error
                if error_key in actual_errors:
                    actual_errors[error_key] += 1
        else:
            print("No errors simulated")

        try:
            response = requests.post(
                URL,
                json=payment,
                headers={"Content-Type": "application/json"},
                timeout=30,
            )
            print(f"Status: {response.status_code}")
            try:
                print(f"Response: {response.json()}")
            except Exception:
                print(f"Response: {response.text[:200]}")
            success_count += 1 if response.status_code == 202 else 0
        except Exception as e:
            print(f"Request failed: {e}")

        time.sleep(random.uniform(MIN_DELAY_SEC, MAX_DELAY_SEC))

    failed_count = TOTAL_REQUESTS - success_count
    print("\n=== SIMULATION SUMMARY ===")
    print(f"\nRequests:")
    print(f"  Total: {TOTAL_REQUESTS}")
    print(f"  Successful (202): {success_count}")
    print(f"  Failed: {failed_count}")
    print("\nError Simulation (triggered):")
    print(f"  Validation:     {actual_errors['validation']}")
    print(f"  Initializer:    {actual_errors['initializer']}")
    print(f"  Executor:       {actual_errors['executor']}")
    print(f"  PSP Server:     {actual_errors['psp_server']}")
    print(f"  PSP Business:   {actual_errors['psp_business']}")
    print(f"  Wallet:         {actual_errors['wallet']}")
