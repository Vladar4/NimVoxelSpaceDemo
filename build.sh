#!/bin/sh
nim c -d:release --opt:speed nvs_demo.nim
rm -rf nimcache
