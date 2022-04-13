// SPDX-License-Identifier: MIT
// ▄█ █▀█ █▀█ ▀▄▀
// ░█ █▄█ █▄█ █░█

pragma solidity 0.8.13;

import { Ownable } from "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import { ReentrancyGuard } from "../lib/openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";
import { ERC721A } from "../lib/ERC721A/contracts/ERC721A.sol";

contract ERC721LPDA is Ownable, ReentrancyGuard, ERC721A {
  // --- errors ---
  error ERC721LPDA_BadArguments();
  error ERC721LPDA_OutOfWindow();
  error ERC721LPDA_UnableToSendETH();
  error ERC721LPDA_WithdrawNotAllow();

  // --- general NFT drop states ---
  uint256 public maxSupply;

  // --- dutch auction states ---
  uint256 public startBlock;
  uint256 public endBlock;
  uint256 internal __rate;

  uint256 public startPrice;
  uint256 public floorPrice;

  uint256 public dutchAuctionTotalSold;
  uint256 public dutchAuctionTotalPaid;
  uint256 public dutchAuctionClearingAmount;
  uint256 public lastPrice;
  struct Minter {
    uint256 paid;
    uint256 totalMint;
    uint256 isRefunded;
  }
  mapping(address => Minter) public dutchAuctionMinters;

  constructor(
    string memory _name,
    string memory _symbol,
    uint256 _maxSupply,
    uint256 _startBlock,
    uint256 _endblock,
    uint256 _startPrice,
    uint256 _floorPrice
  ) ERC721A(_name, _symbol) {
    if (_endblock < _startBlock || _floorPrice > _startPrice)
      revert ERC721LPDA_BadArguments();

    maxSupply = _maxSupply;
    startBlock = _startBlock;
    endBlock = _endblock;
    startPrice = _startPrice;
    floorPrice = _floorPrice;

    unchecked {
      __rate = (startPrice - floorPrice) / (endBlock - startBlock);
    }
  }

  function price() public view returns (uint256) {
    if (block.number < startBlock) return startPrice;
    if (block.number > endBlock) return floorPrice;

    return startPrice - (__rate * (block.number - startBlock));
  }

  function bid(uint256 _amount) external payable nonReentrant {
    // Check
    if (block.number < startBlock || block.number > endBlock)
      revert ERC721LPDA_OutOfWindow();

    uint256 _cost = _amount * price();
    if (msg.value < _cost || totalSupply() + _amount > maxSupply)
      revert ERC721LPDA_BadArguments();

    // SLOAD
    Minter storage _minter = dutchAuctionMinters[msg.sender];
    // Apply effect to global states
    dutchAuctionTotalPaid += _cost;
    dutchAuctionTotalSold += _amount;
    lastPrice = price();

    // Apply effect to user states
    _minter.paid += _cost;
    _minter.totalMint += _amount;

    _mint(msg.sender, _amount, "", false);

    // Interact
    // Refund
    uint256 _back = msg.value - _cost;
    if (_back > 0) {
      (bool sent, ) = msg.sender.call{ value: _back }("");
      if (!sent) revert ERC721LPDA_UnableToSendETH();
    }
  }

  /// @notice Refund to a user if dutch auction end up lower than what he paid
  /// @param _user The user to be refunded
  function _refund(address _user) internal returns (uint256) {
    // SLOAD
    Minter storage _minter = dutchAuctionMinters[_user];

    // Check
    // If not sold out
    if (totalSupply() != maxSupply) {
      // If not end, then no refund yet
      if (block.number <= endBlock) return 0;
      // If ended and not sold out, then lastPrice is the floor price
      lastPrice = floorPrice;
    }

    if (_minter.isRefunded == 1) return 0;

    // Effect
    _minter.isRefunded = 1;

    // Interact
    uint256 _back = _minter.paid - (_minter.totalMint * lastPrice);
    if (_back > 0) {
      (bool sent, ) = _user.call{ value: _back }("");
      if (!sent) revert ERC721LPDA_UnableToSendETH();
    }

    return _back;
  }

  function refund(address _user) external nonReentrant returns (uint256) {
    return _refund(_user);
  }

  /// @notice Batch refund to a users
  /// @param _users The users to be refunded
  function refundMany(address[] calldata _users) external nonReentrant {
    for (uint256 i = 0; i < _users.length; ) {
      if (_users[i] == address(0)) continue;
      _refund(_users[i]);
      unchecked {
        ++i;
      }
    }
  }

  /// @notice Realized revenue and send to "_to"
  /// @param _to The address to recevied revenue
  function withdrawETH(address _to) external onlyOwner {
    // Check
    if (block.number < endBlock || dutchAuctionClearingAmount != 0)
      revert ERC721LPDA_WithdrawNotAllow();

    // Effect
    dutchAuctionClearingAmount = dutchAuctionTotalSold * lastPrice;

    (bool sent, ) = _to.call{ value: dutchAuctionClearingAmount }("");
    if (!sent) revert ERC721LPDA_UnableToSendETH();
  }
}
