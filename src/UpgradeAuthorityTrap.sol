// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "./FixtureERC20.sol";
import "./FixtureOwnable.sol";
/// @notice TEST FIXTURE: deployed only on local forks.
contract UpgradeAuthorityTrap is FixtureERC20, FixtureOwnable {

constructor() FixtureERC20("Beacon upgrade authority", "UPGRADE") {
 address implementation=address(new UpgradeAuthorityLogic());
 address beacon=address(new UpgradeAuthorityBeacon(msg.sender,implementation));
 bytes32 slot=bytes32(uint256(keccak256("eip1967.proxy.beacon"))-1);
 assembly{sstore(slot,beacon)}
 bytes memory runtime=type(UpgradeAuthorityRuntime).runtimeCode;
 assembly{return(add(runtime,32),mload(runtime))}
}
function _update(address from,address to,uint256 amount) internal override {super._update(from,to,amount);}

}

/// @notice TEST FIXTURE: minimal beacon and UUPS logic for local forks.
contract UpgradeAuthorityBeacon {
 address public owner;address public implementation;
 constructor(address owner_,address impl_){owner=owner_;implementation=impl_;}
 function upgradeTo(address impl_) external {require(msg.sender==owner,"not owner");implementation=impl_;}
}
contract UpgradeAuthorityLogic is FixtureERC20, FixtureOwnable {
 constructor() FixtureERC20("Upgrade logic", "IMPL") {}
 function proxiableUUID() external pure returns(bytes32){return bytes32(uint256(keccak256("eip1967.proxy.implementation"))-1);}
 function upgradeTo(address impl_) external onlyOwner {
  bytes32 slot=bytes32(uint256(keccak256("eip1967.proxy.implementation"))-1);
  assembly{sstore(slot,impl_)}
 }
 function _update(address from,address to,uint256 amount) internal override {super._update(from,to,amount);}
}
contract UpgradeAuthorityRuntime {
 // Explicit ERC-20 dispatch lets the existing classifier recognize a beacon token.
 function balanceOf(address) external returns(uint256){_delegate();}
 function totalSupply() external returns(uint256){_delegate();}
 function transfer(address,uint256) external returns(bool){_delegate();}
 function approve(address,uint256) external returns(bool){_delegate();}
 function useUUPS() external {
  bytes32 beaconSlot=bytes32(uint256(keccak256("eip1967.proxy.beacon"))-1);
  bytes32 implSlot=bytes32(uint256(keccak256("eip1967.proxy.implementation"))-1);
  address beacon;assembly{beacon:=sload(beaconSlot)}
  require(msg.sender==UpgradeAuthorityBeacon(beacon).owner(),"not owner");
  address implementation=UpgradeAuthorityBeacon(beacon).implementation();
  assembly{sstore(implSlot,implementation) sstore(beaconSlot,0)}
 }
 fallback() external payable{_delegate();}
 function _delegate() internal {
  bytes32 implSlot=bytes32(uint256(keccak256("eip1967.proxy.implementation"))-1);
  bytes32 beaconSlot=bytes32(uint256(keccak256("eip1967.proxy.beacon"))-1);
  address impl;address beacon;assembly{impl:=sload(implSlot) beacon:=sload(beaconSlot)}
  if(impl==address(0)) impl=UpgradeAuthorityBeacon(beacon).implementation();
  assembly{
   calldatacopy(0,0,calldatasize())
   let ok:=delegatecall(gas(),impl,0,calldatasize(),0,0)
   returndatacopy(0,0,returndatasize())
   switch ok case 0 {revert(0,returndatasize())} default{return(0,returndatasize())}
  }
 }
}
