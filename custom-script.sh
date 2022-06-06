#!/bin/bash

cloud-init status --wait

/root/vstsagent.sh -s "{0}" -k "{1}" -t "{2}" -a "{3}" -v "{4}" -p "{5}"

[ -f /var/run/reboot-required ] && shutdown -r +1 || :
