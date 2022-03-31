// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

contract Blood is ERC20, Ownable, Pausable {
    address public admin;

    // a mapping from an address to whether or not it can mint / burn
    mapping(address => bool) controllers;

    uint256 public burnCount;

    constructor() ERC20("Blood Token", "BLOOD") {
        _mint(msg.sender, 1000000 * 10**decimals());
    }

    /**
     * mints $BLOOD to a recipient
     * @param to the recipient of the $BLOOD
     * @param amount the amount of $BLOOD to mint
     */
    function mint(address to, uint256 amount) external {
        require(controllers[msg.sender], "Only controllers can mint");
        _mint(to, amount);
    }

    /**
     * burns $BLOOD from a holder
     * @param from the holder of the $BLOOD
     * @param amount the amount of $BLOOD to burn
     */
    function burn(address from, uint256 amount) external {
        require(controllers[msg.sender], "Only controllers can burn");
        burnCount += amount;
        _burn(from, amount);
    }

    /**
     * enables an address to mint / burn
     * @param controller the address to enable
     */
    function addController(address controller) external onlyOwner {
        controllers[controller] = true;
    }

    /**
     * disables an address from minting / burning
     * @param controller the address to disbale
     */
    function removeController(address controller) external onlyOwner {
        controllers[controller] = false;
    }
}
