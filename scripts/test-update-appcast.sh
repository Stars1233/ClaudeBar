#!/bin/bash
# Unit tests for update-appcast.sh
# Tests all version update scenarios for beta channel support
#
# Usage: ./scripts/test-update-appcast.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
UPDATE_SCRIPT="$SCRIPT_DIR/update-appcast.sh"
TEST_DIR=$(mktemp -d)
ORIGINAL_APPCAST="$SCRIPT_DIR/../docs/appcast.xml"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Setup: backup original appcast and use test directory
setup() {
    if [[ -f "$ORIGINAL_APPCAST" ]]; then
        cp "$ORIGINAL_APPCAST" "$TEST_DIR/appcast.xml.backup"
    fi
    mkdir -p "$SCRIPT_DIR/../docs"
}

# Teardown: restore original appcast
teardown() {
    if [[ -f "$TEST_DIR/appcast.xml.backup" ]]; then
        cp "$TEST_DIR/appcast.xml.backup" "$ORIGINAL_APPCAST"
    fi
    rm -rf "$TEST_DIR"
}

# Run update-appcast.sh with given parameters
run_update() {
    local version="$1"
    local build="$2"
    local channel="${3:-}"

    "$UPDATE_SCRIPT" "$version" "$build" "https://example.com/$version.zip" "sig$build" "1000000" "Release notes" "$channel" > /dev/null 2>&1
}

# Assert appcast contains a specific version
assert_contains_version() {
    local version="$1"
    local appcast="$SCRIPT_DIR/../docs/appcast.xml"

    if grep -q "<sparkle:shortVersionString>$version</sparkle:shortVersionString>" "$appcast"; then
        return 0
    else
        return 1
    fi
}

# Assert appcast does NOT contain a specific version
assert_not_contains_version() {
    local version="$1"
    local appcast="$SCRIPT_DIR/../docs/appcast.xml"

    if grep -q "<sparkle:shortVersionString>$version</sparkle:shortVersionString>" "$appcast"; then
        return 1
    else
        return 0
    fi
}

# Assert appcast contains exactly N items
assert_item_count() {
    local expected="$1"
    local appcast="$SCRIPT_DIR/../docs/appcast.xml"
    local actual=$(grep -c "<item>" "$appcast" || echo "0")

    if [[ "$actual" -eq "$expected" ]]; then
        return 0
    else
        echo "Expected $expected items, got $actual"
        return 1
    fi
}

