#!/bin/bash

set -e

echo "Deleting namespaces..."
ip netns del ns1 || true
ip netns del ns2 || true
ip netns del router-ns || true

echo "Cleanup complete."
