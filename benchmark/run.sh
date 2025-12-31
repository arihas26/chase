#!/bin/bash

# Chase Benchmarks
# Requires: wrk (brew install wrk) or hey (go install github.com/rakyll/hey@latest)

set -e

cd "$(dirname "$0")"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Configuration
DURATION=10
THREADS=4
CONNECTIONS=100
MODE="jit"  # jit or aot
TESTS=""    # empty = all tests

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --aot)
            MODE="aot"
            shift
            ;;
        --jit)
            MODE="jit"
            shift
            ;;
        --duration)
            DURATION="$2"
            shift 2
            ;;
        --connections)
            CONNECTIONS="$2"
            shift 2
            ;;
        --test)
            TESTS="$2"
            shift 2
            ;;
        --help)
            echo "Usage: ./run.sh [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --aot             Use AOT-compiled native executables"
            echo "  --jit             Use JIT mode (default)"
            echo "  --duration N      Test duration in seconds (default: 10)"
            echo "  --connections N   Concurrent connections (default: 100)"
            echo "  --test NAME       Run specific test only"
            echo ""
            echo "Available tests:"
            echo "  text        Plain text response"
            echo "  json        JSON response"
            echo "  params      Route parameters"
            echo "  query       Query parameters"
            echo "  large       Large JSON response"
            echo "  middleware  Middleware chain"
            echo "  post        POST JSON body (hey only)"
            echo ""
            echo "Examples:"
            echo "  ./run.sh --aot"
            echo "  ./run.sh --aot --test middleware"
            echo "  ./run.sh --test json --duration 5"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Function to check if test should run
should_run() {
    local test_name=$1
    if [ -z "$TESTS" ]; then
        return 0  # Run all tests
    fi
    if [ "$TESTS" = "$test_name" ]; then
        return 0
    fi
    return 1
}

echo -e "${BLUE}================================${NC}"
echo -e "${BLUE}  Chase Benchmark Suite${NC}"
echo -e "${BLUE}================================${NC}"
echo ""
echo -e "${YELLOW}Mode: $(echo $MODE | tr 'a-z' 'A-Z')${NC}"
echo -e "${YELLOW}Duration: ${DURATION}s${NC}"
echo -e "${YELLOW}Connections: ${CONNECTIONS}${NC}"
echo ""

# Check for benchmark tool
if command -v wrk &> /dev/null; then
    BENCH_TOOL="wrk"
    echo -e "${GREEN}Using wrk for benchmarks${NC}"
elif command -v hey &> /dev/null; then
    BENCH_TOOL="hey"
    echo -e "${GREEN}Using hey for benchmarks${NC}"
else
    echo -e "${RED}Error: Please install wrk or hey${NC}"
    echo "  brew install wrk"
    echo "  or"
    echo "  go install github.com/rakyll/hey@latest"
    exit 1
fi

# Get dependencies
echo ""
echo -e "${BLUE}Installing dependencies...${NC}"
dart pub get

# Build directory for AOT
BUILD_DIR="build"

# Compile if AOT mode (always recompile to ensure latest code)
if [ "$MODE" = "aot" ]; then
    echo ""
    echo -e "${BLUE}Compiling native executables...${NC}"
    rm -rf $BUILD_DIR
    mkdir -p $BUILD_DIR

    echo "  Compiling chase_server..."
    dart compile exe bin/chase_server.dart -o $BUILD_DIR/chase_server

    echo "  Compiling shelf_server..."
    dart compile exe bin/shelf_server.dart -o $BUILD_DIR/shelf_server

    echo "  Compiling dartio_server..."
    dart compile exe bin/dartio_server.dart -o $BUILD_DIR/dartio_server

    echo "  Compiling dartfrog_server..."
    dart compile exe bin/dartfrog_server.dart -o $BUILD_DIR/dartfrog_server

    echo -e "${GREEN}Compilation complete!${NC}"
fi

# Function to run benchmark
run_benchmark() {
    local name=$1
    local port=$2
    local endpoint=$3
    local method=${4:-GET}
    local body=${5:-}

    echo ""
    echo -e "${GREEN}Benchmarking: $name - $method $endpoint${NC}"

    if [ "$BENCH_TOOL" = "wrk" ]; then
        if [ "$method" = "POST" ]; then
            wrk -t$THREADS -c$CONNECTIONS -d${DURATION}s -s post.lua "http://localhost:$port$endpoint"
        else
            wrk -t$THREADS -c$CONNECTIONS -d${DURATION}s "http://localhost:$port$endpoint"
        fi
    else
        if [ "$method" = "POST" ]; then
            hey -z ${DURATION}s -c $CONNECTIONS -m POST -d "$body" -T "application/json" "http://localhost:$port$endpoint"
        else
            hey -z ${DURATION}s -c $CONNECTIONS "http://localhost:$port$endpoint"
        fi
    fi
}

# Cleanup function
cleanup() {
    echo ""
    echo -e "${BLUE}Cleaning up...${NC}"
    [ -n "$CHASE_PID" ] && kill $CHASE_PID 2>/dev/null || true
    [ -n "$SHELF_PID" ] && kill $SHELF_PID 2>/dev/null || true
    [ -n "$DARTIO_PID" ] && kill $DARTIO_PID 2>/dev/null || true
    [ -n "$DARTFROG_PID" ] && kill $DARTFROG_PID 2>/dev/null || true
}

