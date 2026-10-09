#!/bin/bash
# Desktop test of fovea.net.EventSourceStream (SSE reader) against a scripted local server.
# Usage: AIR_SDK=/path/to/AIRSDK tests-sse/run.sh   (after `make swc`)
set -e
cd "$(dirname "$0")"
AIR_SDK=${AIR_SDK:-../../../triominos-client/bin/AIRSDK_51.3.4.3}
mkdir -p out
"$AIR_SDK/bin/amxmlc" -output out/SSEStreamTest.swf -library-path+=../bin/ganomede.swc SSEStreamTest.as >/dev/null
cp SSEStreamTest-app.xml out/
node server.js & SERVER=$!
sleep 1
"$AIR_SDK/bin/adl" out/SSEStreamTest-app.xml out >/dev/null 2>&1 &
wait $SERVER
