// SPDX-License-Identifier: MIT

// ERC20 token migration from old AntiMEV contract to new XMEV contract

pragma solidity ^0.8.20;

/* import "./AntiMEV.sol";
import "./XMEV.sol";

contract Migration {
  AntiMEV public antiMEV;
  XMEV public xMEV;
  address public owner;
  uint256 public migrationStartTime;
  uint256 public migrationEndTime;
  uint256 public migrationRate;
  uint256 public totalMigrated;

  event Migrate(address indexed user, uint256 amount);

  constructor(
    AntiMEV _antiMEV,
    XMEV _xMEV,
    uint256 _migrationStartTime,
    uint256 _migrationEndTime
  ) {
    antiMEV = _antiMEV;
    xMEV = _xMEV;
    migrationStartTime = _migrationStartTime;
    migrationEndTime = _migrationEndTime;
    owner = msg.sender;
  }

  function migrate(uint256 amount) external {
    require(
      block.timestamp >= migrationStartTime,
      "Migration: migration not started"
    );
    require(block.timestamp <= migrationEndTime, "Migration: migration ended");
    require(amount > 0, "Migration: amount must be greater than 0");
    require(
      antiMEV.balanceOf(msg.sender) >= amount,
      "Migration: insufficient balance"
    );
    require(
      antiMEV.allowance(msg.sender, address(this)) >= amount,
      "Migration: insufficient allowance"
    );

    antiMEV.transferFrom(msg.sender, address(this), amount);
    xMEV.mint(msg.sender, amount);
    totalMigrated += amount;

    emit Migrate(msg.sender, amount);
  }

  function withdrawAntiMEV(uint256 amount) external {
    require(msg.sender == owner, "Migration: only owner");
    require(
      block.timestamp > migrationEndTime,
      "Migration: migration not ended"
    );
    require(
      antiMEV.balanceOf(address(this)) >= amount,
      "Migration: insufficient balance"
    );

    antiMEV.transfer(msg.sender, amount);
  }

  function withdrawXMEV(uint256 amount) external {
    require(msg.sender == owner, "Migration: only owner");
    require(
      block.timestamp > migrationEndTime,
      "Migration: migration not ended"
    );
    require(
      xMEV.balanceOf(address(this)) >= amount,
      "Migration: insufficient balance"
    );

    xMEV.transfer(msg.sender, amount);
  }
}
 */