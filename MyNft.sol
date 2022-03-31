// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "./Blood.sol";
import "./ICastle.sol";
import "hardhat/console.sol";

contract MyNFT is ERC721Enumerable, Ownable {
    using Strings for uint256;

    uint256 randNonce = 0;

    string public baseHumanURI;
    string public baseVampireURI;
    string public baseWolfURI;
    string public baseExtension = ".png";
    string public notRevealedUri;

    uint256 public cost = 0.01 ether;
    uint256 public WLcost = 0.01 ether;

    uint256 public bloodPrice = 10000;
    uint256 public maxSupply = 50000;
    uint256 public genZeroSupply = 10000;
    uint256 public maxMintAmount = 20000;
    uint256 public nftPerAddressLimit = 10000;

    Blood public blood;

    bool mintWithBlood = false;

    address public castle;
    address public teamWallet;

    bool public paused = false;
    bool public revealed = false;
    bool public onlyWhitelisted = false;
    mapping(address => bool) public whitelistedAddresses;

    event randomData(uint256 i);

    mapping(address => uint256) public addressMintedBalance;

    uint256 public totalHuman = 0;
    uint256 public totalVampire = 0;
    uint256 public totalWolf = 0;
    uint256 public minted;

    mapping(uint256 => uint256) public tokenType; //1human 2vampire 3wolf
    mapping(uint256 => uint256) public tokenNumByRace; //Num for seek URI number by ID

    constructor() ERC721("Strange Creatures", "STC") {}

    function random(uint256 _modulus) internal returns (uint256) {
        // increase nonce
        randNonce++;
        return
            uint256(
                keccak256(
                    abi.encodePacked(block.timestamp, msg.sender, randNonce)
                )
            ) % _modulus;
    }

    // public
    function mint(uint256 _mintAmount) public payable {
        require(!paused, "the contract is paused");
        uint256 supply = totalSupply();
        uint256 totalCost = 0;
        require(_mintAmount > 0, "need to mint at least 1 NFT");
        require(
            _mintAmount <= maxMintAmount,
            "max mint amount per session exceeded"
        );
        require(supply + _mintAmount <= maxSupply, "max NFT limit exceeded");

        if (onlyWhitelisted == true) {
            require(isWhitelisted(msg.sender), "user is not whitelisted");
            require(msg.value >= WLcost * _mintAmount, "insufficient funds");
            whitelistedAddresses[msg.sender] = false;
        } else {
            if (supply + _mintAmount <= genZeroSupply) {
                require(msg.value >= cost * _mintAmount, "insufficient funds");
            } else {
                for (uint256 i = 1; i <= _mintAmount; i++) {
                    totalCost += calculateBloodCost(i);
                }
                blood.transferFrom(msg.sender, address(this), totalCost);
            }
        }

        for (uint256 i = 1; i <= _mintAmount; i++) {
            uint256 nftType = random(101);
            address rowner = address(msg.sender);
            uint256 isSteal = random(11);
            console.log("steal = ", isSteal);
            if (supply + i > genZeroSupply) {
                if (isSteal == 1) {
                    rowner = ICastle(castle).randomCreatureOwner();
                } else {
                    rowner = address(msg.sender);
                }
                if (rowner == address(0x0)) rowner = address(msg.sender);
            }
            if (nftType > 99) {
                tokenType[supply + i] = 3;
                totalWolf += 1;
                tokenNumByRace[supply + 1] = totalWolf;
            }
            if (nftType <= 99 && nftType >= 90) {
                tokenType[supply + i] = 2;
                totalVampire += 1;
                tokenNumByRace[supply + 1] = totalVampire;
            } else {
                tokenType[supply + i] = 1;
                totalHuman += 1;
                tokenNumByRace[supply + 1] = totalHuman;
            }
            addressMintedBalance[rowner]++;

            _safeMint(rowner, supply + i);
            delete nftType;
        }
        delete supply;
    }

    function calculateBloodCost(uint256 tokenId)
        public
        view
        returns (uint256 result)
    {
        uint256 base = genZeroSupply;
        uint256 supply = totalSupply();

        uint256 mul = ((supply + tokenId - base) / 2000);

        result = 20000 ether + (mul * 4000 ether);
    }

    function mintWolfByOwner(address user) public onlyOwner {
        uint256 supply = totalSupply();
        addressMintedBalance[user]++;
        tokenType[supply + 1] = 3;
        totalWolf += 1;
        tokenNumByRace[supply + 1] = totalWolf;
        _safeMint(user, supply + 1);
    }

    function mintWolfByCastle(address user) public {
        require(msg.sender == address(castle));
        uint256 supply = totalSupply();
        addressMintedBalance[msg.sender]++;
        tokenType[supply + 1] = 3;
        totalWolf += 1;
        tokenNumByRace[supply + 1] = totalWolf;
        _safeMint(address(user), supply + 1);
    }

    function burn(address user, uint256 tokenId) public {
        require(ownerOf(tokenId) == address(user), "you are not owner");
        _burn(tokenId);
    }

    function massivBurn(uint256 nb) external onlyOwner {
        uint256 supply = totalSupply();
        for (uint256 i = 1; i <= nb; i++) {
            _mint(address(this), supply + i);
        }
    }

    function airdrop(uint256 _amount, address user) public onlyOwner {
        require(
            _amount <= maxMintAmount,
            "max mint amount per session exceeded"
        );
        uint256 supply = totalSupply();

        for (uint256 i = 1; i <= _amount; i++) {
            uint256 nftType = random(101);
            // tokenNum[supply + i] = nftType;
            if (nftType > 99) {
                tokenType[supply + i] = 3;
                totalWolf += 1;
                tokenNumByRace[supply + 1] = totalWolf;
            }
            if (nftType <= 99 && nftType >= 90) {
                tokenType[supply + i] = 2;
                totalVampire += 1;
                tokenNumByRace[supply + 1] = totalVampire;
            } else {
                tokenType[supply + i] = 1;
                totalHuman += 1;
                tokenNumByRace[supply + 1] = totalHuman;
            }
            addressMintedBalance[user]++;
            _safeMint(user, supply + i);
            delete nftType;
        }
        delete supply;
    }

    function isWhitelisted(address _user) public view returns (bool) {
        if (whitelistedAddresses[_user]) return true;
        return false;
    }

    function walletOfOwner(address _owner)
        public
        view
        returns (uint256[] memory)
    {
        uint256 ownerTokenCount = balanceOf(_owner);
        uint256[] memory tokenIds = new uint256[](ownerTokenCount);
        for (uint256 i; i < ownerTokenCount; i++) {
            tokenIds[i] = tokenOfOwnerByIndex(_owner, i);
        }
        return tokenIds;
    }

    function tokenURI(uint256 tokenId)
        public
        view
        virtual
        override
        returns (string memory)
    {
        require(_exists(tokenId), "this token does not exist");

        if (revealed == false) {
            return notRevealedUri;
        }

        string memory currentBaseURI = getBaseURI(tokenId);
        return
            bytes(currentBaseURI).length > 0
                ? string(
                    abi.encodePacked(
                        currentBaseURI,
                        tokenNumByRace[tokenId].toString(),
                        baseExtension
                    )
                )
                : "";
    }

    function getBaseURI(uint256 tokenId) public view returns (string memory) {
        if (tokenType[tokenId] == 1) return baseHumanURI;
        if (tokenType[tokenId] == 2) return baseVampireURI;
        if (tokenType[tokenId] == 3) return baseWolfURI;
    }

    //only owner
    function reveal() public onlyOwner {
        revealed = true;
    }

    function setNftPerAddressLimit(uint256 _limit) public onlyOwner {
        nftPerAddressLimit = _limit;
    }

    function setCost(uint256 _newCost) public onlyOwner {
        cost = _newCost;
    }

    function setmaxMintAmount(uint256 _newmaxMintAmount) public onlyOwner {
        maxMintAmount = _newmaxMintAmount;
    }

    function setBaseURI(
        string memory _newHumanURI,
        string memory _newVampireURI,
        string memory _newWolfURI
    ) public onlyOwner {
        baseHumanURI = _newHumanURI;
        baseVampireURI = _newVampireURI;
        baseWolfURI = _newWolfURI;
    }

    function setBaseExtension(string memory _newBaseExtension)
        public
        onlyOwner
    {
        baseExtension = _newBaseExtension;
    }

    function setNotRevealedURI(string memory _notRevealedURI) public onlyOwner {
        notRevealedUri = _notRevealedURI;
    }

    function pause(bool _state) public onlyOwner {
        paused = _state;
    }

    function setOnlyWhitelisted(bool _state) public onlyOwner {
        onlyWhitelisted = _state;
    }

    function setMaxLimit(uint256 _state) public onlyOwner {
        maxSupply = _state;
    }

    function setMintWithBlood(bool _state) public onlyOwner {
        mintWithBlood = _state;
    }

    function setTokenAddress(Blood _token) public onlyOwner {
        blood = _token;
    }

    function setGenZeroSupply(uint256 _supply) public onlyOwner {
        genZeroSupply = _supply;
    }

    function setCastleAddress(address _castle) public onlyOwner {
        castle = _castle;
    }

    function setTeamAddress(address _teamWallet) public onlyOwner {
        teamWallet = _teamWallet;
    }

    function whitelistUsers(address[] calldata _users) public onlyOwner {
        for (uint256 i = 0; i < _users.length; i++) {
            whitelistedAddresses[_users[i]] = true;
        }
    }

    function withdrawOwner() public onlyOwner {
        uint256 bal = address(this).balance;
        uint256 dev = (bal / 100) * 12;
        payable(owner()).transfer(dev);
        payable(teamWallet).transfer(bal - dev);
    }
}
