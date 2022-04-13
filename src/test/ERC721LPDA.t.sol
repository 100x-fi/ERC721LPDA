// SPDX-License-Identifier: MIT
// ▄█ █▀█ █▀█ ▀▄▀
// ░█ █▄█ █▄█ █░█

pragma solidity 0.8.13;

import { BaseTest, console } from "./base/BaseTest.sol";

import { ERC721LPDA } from "../ERC721LPDA.sol";

contract ERC721LPDA_Test is BaseTest {
  address private constant TESTER1 = address(0x168);
  address private constant TESTER2 = address(0x88);
  address private constant TESTER3 = address(0x69);
  address private constant TREASURY = address(0x619);

  ERC721LPDA private erc721lpda;

  uint256 private constant maxSupply = 10000;

  uint256 private startBlock;
  uint256 private endBlock;

  uint256 private constant startPrice = 88 ether;
  uint256 private constant floorPrice = 8 ether;

  function setUp() public {
    startBlock = block.number + 100;
    endBlock = block.number + 200;

    erc721lpda = new ERC721LPDA(
      "ERC721LPDA",
      "LPDA",
      maxSupply,
      startBlock,
      endBlock,
      startPrice,
      floorPrice
    );
  }

  function testRevert_bid() public {
    // bid before auction start
    vm.expectRevert(abi.encodeWithSignature("ERC721LPDA_OutOfWindow()"));
    erc721lpda.bid(1);

    // bid with incorrect funds
    vm.roll(startBlock);
    vm.expectRevert(abi.encodeWithSignature("ERC721LPDA_BadArguments()"));
    erc721lpda.bid(1);

    // bid more than maxSupply
    vm.expectRevert(abi.encodeWithSignature("ERC721LPDA_BadArguments()"));
    erc721lpda.bid{ value: startPrice * (maxSupply + 1) }(maxSupply + 1);

    // bid after auction end
    vm.roll(endBlock + 1);
    vm.expectRevert(abi.encodeWithSignature("ERC721LPDA_OutOfWindow()"));
    erc721lpda.bid(1);
  }

  function testCorrectness_bid() external {
    // give some ethers to the contract
    vm.deal(address(this), 88888 ether);

    // set block to startBlock
    vm.roll(startBlock);

    // bid with correct funds
    uint256 _price = erc721lpda.price();
    erc721lpda.bid{ value: 300 ether }(3);

    (uint256 _paid, uint256 _totalMint, uint256 _isRefunded) = erc721lpda
      .dutchAuctionMinters(address(this));

    assertEq(erc721lpda.balanceOf(address(this)), 3);
    assertEq(address(this).balance, 88888 ether - (_price * 3));
    assertEq(erc721lpda.dutchAuctionTotalPaid(), _price * 3);
    assertEq(erc721lpda.dutchAuctionTotalSold(), 3);
    assertEq(_paid, _price * 3);
    assertEq(_totalMint, 3);
    assertEq(_isRefunded, 0);
  }

  function testCorrectness_refundWhenSomeoneBidAtFloor() external {
    // give some ethers to TESTERs
    vm.deal(TESTER1, 88888 ether);
    vm.deal(TESTER2, 88888 ether);
    vm.deal(TESTER3, 88888 ether);

    // TESTER1 bid at startBlock
    vm.roll(startBlock);
    vm.prank(TESTER1);
    erc721lpda.bid{ value: 100 ether }(1);

    // TESTER2 bid at startBlock + 50
    vm.roll(startBlock + 50);
    vm.prank(TESTER2);
    erc721lpda.bid{ value: 100 ether }(1);

    // TESTER3 bid at endBlock
    vm.roll(endBlock);
    vm.prank(TESTER3);
    erc721lpda.bid{ value: 100 ether }(1);

    vm.stopPrank();

    // TESTER1 and TESTER2 try to refund at endBlock
    assertEq(erc721lpda.refund(TESTER1), 0);
    assertEq(erc721lpda.refund(TESTER2), 0);

    // roll to endBlock + 1
    vm.roll(endBlock + 1);

    // TESTER1 and TESTER2 should be refunded
    // TESTER3 paid at last price, hence no refund
    assertEq(erc721lpda.refund(TESTER1), 88 ether - 8 ether);
    assertEq(erc721lpda.refund(TESTER2), 48 ether - 8 ether);
    assertEq(erc721lpda.refund(TESTER3), 0);

    // try refund again
    assertEq(erc721lpda.refund(TESTER1), 0);
    assertEq(erc721lpda.refund(TESTER2), 0);
    assertEq(erc721lpda.refund(TESTER3), 0);
  }

  function testCorrectness_refundManyWhenSomeoneBidAtFloor() external {
    // give some ethers to TESTERs
    vm.deal(TESTER1, 88888 ether);
    vm.deal(TESTER2, 88888 ether);
    vm.deal(TESTER3, 88888 ether);

    // TESTER1 bid at startBlock
    vm.roll(startBlock);
    vm.prank(TESTER1);
    erc721lpda.bid{ value: 100 ether }(1);

    // TESTER2 bid at startBlock + 50
    vm.roll(startBlock + 50);
    vm.prank(TESTER2);
    erc721lpda.bid{ value: 100 ether }(1);

    // TESTER3 bid at endBlock
    vm.roll(endBlock);
    vm.prank(TESTER3);
    erc721lpda.bid{ value: 100 ether }(1);

    vm.stopPrank();

    // TESTER1 and TESTER2 try to refund at endBlock
    assertEq(erc721lpda.refund(TESTER1), 0);
    assertEq(erc721lpda.refund(TESTER2), 0);

    // roll to endBlock + 1
    vm.roll(endBlock + 1);

    // TESTER1 and TESTER2 should be refunded
    // TESTER3 paid at last price, hence no refund
    address[] memory _testers = new address[](3);
    _testers[0] = TESTER1;
    _testers[1] = TESTER2;
    _testers[2] = TESTER3;

    erc721lpda.refundMany(_testers);

    // try refund again
    assertEq(erc721lpda.refund(TESTER1), 0);
    assertEq(erc721lpda.refund(TESTER2), 0);
    assertEq(erc721lpda.refund(TESTER3), 0);
  }

  function testCorrectness_refundWhenNooneBidAtFloor() external {
    // give some ethers to TESTERs
    vm.deal(TESTER1, 88888 ether);
    vm.deal(TESTER2, 88888 ether);
    vm.deal(TESTER3, 88888 ether);

    // TESTER1 bid at startBlock
    vm.roll(startBlock);
    vm.prank(TESTER1);
    erc721lpda.bid{ value: 100 ether }(1);

    // TESTER2 bid at startBlock + 50
    vm.roll(startBlock + 50);
    vm.prank(TESTER2);
    erc721lpda.bid{ value: 100 ether }(1);

    vm.stopPrank();

    // roll to endBlock + 1
    vm.roll(endBlock + 1);

    // TESTER1 and TESTER2 should be refunded at floor price
    // as it is not sold out
    assertEq(erc721lpda.refund(TESTER1), 88 ether - 8 ether);
    assertEq(erc721lpda.refund(TESTER2), 48 ether - 8 ether);

    // try refund again
    assertEq(erc721lpda.refund(TESTER1), 0);
    assertEq(erc721lpda.refund(TESTER2), 0);
  }

  function testCorrectness_withdrawETH() external {
    // give some ethers to TESTERs
    vm.deal(TESTER1, 88888 ether);
    vm.deal(TESTER2, 88888 ether);
    vm.deal(TESTER3, 88888 ether);

    // TESTER1 bid at startBlock
    vm.roll(startBlock);
    vm.prank(TESTER1);
    erc721lpda.bid{ value: 100 ether }(1);

    // TESTER2 bid at startBlock + 50
    vm.roll(startBlock + 50);
    vm.prank(TESTER2);
    erc721lpda.bid{ value: 100 ether }(1);

    // TESTER3 bid at endBlock
    vm.roll(endBlock);
    vm.prank(TESTER3);
    erc721lpda.bid{ value: 100 ether }(1);

    vm.stopPrank();

    // roll to endBlock + 1
    vm.roll(endBlock + 1);

    // withdraw ETH
    erc721lpda.withdrawETH(TREASURY);
    assertEq(TREASURY.balance, 8 ether * 3);

    // TESTER1 and TESTER2 should be refunded
    // TESTER3 paid at last price, hence no refund
    address[] memory _testers = new address[](3);
    _testers[0] = TESTER1;
    _testers[1] = TESTER2;
    _testers[2] = TESTER3;

    erc721lpda.refundMany(_testers);

    assertEq(address(erc721lpda).balance, 0);

    vm.expectRevert(abi.encodeWithSignature("ERC721LPDA_WithdrawNotAllow()"));
    erc721lpda.withdrawETH(address(this));
  }

  /// @notice Fallback function to receive ETH
  receive() external payable {}
}
