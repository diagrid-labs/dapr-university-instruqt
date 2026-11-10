#!/usr/bin/env bash
# VM health check: the sandbox is ready once the lab startup script has written its marker.
test -f /var/lib/lab-setup/ready
