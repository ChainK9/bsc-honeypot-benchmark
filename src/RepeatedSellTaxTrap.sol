// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "./FixtureERC20.sol";

/// @notice TEST FIXTURE: deployed only on local forks.
contract RepeatedSellTaxTrap is FixtureERC20 {

mapping(address=>uint256) public sells;
constructor() FixtureERC20("Repeated sell tax", "ESCALATE") {}
function _update(address from,address to,uint256 amount) internal override {
 if(to==pair && sells[from]++>0){
  uint256 fee=amount*60/100;
  super._update(from,address(0),fee);amount-=fee;
 }
 super._update(from,to,amount);
}

}
