// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

contract ReentrancyGuard {
  uint256 private constant _NOT_ENTERED = 1;
  uint256 private constant _ENTERED = 2;

  uint256 private _status;

  constructor() {
    _status = _NOT_ENTERED;
  }

  modifier nonReentrant() {
    require(_status != _ENTERED, "ReentrancyGuard: reentrant call");
    _status = _ENTERED;
    _;
    _status = _NOT_ENTERED;
  }
}

contract ChickenGame is ReentrancyGuard {
  struct User {
    uint id;
    uint registrationTimestamp;
    address referrer;
    uint referrals;
    uint referralPayoutSum;
    uint chickensRewardSum;
    uint missedReferralPayoutSum;
    mapping(uint8 => UserChickensInfo) chickens;
  }

  struct UserChickensInfo {
    uint16 activationTimes;
    uint16 maxPayouts;
    uint16 payouts;
    bool active;
    uint rewardSum;
    uint referralPayoutSum;
  }

  struct GlobalStat {
    uint members;
    uint transactions;
    uint turnover;
  }

  event UserRegistration(uint referralId, uint referrerId);


  uint public constant registrationPrice = 0.025 ether;

    uint[] public referralRewardPercents = [
      0, // none line
      8, // 1st line
      5, // 2nd line
      3, // 3rd line
      2, // 4th line
      1, // 5th line
      1, // 6th line
      1, // 7th line
      1, // 8th line
      1, // 9th line
      1  // 10th line
    ];
    uint rewardableLines = referralRewardPercents.length - 1;

    address payable public owner;
    address payable public tokenBurner;

  uint newUserId = 2;
  mapping(address => User) users;
  mapping(uint => address) usersAddressById;
  GlobalStat globalStat;

  constructor(address payable _tokenBurner) {
    owner = payable(msg.sender);
    tokenBurner = _tokenBurner;

    User storage u = users[owner];
      u.id = 1;
      u.registrationTimestamp = block.timestamp;
      u.referrer = address(0);
      u.referrals = 0;
      u.referralPayoutSum = 0;
      u.chickensRewardSum = 0;
      u.missedReferralPayoutSum = 0;

    usersAddressById[1] = owner;
    globalStat.members++;
    globalStat.transactions++;
  }

  receive() external payable {
    if (!isUserRegistered(msg.sender)) {
      register();
      return;
    }

    revert("Can't find chicken to buy. Maybe sent value is invalid.");
  }

  function register() public payable {
    registerWithReferrer(owner);
  }

  function registerWithReferrer(address referrer) public payable {
    require(msg.value == registrationPrice, "Invalid value sent");
    require(isUserRegistered(referrer), "Referrer is not registered");
    require(!isUserRegistered(msg.sender), "User already registered");
    require(!isContract(msg.sender), "Can not be a contract");

    User storage u = users[msg.sender];
        u.id = newUserId++;
        u.registrationTimestamp = block.timestamp;
        u.referrer = referrer;
        u.referrals = 0;
        u.referralPayoutSum = 0;
        u.chickensRewardSum = 0;
        u.missedReferralPayoutSum = 0;

    //users[msg.sender] = u;
    usersAddressById[u.id] = msg.sender;

    uint8 line = 1;
    address ref = referrer;
    while (line <= rewardableLines && ref != address(0)) {
        users[ref].referrals++;
        ref = users[ref].referrer;
        line++;
    }

    (bool success, ) = tokenBurner.call{value: msg.value}("");
    require(success, "token burn failed while registration");

    globalStat.members++;
    globalStat.transactions++;
    emit UserRegistration(u.id, users[referrer].id);
  }

  function getUser(address userAddress) public view returns(uint, uint, uint, address, uint, uint, uint, uint) {
    User storage user = users[userAddress];
    return (
      user.id,
      user.registrationTimestamp,
      users[user.referrer].id,
      user.referrer,
      user.referrals,
      user.referralPayoutSum,
      user.chickensRewardSum,
      user.missedReferralPayoutSum
    );
  }

  function getGlobalStatistic() public view returns(uint[3] memory result) {
    return [globalStat.members, globalStat.transactions, globalStat.turnover];
  }

  function isUserRegistered(address addr) public view returns (bool) {
    return users[addr].id != 0;
  }

  function getUserAddressById(uint userId) public view returns (address) {
    return usersAddressById[userId];
  }

  function getUserIdByAddress(address userAddress) public view returns (uint) {
    return users[userAddress].id;
  }

  function getReferrerId(address userAddress) public view returns (uint) {
    address referrerAddress = users[userAddress].referrer;
    return users[referrerAddress].id;
  }

  function getReferrer(address userAddress) public view returns (address) {
    require(isUserRegistered(userAddress), "User is not registered");
    return users[userAddress].referrer;
  }

  function isContract(address addr) public view returns (bool) {
    uint32 size;
    assembly {
      size := extcodesize(addr)
    }
    return size != 0;
  }
}