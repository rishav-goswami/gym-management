#!/bin/sh

set -eu

if command -v java >/dev/null 2>&1 && java -version >/dev/null 2>&1; then
  exec npx firebase "$@"
fi

for java_home_candidate in \
  /opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home \
  /usr/local/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home
do
  if [ -x "$java_home_candidate/bin/java" ]; then
    JAVA_HOME="$java_home_candidate"
    PATH="$JAVA_HOME/bin:$PATH"
    export JAVA_HOME PATH
    exec npx firebase "$@"
  fi
done

echo "Java 21+ is required. Install it with: brew install openjdk@21" >&2
exit 1
