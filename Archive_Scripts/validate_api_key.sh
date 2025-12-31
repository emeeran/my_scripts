#!/bin/bash

# validate_api_key.sh - A simple Bash script to validate an API key.

# --- Configuration ---
# The expected API key should be set as an environment variable named API_KEY.
# Example: export API_KEY="your_secret_api_key_123"
# You can set this in your .bashrc, .profile, or directly in your terminal
# before running the script.
EXPECTED_API_KEY="$API_KEY"

# --- Main Logic ---

# 1. Check if the expected API key is set in the environment.
if [ -z "$EXPECTED_API_KEY" ]; then
    echo "Error: The 'API_KEY' environment variable is not set."
    echo "Please set it, e.g.: export API_KEY=\"your_secret_key_here\""
    exit 1
fi

# 2. Get the API key to validate from the first command-line argument.
PROVIDED_API_KEY="$1"

# 3. Check if an API key was provided as an argument.
if [ -z "$PROVIDED_API_KEY" ]; then
    echo "Usage: $0 <API_KEY_TO_VALIDATE>"
    echo "Example: $0 \"some_key_to_test\""
    exit 1
fi

# 4. Perform the validation.
echo "--- API Key Validation ---"
echo "Provided Key: '$PROVIDED_API_KEY'"
echo "Expected Key (from env): '${EXPECTED_API_KEY:0:4}**********'" # Obscure for display

if [[ "$PROVIDED_API_KEY" == "$EXPECTED_API_KEY" ]]; then
    echo "Validation Result: VALID. API key matches."
    exit 0 # Exit with status 0 for success
else
    echo "Validation Result: INVALID. API key does NOT match."
    exit 2 # Exit with a non-zero status for failure
fi
