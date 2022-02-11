// SPDX-License-Identifier: MIT

pragma solidity 0.7.6;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

///	@title	Balast token contract
contract BalastERC20 is ERC20 {

	constructor(uint256 initialSupply) ERC20("Ballast Finance", "BALFI") {
		_mint(msg.sender, initialSupply);
	}

}