trap cleanup EXIT

# Start servers
echo ""
if [ "$MODE" = "aot" ]; then
    echo -e "${BLUE}Starting AOT-compiled servers...${NC}"

    echo "  Starting Chase server..."
    ./$BUILD_DIR/chase_server > /dev/null 2>&1 &
    CHASE_PID=$!

    echo "  Starting Shelf server..."
    ./$BUILD_DIR/shelf_server > /dev/null 2>&1 &
    SHELF_PID=$!

    echo "  Starting dart:io server..."
    ./$BUILD_DIR/dartio_server > /dev/null 2>&1 &
    DARTIO_PID=$!

    echo "  Starting dart_frog server..."
    ./$BUILD_DIR/dartfrog_server > /dev/null 2>&1 &
    DARTFROG_PID=$!
else
    echo -e "${BLUE}Starting JIT servers...${NC}"

    echo "  Starting Chase server..."
    dart run bin/chase_server.dart > /dev/null 2>&1 &
    CHASE_PID=$!

    echo "  Starting Shelf server..."
    dart run bin/shelf_server.dart > /dev/null 2>&1 &
    SHELF_PID=$!

    echo "  Starting dart:io server..."
    dart run bin/dartio_server.dart > /dev/null 2>&1 &
    DARTIO_PID=$!

    echo "  Starting dart_frog server..."
    dart run bin/dartfrog_server.dart > /dev/null 2>&1 &
    DARTFROG_PID=$!
fi

echo -e "${BLUE}Waiting for servers to start...${NC}"
sleep 3

echo ""
echo -e "${BLUE}All servers started. Running benchmarks...${NC}"

# Benchmark: Plain text
if should_run "text"; then
    echo ""
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE}  Test: Plain Text Response${NC}"
    echo -e "${BLUE}================================${NC}"
    run_benchmark "Chase" 3000 "/"
    run_benchmark "Shelf" 3001 "/"
    run_benchmark "dart:io" 3002 "/"
    run_benchmark "dart_frog" 3003 "/"
fi

# Benchmark: JSON
if should_run "json"; then
    echo ""
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE}  Test: JSON Response${NC}"
    echo -e "${BLUE}================================${NC}"
    run_benchmark "Chase" 3000 "/json"
    run_benchmark "Shelf" 3001 "/json"
    run_benchmark "dart:io" 3002 "/json"
    run_benchmark "dart_frog" 3003 "/json"
fi

# Benchmark: Route Parameters
if should_run "params"; then
    echo ""
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE}  Test: Route Parameters${NC}"
    echo -e "${BLUE}================================${NC}"
    run_benchmark "Chase" 3000 "/user/123"
    run_benchmark "Shelf" 3001 "/user/123"
    run_benchmark "dart:io" 3002 "/user/123"
    run_benchmark "dart_frog" 3003 "/user/123"
fi

# Benchmark: Query Parameters
if should_run "query"; then
    echo ""
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE}  Test: Query Parameters${NC}"
    echo -e "${BLUE}================================${NC}"
    run_benchmark "Chase" 3000 "/query?name=john&age=30"
    run_benchmark "Shelf" 3001 "/query?name=john&age=30"
    run_benchmark "dart:io" 3002 "/query?name=john&age=30"
    run_benchmark "dart_frog" 3003 "/query?name=john&age=30"
fi

# Benchmark: Large JSON
if should_run "large"; then
    echo ""
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE}  Test: Large JSON Response (100 items)${NC}"
    echo -e "${BLUE}================================${NC}"
    run_benchmark "Chase" 3000 "/large"
    run_benchmark "Shelf" 3001 "/large"
    run_benchmark "dart:io" 3002 "/large"
    run_benchmark "dart_frog" 3003 "/large"
fi

# Benchmark: Middleware Chain
if should_run "middleware"; then
    echo ""
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE}  Test: Middleware Chain${NC}"
    echo -e "${BLUE}================================${NC}"
    run_benchmark "Chase" 3000 "/middleware"
    run_benchmark "Shelf" 3001 "/middleware"
    run_benchmark "dart:io" 3002 "/middleware"
    run_benchmark "dart_frog" 3003 "/middleware"
fi

# Benchmark: POST with body (hey only, wrk needs lua script)
if should_run "post"; then
    if [ "$BENCH_TOOL" = "hey" ]; then
        echo ""
        echo -e "${BLUE}================================${NC}"
        echo -e "${BLUE}  Test: POST JSON Body${NC}"
        echo -e "${BLUE}================================${NC}"
        run_benchmark "Chase" 3000 "/echo" "POST" '{"message":"hello","count":42}'
        run_benchmark "Shelf" 3001 "/echo" "POST" '{"message":"hello","count":42}'
        run_benchmark "dart:io" 3002 "/echo" "POST" '{"message":"hello","count":42}'
        run_benchmark "dart_frog" 3003 "/echo" "POST" '{"message":"hello","count":42}'
    else
        echo -e "${YELLOW}POST test requires 'hey' tool (skipped)${NC}"
    fi
fi

echo ""
echo -e "${GREEN}================================${NC}"
echo -e "${GREEN}  Benchmarks Complete!${NC}"
echo -e "${GREEN}================================${NC}"
echo ""
echo -e "${YELLOW}Mode: $(echo $MODE | tr 'a-z' 'A-Z')${NC}"
