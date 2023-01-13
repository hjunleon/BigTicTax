// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.6;
library my_math {
    function max(uint256 a, uint256 b) external pure returns (uint256) {
        return a >= b ? a : b;
    }
    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a <= b ? a : b;
    }

    function max(uint256[] memory numbers) external pure returns (uint256) {
        require(numbers.length > 0); // throw an exception if the condition is not met
        uint256 maxNumber; // default 0, the lowest value of `uint256`

        for (uint256 i = 0; i < numbers.length; i++) {
            if (numbers[i] > maxNumber) {
                maxNumber = numbers[i];
            }
        }

        return maxNumber;
    }

}