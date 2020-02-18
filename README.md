# ETC Odyssey smart contract audit

Built with [Saturn Dapp Dev Kit](https://www.saturn.network/blog/ethereum-dapp-development-kit/)!

![coverage report](https://forum.saturn.network/uploads/default/optimized/2X/d/d2396f975d189e51c5b5181408a414fbd4abd6df_2_1306x1000.png)

## Note

The auditor was provided the source code without explanation of how it is being used. The use cases for this smart contract, and the potential pitfalls (aka what exactly are we testing for?) were determined solely at auditor's discretion based on information provided on https://etcodyssey.com/ and by getting some experience playing the game in a testnet.

## Methodology

1. The contract in contracts/EtcOdysseyOriginal.sol was modified to support testing. As it was written originally, certain constants (like address of [ONEX token](https://www.saturn.network/exchange/ETC/order-book/onex)) were *hard-coded*, meaning it was impossible to write tests for.
2. Once modified, and once `ONEX.sol` was pulled from blockscout and added into the `contracts` folder, `migrations` were written.
3. The auditor read the source, each method inside it, and started writing `test/test-game.js`.
5. The auditor added some helpful additional methods to the smart contract and refactored it to make it more readable. This way, he is showing respect to all future readers of the source code - they get a high quality product in return and don't need to waste any additional time, they can read the code and understand it in full.
6. Test suite coverage was measured as well, ensuring that we have executed every line at least once in our test suite, and that we thought of as many edge cases as we possibly could.

Ultimately, the game was tested with the test suite of the following quality:

* **97.24%** statement coverage
* **73.75%** branch coverage
* **100%** function coverage
* **97.3%** line coverage

Uncovered lines and branches can be examined visually by running the reproduce step of this document, or by viewing `coverage/index.html` in your web browser.

While there is no guarantee that an audited contract has zero bugs, the auditor believes this game to be safe to use and not have any exploitable holes. The final result is an improved, safer codebase. Only small bugs were discovered during the audit with no fund-threatening vulnerabilities.

The recommended-to-be-used smart contract can be found in `contracts/EtcOdyssey.sol`.

## To reproduce

1. Ensure you have node.js, git and yarn installed.
3. Download this repository, open the folder in terminal and run

```sh
yarn

yarn compile

yarn migrate

yarn coverage
```

You can then visually expect test coverage by viewing `coverage/index.html` in your web browser.

Due to a certain degree of randomness

## To deploy final contract on ETC mainnet

First, do the `reproduce` step. Then,

```sh
yarn sol-compiler
node index.js
```

This will prompt you to enter a private key or a 12-word-mnemonic that will be used to deploy the game and become its admin.

## Changelog

1. Added views to support querying for the dashboard and tests. See `test/utils.js`.
2. Added new events to support building an API for leaderboards and game stats.
3. Added `nonReentrant` modifier to game functions for protection against reentrancy bugs.
4. Added constructor to facilitate testing and deployment of the game on other chains.
5. Removed `payable` modifier from ship upgrade and raid functions, since those are upgraded with Dark Matter, not with ether.
6. Upgrading ships with StarDust seems to be redundant and is very rarely triggered. Removed those not-that-useful and hard-to-test lines to reduce attack surface.
7. Fixed a bug with incorrect shield calculations inside a losing raid.
8. Removed unused functions.
9. Modified `repairShipUnit` function to refund ether that was not spent on ship repairs.
10. Fixed `onexamount` bug - it was not reflecting actual ONEX balance of the game's smart contract.
11. Fixed a bug in `withdrawShare` that didn't check for cooldown on withdrawals.

# Recommendations

1. Do not use *exotic* ether denominations in your code, such as `szabo` and `finney`. IMO it's an anti feature, as it requires unnecessary memorization and confusion. Off the top of your head, can you answer which is larger: 10 szabo or 1000 finney? I recommend only using `ether` and `wei`.
2. Be logical when structuring your code. Try this structure: `using Safemath` comes first, then private constants, followed by public constants, followed by events, followed by constructor, followed by public methods, followed by admin_only methods, followed by private methods. It makes your code much more readable.
3. If your contract accepts ERC223 tokens, mark it with `contract Foo is ContractReceiver`.
4. Is top up by any address intentional, provided that admin can withdraw all of the ONEX balance? Perhaps `adminWithdrawONEX` should not exist in production version of the game. Instead, the admin can provide ONEX bounties in small increments, like running promotions, and once the ONEX is in the game the only way to claim it is to earn it! This design choice decentralizes the power balance better.
5. Upgrading ships with StarDust seems to be redundant and is very rarely triggered. Consider specializing your resources. DM for ship upgrades, SD for fusing into ETC and ONEX.
6. Sometimes `startRaid` fails to run due to all of the randomization - namely wallet's gas estimation fails. I suggest you fix the `gasLimit` in your UI at 500,000. Worst case unused gas will be refunded.
