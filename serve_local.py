from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
import os, sys

os.chdir(os.path.join(os.path.dirname(os.path.abspath(__file__)), 'docs'))
PREFIX = '/smart-fridge-project'

class Handler(SimpleHTTPRequestHandler):
    def do_GET(self):
        if self.path.startswith(PREFIX):
            self.path = self.path[len(PREFIX):] or '/'
        return super().do_GET()

print(f'serving docs/ at http://localhost:8000{PREFIX}/', flush=True)
ThreadingHTTPServer(('', 8000), Handler).serve_forever()
