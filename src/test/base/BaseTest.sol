// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import { DSTest } from "../../../lib/ds-test/src/test.sol";

import { VM } from "../utils/VM.sol";
import { console } from "../utils/console.sol";

contract BaseTest is DSTest {
  VM internal constant vm = VM(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
}
