"""Minimal HTTP server for ECS + ALB health checks (port 8080)."""

from http.server import BaseHTTPRequestHandler, HTTPServer


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *_args):
        return

    def do_GET(self):
        path = self.path.split("?", 1)[0]
        if path in ("/", "/healthz"):
            body = b"ok\n" if path == "/healthz" else b"hello\n"
            self.send_response(200)
            self.send_header("Content-Type", "text/plain; charset=utf-8")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
            return
        self.send_response(404)
        self.end_headers()


if __name__ == "__main__":
    HTTPServer(("0.0.0.0", 8080), Handler).serve_forever()
