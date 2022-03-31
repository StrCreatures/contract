// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "./Blood.sol";
import "./MyNft.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract Castle {
    using SafeMath for uint256;
    string public name = "Strange Creatures Game";
    uint256 public HUMAN_TOKEN_PER_DAY = 10000 ether;
    uint256 public WOLF_TOKEN_PER_DAY = 5000 ether;
    // uint256 public cost = 0.0001 ether;
    uint256 public MAXIMUM_GLOBAL_THRONE = 24000000 ether;

    uint256 public totalHumanRewards;
    uint256 public totalTaxVampire;
    uint256 public totalWolfRewards;

    uint256 public unaccountedRewards;

    uint256 public lastClaimTimestamp;
    uint256 public startedTimestamp;
    uint256 public dayCount;
    uint256 public dailyRewardPerVampire;

    uint256 randNonce = 0;
    uint256 public ratio = 5;

    address public owner;
    Blood public blood;
    MyNFT public myNFT;

    bool public paused;

    // maps tokenId to stake
    mapping(uint256 => Stake) public battle;

    uint256 public totalStaked;
    uint256 public totalHumanStaked;
    uint256 public totalVampireStaked;
    uint256 public totalWolfStaked;

    mapping(address => uint256[]) public stakingArray;

    mapping(uint256 => uint256[]) public pack;

    mapping(address => mapping(uint256 => uint256)) public tokenIDsByWallet;
    mapping(address => uint256) public counterByWallet;
    mapping(uint256 => uint256) public _ownedTokensIndex;

    mapping(address => uint256) public totalVampireRewardLost;
    mapping(address => uint256) public totalWolfRewardGain;

    mapping(uint256 => bool) public lastAttackResult;
    mapping(uint256 => uint256) public totalAttacks;
    mapping(uint256 => uint256) public totalSuccessfullAttacks;
    mapping(uint256 => uint256) public lastAttackTimeOfWolf;

    mapping(uint256 => uint256) public timeStaked;
    mapping(address => mapping(uint256 => uint256)) public lastRewarded;
    mapping(address => mapping(uint256 => bool)) public stakingRecord;

    event NewStaker(address staker, uint256 id);
    event UnStaked(address staker, uint256 id);
    event rewardsClaimed(address user, uint256 total);

    struct Stake {
        address owner;
        uint256 tokenId;
        uint256 stakeTime;
        uint256 value;
    }

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    constructor() {
        owner = msg.sender;
        startedTimestamp = block.timestamp;
        dayCount = block.timestamp;
    }

    function random(uint256 _modulus) internal returns (uint256) {
        randNonce++;
        return
            uint256(
                keccak256(
                    abi.encodePacked(block.timestamp, msg.sender, randNonce)
                )
            ) % _modulus;
    }

    function stake(uint256[] calldata _ids) public {
        require(!paused, "staking is paused");
        for (uint256 index = 0; index < _ids.length; index++) {
            myNFT.transferFrom(msg.sender, address(this), _ids[index]);
            addTokenToOwnerEnumeration(msg.sender, _ids[index]);

            uint256 myType = myNFT.tokenType(_ids[index]);
            if (myType == 1) {
                battle[_ids[index]] = Stake({
                    owner: msg.sender,
                    tokenId: uint256(_ids[index]),
                    stakeTime: uint256(block.timestamp),
                    value: uint256(block.timestamp)
                });
                totalHumanStaked += 1;
            }
            if (myType == 2) {
                pack[myType].push(_ids[index]);
                battle[_ids[index]] = Stake({
                    owner: msg.sender,
                    tokenId: uint256(_ids[index]),
                    stakeTime: uint256(block.timestamp),
                    value: totalTaxVampire
                });
                totalVampireStaked += 1;
            }
            if (myType == 3) {
                pack[myType].push(_ids[index]);
                battle[_ids[index]] = Stake({
                    owner: msg.sender,
                    tokenId: uint256(_ids[index]),
                    stakeTime: uint256(block.timestamp),
                    value: uint256(block.timestamp)
                });
                totalWolfStaked += 1;
            }

            stakingArray[msg.sender].push(_ids[index]);
            emit NewStaker(msg.sender, _ids[index]);
        }
    }

    function randomCreatureOwner() external returns (address) {
        uint256 bucket = random(2);

        if (bucket < 1) {
            if (totalVampireStaked < 1) return address(0x0);

            uint256 stealer = random(pack[2].length);
            return battle[pack[2][stealer]].owner;
        } else {
            if (totalWolfStaked < 1) return address(0x0);

            uint256 stealer = random(pack[3].length);
            return battle[pack[3][stealer]].owner;
        }
    }

    function unstake(uint256[] calldata tokenIds) public {
        uint256 remainingReward;

        for (uint256 index = 0; index < tokenIds.length; index++) {
            Stake memory stake = battle[tokenIds[index]];

            require(
                stake.stakeTime + 2 days >= block.timestamp,
                "Unstake success only after 2 days"
            );

            uint256 totalRewards = 0;
            uint256 tax = 0;
            uint256 myType = myNFT.tokenType(tokenIds[index]);
            myNFT.transferFrom(address(this), msg.sender, tokenIds[index]);
            // delete stakingArray[msg.sender][_arrayIndex];
            removeTokenFromOwnerEnumeration(msg.sender, tokenIds[index]);

            if (myType == 1) {
                totalRewards = calculateRewards(tokenIds[index]);
                uint256 ratio = random(2);
                if (ratio <= 0) {
                    remainingReward += totalRewards;
                } else {
                    _payVampireTax(totalRewards / 2);
                }
                totalHumanStaked -= 1;
                delete battle[tokenIds[index]];
            }
            if (myType == 2) {
                remainingReward += calculateRewards(tokenIds[index]);
                totalVampireStaked -= 1;
                delete battle[tokenIds[index]];
            }
            if (myType == 3) {
                remainingReward += calculateRewards(tokenIds[index]);
                totalWolfStaked -= 1;
                delete battle[tokenIds[index]];
            }
            emit UnStaked(msg.sender, tokenIds[index]);
        }
        blood.mint(msg.sender, remainingReward);
    }

    function calculateRewards(uint256 tokenId)
        public
        view
        returns (uint256 owed)
    {
        Stake memory stake = battle[tokenId];
        uint256 myType = myNFT.tokenType(tokenId);

        if (myType == 1) {
            if (totalHumanRewards + totalWolfRewards < MAXIMUM_GLOBAL_THRONE) {
                owed =
                    ((block.timestamp - stake.value) * HUMAN_TOKEN_PER_DAY) /
                    1 days;
            } else if (stake.value > lastClaimTimestamp) {
                owed = 0;
            } else {
                owed =
                    ((lastClaimTimestamp - stake.value) * HUMAN_TOKEN_PER_DAY) /
                    1 days;
            }
        } else if (myType == 2) {
            owed = (totalTaxVampire - stake.value) / totalVampireStaked;
        } else if (myType == 3) {
            if (totalHumanRewards + totalWolfRewards < MAXIMUM_GLOBAL_THRONE) {
                owed =
                    ((block.timestamp - stake.value) * WOLF_TOKEN_PER_DAY) /
                    1 days;
            } else if (stake.value > lastClaimTimestamp) {
                owed = 0;
            } else {
                owed =
                    ((lastClaimTimestamp - stake.value) * WOLF_TOKEN_PER_DAY) /
                    1 days;
            }
        }
    }

    function claimRewards(uint256[] calldata tokenIds) public {
        require(msg.sender == tx.origin, "Only EOA");
        uint256 remainingReward;

        for (uint256 index = 0; index < tokenIds.length; index++) {
            require(
                battle[tokenIds[index]].owner == msg.sender,
                "You are not owner of this tokens"
            );

            uint256 totalRewards = 0;
            uint256 tax = 0;

            uint256 myType = myNFT.tokenType(tokenIds[index]);

            if (myType == 1) {
                totalRewards = calculateRewards(tokenIds[index]);
                tax = (totalRewards * 20) / 100;
                remainingReward += totalRewards - tax;
                _payVampireTax(tax);

                battle[tokenIds[index]] = Stake({
                    owner: msg.sender,
                    tokenId: uint256(tokenIds[index]),
                    stakeTime: uint256(block.timestamp),
                    value: uint256(block.timestamp)
                });
            }
            // 20% goes to vampire
            if (myType == 2) {
                remainingReward += calculateRewards(tokenIds[index]);
                battle[tokenIds[index]] = Stake({
                    owner: msg.sender,
                    tokenId: uint256(tokenIds[index]),
                    stakeTime: uint256(block.timestamp),
                    value: totalTaxVampire
                });
            }

            if (myType == 3) {
                remainingReward += calculateRewards(tokenIds[index]);
                battle[tokenIds[index]] = Stake({
                    owner: msg.sender,
                    tokenId: uint256(tokenIds[index]),
                    stakeTime: uint256(block.timestamp),
                    value: uint256(block.timestamp)
                });
            }
        }

        blood.mint(msg.sender, remainingReward);
    }

    function _payVampireTax(uint256 amount) internal {
        if (totalVampireStaked == 0) {
            unaccountedRewards += amount;
            return;
        }
        if (dayCount + 1 days >= block.timestamp) {
            dailyRewardPerVampire +=
                (amount + unaccountedRewards) /
                totalVampireStaked;
        } else {
            dayCount = block.timestamp;
            dailyRewardPerVampire = 0;
        }
        totalTaxVampire += (amount + unaccountedRewards);
        unaccountedRewards = 0;
    }

    function wolfAttack(uint256 _id, uint256 numberOfVampire) public {
        //can attack ones every 1 day
        uint256 myType = myNFT.tokenType(_id);
        uint256 diff = lastAttackTimeOfWolf[_id];
        require(
            diff + 1 days <= block.timestamp,
            "wolf can only attack every 24 hours"
        );
        require(myType == 3, "You are not a wolf");
        require(numberOfVampire <= 5, "You cannot attack more then 5 vampires");
        require(totalVampireStaked > numberOfVampire, "no vampire staked");
        uint256 chance = random(1001);
        uint256 totalRewards = dailyRewardPerVampire * numberOfVampire;

        totalAttacks[_id] += 1;
        lastAttackResult[_id] = false;
        lastAttackTimeOfWolf[_id] = block.timestamp;

        if (chance <= 900 && numberOfVampire == 1) {
            totalTaxVampire -= totalRewards.div(ratio);
            blood.mint(msg.sender, totalRewards);
            totalSuccessfullAttacks[_id] += 1;
            lastAttackResult[_id] = true;
            return;
        }

        if (chance <= 450 && numberOfVampire == 2) {
            totalTaxVampire -= totalRewards.div(ratio);
            blood.mint(msg.sender, totalRewards);
            totalSuccessfullAttacks[_id] += 1;
            lastAttackResult[_id] = true;
            return;
        }

        if (chance <= 225 && numberOfVampire == 3) {
            totalTaxVampire -= totalRewards.div(ratio);
            blood.mint(msg.sender, totalRewards);
            totalSuccessfullAttacks[_id] += 1;
            lastAttackResult[_id] = true;
            return;
        }

        if (chance <= 112 && numberOfVampire == 4) {
            totalTaxVampire -= totalRewards.div(ratio);
            blood.mint(msg.sender, totalRewards);
            totalSuccessfullAttacks[_id] += 1;
            lastAttackResult[_id] = true;
            return;
        }

        if (chance <= 56 && numberOfVampire == 5) {
            totalTaxVampire -= totalRewards.div(ratio);
            blood.mint(msg.sender, totalRewards);
            totalSuccessfullAttacks[_id] += 1;
            lastAttackResult[_id] = true;
            return;
        }
    }

    function transform(uint256 tokenId) public {
        Stake memory stake = battle[tokenId];
        require(stake.owner == msg.sender, "You are not owner");
        // require(
        //     stake.stakeTime + 10 days >= block.timestamp,
        //     "you need 100k token accumulated"
        // );
        delete battle[tokenId];
        myNFT.burn(msg.sender, tokenId);
        myNFT.mintWolfByCastle(msg.sender);
    }

    function addTokenToOwnerEnumeration(address to, uint256 tokenId) internal {
        uint256 length = counterByWallet[to];
        tokenIDsByWallet[to][length] = tokenId;
        _ownedTokensIndex[tokenId] = length;
        counterByWallet[to]++;
    }

    function removeTokenFromOwnerEnumeration(address from, uint256 tokenId)
        internal
    {
        // To prevent a gap in from's tokens array, we store the last token in the index of the token to delete, and
        // then delete the last slot (swap and pop).
        uint256 tokenIndex;
        for (uint256 i = 0; i < counterByWallet[from]; i++) {
            if (tokenIDsByWallet[from][i] == tokenId) tokenIndex = i;
        }
        uint256 lastTokenIndex = counterByWallet[from] - 1;
        // When the token to delete is the last token, the swap operation is unnecessary
        if (tokenIndex != lastTokenIndex) {
            uint256 lastTokenId = tokenIDsByWallet[from][lastTokenIndex];

            tokenIDsByWallet[from][tokenIndex] = lastTokenId; // Move the last token to the slot of the to-delete token
            _ownedTokensIndex[lastTokenId] = tokenIndex; // Update the moved token's index
        }

        // This also deletes the contents at the last position of the array
        counterByWallet[from]--;
        delete _ownedTokensIndex[tokenId];
        delete tokenIDsByWallet[from][lastTokenIndex];
    }

    function walletOfOwner(address _owner)
        public
        view
        returns (uint256[] memory)
    {
        uint256 ownerTokenCount = counterByWallet[_owner];
        uint256[] memory tokenIds = new uint256[](ownerTokenCount);
        for (uint256 i; i < ownerTokenCount; i++) {
            tokenIds[i] = tokenIDsByWallet[_owner][i];
        }
        return tokenIds;
    }

    function setHumanTokenPerDay(uint256 _state) public onlyOwner {
        HUMAN_TOKEN_PER_DAY = _state;
    }

    function setWofTokenPerDay(uint256 _state) public onlyOwner {
        WOLF_TOKEN_PER_DAY = _state;
    }

    function setRatio(uint256 _ratio) public onlyOwner {
        require(_ratio > 0, "wut ?");
        ratio = _ratio;
    }

    function setHelperContractd(Blood _blood, MyNFT _myNFT) public onlyOwner {
        blood = _blood;
        myNFT = _myNFT;
    }
}