# Assert version has beta channel tag
assert_has_beta_channel() {
    local version="$1"
    local appcast="$SCRIPT_DIR/../docs/appcast.xml"

    # Use awk to extract the specific item block containing this version
    # Then check if that block has the beta channel tag
    local item_block=$(awk -v ver="$version" '
        /<item>/ { item=""; in_item=1 }
        in_item { item = item $0 "\n" }
        /<\/item>/ {
            in_item=0
            if (item ~ "<sparkle:shortVersionString>" ver "</sparkle:shortVersionString>") {
                print item
                exit
            }
        }
    ' "$appcast")

    if echo "$item_block" | grep -q "<sparkle:channel>beta</sparkle:channel>"; then
        return 0
    else
        return 1
    fi
}

# Assert version does NOT have beta channel tag
assert_no_channel() {
    local version="$1"
    local appcast="$SCRIPT_DIR/../docs/appcast.xml"

    # Use awk to extract the specific item block containing this version
    local item_block=$(awk -v ver="$version" '
        /<item>/ { item=""; in_item=1 }
        in_item { item = item $0 "\n" }
        /<\/item>/ {
            in_item=0
            if (item ~ "<sparkle:shortVersionString>" ver "</sparkle:shortVersionString>") {
                print item
                exit
            }
        }
    ' "$appcast")

    if echo "$item_block" | grep -q "<sparkle:channel>"; then
        return 1
    else
        return 0
    fi
}

# Clear appcast for fresh test
clear_appcast() {
    rm -f "$SCRIPT_DIR/../docs/appcast.xml"
}

# Run a single test
run_test() {
    local test_name="$1"
    local test_fn="$2"

    TESTS_RUN=$((TESTS_RUN + 1))

    # Clear appcast before each test
    clear_appcast

    if $test_fn; then
        echo -e "${GREEN}✓${NC} $test_name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}✗${NC} $test_name"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

# =============================================================================
# TEST CASES
# =============================================================================

test_stable_release_creates_single_item() {
    run_update "1.0.0" "100"

    assert_item_count 1 && \
    assert_contains_version "1.0.0" && \
    assert_no_channel "1.0.0"
}

test_beta_release_creates_single_item_with_channel() {
    run_update "1.0.1-beta" "101" "beta"

    assert_item_count 1 && \
    assert_contains_version "1.0.1-beta" && \
    assert_has_beta_channel "1.0.1-beta"
}

test_beta_after_stable_keeps_both() {
    run_update "1.0.0" "100"
    run_update "1.0.1-beta" "101" "beta"

    assert_item_count 2 && \
    assert_contains_version "1.0.0" && \
    assert_contains_version "1.0.1-beta" && \
    assert_no_channel "1.0.0" && \
    assert_has_beta_channel "1.0.1-beta"
}

test_stable_after_beta_keeps_both() {
    run_update "1.0.1-beta" "101" "beta"
    run_update "1.0.0" "100"

    assert_item_count 2 && \
    assert_contains_version "1.0.0" && \
    assert_contains_version "1.0.1-beta" && \
    assert_no_channel "1.0.0" && \
    assert_has_beta_channel "1.0.1-beta"
}

test_new_beta_replaces_old_beta_keeps_stable() {
    run_update "1.0.0" "100"
    run_update "1.0.1-beta" "101" "beta"
    run_update "1.0.2-beta" "103" "beta"

    assert_item_count 2 && \
    assert_contains_version "1.0.0" && \
    assert_not_contains_version "1.0.1-beta" && \
    assert_contains_version "1.0.2-beta" && \
    assert_no_channel "1.0.0" && \
    assert_has_beta_channel "1.0.2-beta"
}

test_new_stable_replaces_old_stable_keeps_beta() {
    run_update "1.0.0" "100"
    run_update "1.0.1-beta" "101" "beta"
    run_update "1.0.1" "102"

    assert_item_count 2 && \
    assert_not_contains_version "1.0.0" && \
    assert_contains_version "1.0.1" && \
    assert_contains_version "1.0.1-beta" && \
    assert_no_channel "1.0.1" && \
    assert_has_beta_channel "1.0.1-beta"
}

test_scenario_full_release_cycle() {
    # Simulate: 1.0.0 → 1.0.1-beta.1 → 1.0.1-beta.2 → 1.0.1
    run_update "1.0.0" "100"

    # After stable 1.0.0
    assert_item_count 1 && assert_contains_version "1.0.0" || return 1

    run_update "1.0.1-beta.1" "101" "beta"

    # After beta.1: should have stable + beta
    assert_item_count 2 && \
    assert_contains_version "1.0.0" && \
    assert_contains_version "1.0.1-beta.1" || return 1

    run_update "1.0.1-beta.2" "102" "beta"

    # After beta.2: stable + new beta (old beta replaced)
    assert_item_count 2 && \
    assert_contains_version "1.0.0" && \
    assert_not_contains_version "1.0.1-beta.1" && \
    assert_contains_version "1.0.1-beta.2" || return 1

    run_update "1.0.1" "103"

    # After stable 1.0.1: new stable + beta (old stable replaced)
    assert_item_count 2 && \
    assert_not_contains_version "1.0.0" && \
    assert_contains_version "1.0.1" && \
    assert_contains_version "1.0.1-beta.2"
}

test_multiple_stable_only_releases() {
    run_update "1.0.0" "100"
    run_update "1.0.1" "101"
    run_update "1.0.2" "102"

    # Should only have latest stable
    assert_item_count 1 && \
    assert_not_contains_version "1.0.0" && \
    assert_not_contains_version "1.0.1" && \
    assert_contains_version "1.0.2"
}

test_multiple_beta_only_releases() {
    run_update "1.0.0-beta.1" "100" "beta"
    run_update "1.0.0-beta.2" "101" "beta"
    run_update "1.0.0-beta.3" "102" "beta"

    # Should only have latest beta
    assert_item_count 1 && \
    assert_not_contains_version "1.0.0-beta.1" && \
    assert_not_contains_version "1.0.0-beta.2" && \
    assert_contains_version "1.0.0-beta.3"
}

test_fresh_start_no_existing_appcast() {
    # Ensure no appcast exists
    clear_appcast

    run_update "2.0.0" "200"

    assert_item_count 1 && \
    assert_contains_version "2.0.0"
}

# =============================================================================
# VERSION UPDATE SCENARIOS FROM DOCUMENTATION
# =============================================================================

# Scenario 1: User on 1.0.0, only 1.0.0 available -> No update
# (This is a client-side behavior, but we verify appcast structure)
test_doc_scenario_1_stable_only() {
    run_update "1.0.0" "100"

    assert_item_count 1 && \
    assert_contains_version "1.0.0" && \
    assert_no_channel "1.0.0"
}

# Scenario 2 & 3: Appcast has 1.0.1-beta + 1.0.0
test_doc_scenario_2_3_beta_plus_stable() {
    run_update "1.0.0" "100"
    run_update "1.0.1-beta" "101" "beta"

    # Beta users (ON): see both, get 1.0.1-beta
    # Stable users (OFF): see only 1.0.0, no update
    assert_item_count 2 && \
    assert_contains_version "1.0.0" && \
    assert_contains_version "1.0.1-beta" && \
    assert_no_channel "1.0.0" && \
    assert_has_beta_channel "1.0.1-beta"
}

# Scenario 4: User on 1.0.1-beta, 1.0.1 stable released
test_doc_scenario_4_stable_after_beta_same_version() {
    run_update "1.0.0" "100"
    run_update "1.0.1-beta" "101" "beta"
    run_update "1.0.1" "102"

    # All users get 1.0.1 (higher build number)
    assert_item_count 2 && \
    assert_contains_version "1.0.1" && \
    assert_contains_version "1.0.1-beta" && \
    assert_no_channel "1.0.1"
}

# Scenario 5 & 6: Appcast has 1.0.2-beta + 1.0.1
test_doc_scenario_5_6_newer_beta_plus_stable() {
    run_update "1.0.1" "102"
    run_update "1.0.2-beta" "103" "beta"

    # Beta users (ON): get 1.0.2-beta
    # Stable users (OFF): stay on 1.0.1
    assert_item_count 2 && \
    assert_contains_version "1.0.1" && \
    assert_contains_version "1.0.2-beta" && \
    assert_no_channel "1.0.1" && \
    assert_has_beta_channel "1.0.2-beta"
}

# Scenario 7 & 8: User on 1.0.0, appcast has 1.0.2-beta + 1.0.1
test_doc_scenario_7_8_user_behind_both_versions() {
    run_update "1.0.0" "100"
    run_update "1.0.1" "102"
    run_update "1.0.2-beta" "103" "beta"

    # Stable users (OFF): get 1.0.1 (beta filtered out)
    # Beta users (ON): get 1.0.2-beta (newest)
    assert_item_count 2 && \
    assert_contains_version "1.0.1" && \
    assert_contains_version "1.0.2-beta" && \
    assert_no_channel "1.0.1" && \
    assert_has_beta_channel "1.0.2-beta"
}

# =============================================================================
# BUILD NUMBER VALIDATION TESTS
# =============================================================================

test_warn_if_new_build_lower_than_existing() {
    # This test verifies the script handles the case where a new release
    # has a LOWER build number than existing entries
    # This can happen if test data with high build numbers is committed

    run_update "1.0.0" "100"  # Stable with high build number
    run_update "1.0.1-beta" "50" "beta"  # Beta with LOWER build number

    # Both should still be in appcast (script doesn't reject, just warns)
    # But this is a configuration error that should be avoided
    assert_item_count 2 && \
    assert_contains_version "1.0.0" && \
    assert_contains_version "1.0.1-beta"
}

test_build_numbers_must_increase_for_same_channel() {
    # Verify newer versions replace older ones even with build numbers
    run_update "1.0.0" "100"
    run_update "1.0.1" "101"

    # 1.0.1 should replace 1.0.0
    assert_item_count 1 && \
    assert_not_contains_version "1.0.0" && \
    assert_contains_version "1.0.1"
}

# =============================================================================
# MAIN
# =============================================================================

main() {
    echo ""
    echo "========================================"
    echo "  update-appcast.sh Unit Tests"
    echo "========================================"
    echo ""

    setup
    trap teardown EXIT

    echo "Basic Functionality:"
    echo "--------------------"
    run_test "Stable release creates single item without channel" test_stable_release_creates_single_item
    run_test "Beta release creates single item with channel tag" test_beta_release_creates_single_item_with_channel
    run_test "Beta after stable keeps both versions" test_beta_after_stable_keeps_both
    run_test "Stable after beta keeps both versions" test_stable_after_beta_keeps_both

    echo ""
    echo "Version Replacement:"
    echo "--------------------"
    run_test "New beta replaces old beta, keeps stable" test_new_beta_replaces_old_beta_keeps_stable
    run_test "New stable replaces old stable, keeps beta" test_new_stable_replaces_old_stable_keeps_beta
    run_test "Multiple stable releases keep only latest" test_multiple_stable_only_releases
    run_test "Multiple beta releases keep only latest" test_multiple_beta_only_releases

    echo ""
    echo "Edge Cases:"
    echo "-----------"
    run_test "Fresh start with no existing appcast" test_fresh_start_no_existing_appcast
    run_test "Full release cycle (stable → betas → stable)" test_scenario_full_release_cycle

    echo ""
    echo "Documentation Scenarios:"
    echo "------------------------"
    run_test "Scenario 1: Stable only appcast" test_doc_scenario_1_stable_only
    run_test "Scenario 2-3: Beta + stable (1.0.1-beta + 1.0.0)" test_doc_scenario_2_3_beta_plus_stable
    run_test "Scenario 4: Stable after beta same version" test_doc_scenario_4_stable_after_beta_same_version
    run_test "Scenario 5-6: Newer beta + stable (1.0.2-beta + 1.0.1)" test_doc_scenario_5_6_newer_beta_plus_stable
    run_test "Scenario 7-8: User behind both versions" test_doc_scenario_7_8_user_behind_both_versions

    echo ""
    echo "Build Number Validation:"
    echo "------------------------"
    run_test "Script accepts lower build number (warns but continues)" test_warn_if_new_build_lower_than_existing
    run_test "Build numbers increase for same channel" test_build_numbers_must_increase_for_same_channel

    echo ""
    echo "========================================"
    echo -e "  Results: ${GREEN}$TESTS_PASSED passed${NC}, ${RED}$TESTS_FAILED failed${NC} (of $TESTS_RUN)"
    echo "========================================"
    echo ""

    if [[ $TESTS_FAILED -gt 0 ]]; then
        exit 1
    fi
}

main "$@"
