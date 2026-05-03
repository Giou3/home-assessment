"""Lightweight tests for the demo API (/healthz must return 200)."""

import http.client
import threading
import unittest
from http.server import HTTPServer

from server import Handler


class TestHandler(unittest.TestCase):
    def test_healthz_returns_200(self):
        server = HTTPServer(("127.0.0.1", 0), Handler)
        port = server.server_port
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        try:
            client = http.client.HTTPConnection("127.0.0.1", port, timeout=5)
            client.request("GET", "/healthz")
            response = client.getresponse()
            self.assertEqual(response.status, 200)
            self.assertEqual(response.read(), b"ok\n")
        finally:
            server.shutdown()

    def test_unknown_path_404(self):
        server = HTTPServer(("127.0.0.1", 0), Handler)
        port = server.server_port
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        try:
            client = http.client.HTTPConnection("127.0.0.1", port, timeout=5)
            client.request("GET", "/nope")
            response = client.getresponse()
            self.assertEqual(response.status, 404)
        finally:
            server.shutdown()


if __name__ == "__main__":
    unittest.main()
