import json
import logging
import os
from uuid import uuid4
from random import randint
import dotenv
from locust import HttpUser, between, task

class Config:
    LATENCY_MIN: float = float(os.getenv("LATENCY_MIN", 0.1))
    LATENCY_MAX: float = float(os.getenv("LATENCY_MAX", 2 * 60))

dotenv.load_dotenv()

CONFIG = Config()

class SimulatedUser(HttpUser):
    host = os.getenv("HOST")
    wait_time = between(CONFIG.LATENCY_MIN, CONFIG.LATENCY_MAX)

    @task
    def simulate_post(self):
        payment = {
            "payment_id": str(uuid4()),
            "amount": randint(1, 1000),
            "currency": "EUR",
        }

        headers = {
            "Content-Type": "application/json",
        }
        self._send_request("POST", "/", json=payment, headers=headers)

    def _send_request(self, method, path, **kwargs):
        try:
            with self.client.request(method, path, catch_response=True, **kwargs) as response:
                log_info = {
                    "HTTP Method": method,
                    "Path": path,
                    "Response code": response.status_code,
                    "Response body": response.text,
                    "Response time (ms)": response.elapsed.total_seconds() * 1000,
                }
                logging.info(json.dumps(log_info))

                if response.status_code >= 400:
                    response.failure(f"Failure: Received {response.status_code}")
                else:
                    response.success()

        except Exception as e:
            logging.error(f"Error during {method} request to {path}: {str(e)}")
            raise
