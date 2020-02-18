pragma solidity ^0.4.20;

import "./SafeMath.sol";
import "./ERC223.sol";
import "./BytesLib.sol";


contract ETCOdyssey is ContractReceiver {
  using SafeMath for uint256;
  using BytesLib for bytes;

  bool private rentrancy_lock = false;
  modifier nonReentrant() {
    require(!rentrancy_lock);
    rentrancy_lock = true;
    _;
    rentrancy_lock = false;
  }

  struct PlayerStats {
    uint256 darkMatter;
    uint256 starDust;
    uint256 reactor;
    uint256 thrusters;   //speed
    uint256 blasters;    //attack
    uint256 hull;        //defence
    uint256 lastUpdate;
    uint256 referralId;
    uint256 referralCount;
    uint256 thrusterTimer;
    uint256 shields;
    uint256 hp;
    uint256 cooldown;
    uint256 fused;
  }

  // 1 ETC gets 1000 darkMatter
  uint256 public darkMatterExchangeRate = 10**15 wei;
  uint256 public minimumSpendETC = 10**17 wei;
  uint256 public repairCost = 10**15 wei;
  uint256 public fuseCooldown = 24 hours;
  uint256 public potPercentage = 25;
  uint256 public onexBalance = 0;
  uint256 public totalFused;

  address public admin;
  address public onexAddress;

  mapping(uint256 => address) public referralList;
  mapping(address => address) public referrer;
  mapping(address => PlayerStats) public playerList;

  uint256 referralNonce = 50000000;
  uint[10] referralLevels = [0,5,10,25,50,100,150,200,250,500];
  uint[10] referralRewards = [40,42,44,46,50,54,58,62,66,70];

  uint[10] upgradeCost = [400, 2400, 14400, 86400, 518400, 4147200, 33177600, 265420800, 2123366400, 16986931200];
  uint[10] reactorProduction = [1, 2, 4, 8, 16, 32, 64, 128, 256, 512];
  uint[10] thrusterProduction = [1, 2, 4, 8, 16, 32, 64, 128, 256, 512];
  uint[10] blasterProduction = [1, 2, 4, 8, 16, 32, 64, 128, 256, 512];
  uint[10] hullProduction = [1, 2, 4, 8, 16, 32, 64, 128, 256, 512];
  uint[10] hullStorage = [400 /2, 2400 /2, 14400 /2, 86400 /2, 518400 /2, 4147200 /2, 33177600 /2, 265420800 /2, 2123366400 /2, 16986931200 /2];
  uint[10] thrusterTimes = [72 hours, 48 hours, 24 hours, 12 hours, 6 hours, 3 hours, 2 hours, 1 hours, 30 minutes, 15 minutes];
  uint[10] maxHP = [50, 100, 150, 200, 250, 300, 350, 400, 450, 500];
  uint[10] maxSP = [50, 100, 150, 200, 250, 300, 350, 400, 450, 500];

  event Raid(address winner, uint256 stardust, uint256 darkmatter, uint256 damage, address loser);

  function ETCOdyssey(
    address onextokenaddress
  ) public {
    admin = msg.sender;
    onexAddress = onextokenaddress;
  }

  function tokenFallback(address sender, uint256 amount, bytes data) public {
    require(msg.sender == onexAddress);
    onexBalance += amount;
  }

  // reject incoming ether explicitly
  function () public payable {
    revert();
  }

  // Views
  function shipStats(address player) public view returns(bytes) {
    PlayerStats memory st = playerList[player];

    return toBytes(st.thrusters)
      .concat(toBytes(st.blasters))
      .concat(toBytes(st.hull))
      .concat(toBytes(st.lastUpdate))
      .concat(toBytes(st.thrusterTimer))
      .concat(toBytes(st.shields))
      .concat(toBytes(st.hp))
      .concat(toBytes(st.cooldown));
  }

  function playerFinancials(address player) public view returns(bytes) {
    PlayerStats memory st = playerList[player];

    return toBytes(st.reactor)
      .concat(toBytes(st.lastUpdate))
      .concat(toBytes(st.referralId))
      .concat(toBytes(st.referralCount))
      .concat(toBytes(st.fused))
      .concat(toBytes(st.darkMatter))
      .concat(toBytes(st.starDust));
  }

  function getProductionRate(address player) public view returns(uint256 productionRate) {
    productionRate = 1 + reactorProduction[playerList[player].reactor] +
      blasterProduction[playerList[player].blasters] +
      thrusterProduction[playerList[player].thrusters] +
      hullProduction[playerList[player].hull];
    productionRate = productionRate;
  }

  // Writeable functions
  function initShip(uint256 ref) public nonReentrant payable {
    require(msg.value >= minimumSpendETC);
    require(playerList[msg.sender].lastUpdate == 0);

    playerList[msg.sender].lastUpdate = now;
    uint256 earnedMatter = msg.value / darkMatterExchangeRate;
    playerList[msg.sender].darkMatter += earnedMatter;
    if(referralList[ref] != address(0)){
      playerList[referralList[ref]].referralCount += 1;
      referrer[msg.sender] = referralList[ref];
      playerList[referrer[msg.sender]].darkMatter += earnedMatter / 100;
    }
    playerList[msg.sender].referralId = referralNonce;
    referralList[referralNonce] = msg.sender;
    referralNonce++;
    playerList[msg.sender].shields = 50;
    playerList[msg.sender].hp = 50;
    admin.transfer(msg.value/20);
  }

  function buyDarkMatter() public nonReentrant payable {
    require(playerList[msg.sender].lastUpdate != 0);
    require(msg.value >= darkMatterExchangeRate);
    updateStats(msg.sender);
    uint256 earnedMatter = msg.value / darkMatterExchangeRate;
    playerList[msg.sender].darkMatter += earnedMatter;
    if (referrer[msg.sender] != address(0)) {
      playerList[referrer[msg.sender]].darkMatter += earnedMatter / 100;
    }
    admin.transfer(msg.value / 20);
  }

  function purchaseUpgradeReactor() public nonReentrant {
    require(playerList[msg.sender].lastUpdate != 0);
    require(playerList[msg.sender].reactor + 1 < 10);
    updateStats(msg.sender);
    require(upgradeCost[playerList[msg.sender].reactor + 1] <= playerList[msg.sender].darkMatter);
    playerList[msg.sender].darkMatter = playerList[msg.sender].darkMatter.sub(upgradeCost[playerList[msg.sender].reactor + 1]);
    playerList[msg.sender].reactor += 1;
  }

  function purchaseUpgradeBlasters() public nonReentrant {
    require(playerList[msg.sender].lastUpdate != 0);
    require(playerList[msg.sender].blasters + 1 < 10);
    updateStats(msg.sender);
    require(upgradeCost[playerList[msg.sender].blasters + 1] <= playerList[msg.sender].darkMatter);
    playerList[msg.sender].darkMatter = playerList[msg.sender].darkMatter.sub(upgradeCost[playerList[msg.sender].blasters + 1]);
    playerList[msg.sender].blasters += 1;
  }

  function purchaseUpgradeThrusters() public nonReentrant {
    require(playerList[msg.sender].lastUpdate != 0);
    require(playerList[msg.sender].thrusters + 1 < 10);
    updateStats(msg.sender);
    require(upgradeCost[playerList[msg.sender].thrusters + 1] <= playerList[msg.sender].darkMatter);
    playerList[msg.sender].darkMatter = playerList[msg.sender].darkMatter.sub(upgradeCost[playerList[msg.sender].thrusters + 1]);
    playerList[msg.sender].thrusters += 1;
    if (playerList[msg.sender].thrusterTimer > now + thrusterTimes[playerList[msg.sender].thrusters]) {
      playerList[msg.sender].thrusterTimer = now + thrusterTimes[playerList[msg.sender].thrusters];
    } else {
      playerList[msg.sender].thrusterTimer = 0;
    }
  }

  function purchaseUpgradeHull() public nonReentrant {
    require(playerList[msg.sender].lastUpdate != 0);
    require(playerList[msg.sender].hull + 1 < 10);
    updateStats(msg.sender);
    require(upgradeCost[playerList[msg.sender].hull + 1] <= playerList[msg.sender].darkMatter);
    playerList[msg.sender].darkMatter = playerList[msg.sender].darkMatter.sub(upgradeCost[playerList[msg.sender].hull + 1]);
    playerList[msg.sender].hull += 1;
    playerList[msg.sender].hp = maxHP[playerList[msg.sender].hull];
  }

  function startRaid() public nonReentrant {
    updateStats(msg.sender);
    require(playerList[msg.sender].thrusterTimer < now);
    require(playerList[msg.sender].hp > 0);
    uint256 randomnumber = uint(keccak256(block.timestamp));
    address opponent = referralList[50000000 + (randomnumber % (referralNonce - 50000000))];
    if (opponent == msg.sender) {
      // shift by one
      opponent = referralList[50000000 - 1 + (randomnumber % (referralNonce - 50000000))];
    }
    updateStats(opponent);

    uint256 attackScore = randomnumber % (120 * (playerList[msg.sender].blasters + 1));
    uint256 defenceScore = playerList[opponent].shields + playerList[opponent].hp;
    uint256 sd;
    uint256 dm;

    if (attackScore > defenceScore) {
      if (hullStorage[playerList[opponent].hull] < playerList[opponent].starDust) {
        sd = playerList[opponent].starDust - hullStorage[playerList[opponent].hull];
        playerList[msg.sender].starDust += sd;
        playerList[opponent].starDust = hullStorage[playerList[opponent].hull];
      }
      if (hullStorage[playerList[opponent].hull] < playerList[opponent].darkMatter) {
        dm = playerList[opponent].darkMatter - hullStorage[playerList[opponent].hull];
        playerList[msg.sender].darkMatter += dm;
        playerList[opponent].darkMatter = hullStorage[playerList[opponent].hull];
      }
      playerList[msg.sender].thrusterTimer = now + thrusterTimes[playerList[msg.sender].thrusters];
      playerList[opponent].shields = 0;
      playerList[opponent].hp = 0;
      Raid(msg.sender, sd, dm, attackScore, opponent);
    } else {
      if (playerList[opponent].shields <= attackScore) {
        uint256 newAtk = attackScore - playerList[opponent].shields;
        playerList[opponent].shields = 0;
        if (playerList[opponent].hp < newAtk) {
          playerList[opponent].hp = 0;
        } else {
          playerList[opponent].hp -= newAtk;
        }
      } else {
        playerList[opponent].shields -= attackScore;
      }
      playerList[msg.sender].thrusterTimer = now + thrusterTimes[playerList[msg.sender].thrusters];
      Raid(opponent, 0, 0, attackScore, msg.sender);
    }
  }

  function repairShipUnit() public nonReentrant payable{
    require(msg.value >= repairCost);
    uint256 repUnits = msg.value / repairCost;
    uint256 earnedValue;
    if (repUnits + playerList[msg.sender].hp > maxHP[playerList[msg.sender].hull]) {
      uint256 diff = repUnits + playerList[msg.sender].hp - maxHP[playerList[msg.sender].hull];
      uint256 refund = repairCost * diff;
      earnedValue = msg.value - refund;
      msg.sender.transfer(refund);
      playerList[msg.sender].hp = maxHP[playerList[msg.sender].hull];
    } else {
      earnedValue = msg.value;
      playerList[msg.sender].hp = repUnits + playerList[msg.sender].hp;
    }
    admin.transfer(earnedValue/20);
  }

  // fusion deposit function - allows users to "freeze", or "fuse", their star dust
  function fusion(uint256 amount) public nonReentrant {
    updateStats(msg.sender);
    playerList[msg.sender].starDust = playerList[msg.sender].starDust.sub(amount);
    totalFused += amount;
    playerList[msg.sender].fused += amount;
    playerList[msg.sender].cooldown = now + fuseCooldown;
  }

  // Fusion withdraw function - allows user to withdraw from the fusion pool
  function withdrawShare() public nonReentrant {
    updateStats(msg.sender);
    require(playerList[msg.sender].fused > 0);
    require(now >= playerList[msg.sender].cooldown);
    msg.sender.transfer((this.balance * potPercentage / 100) * playerList[msg.sender].fused / totalFused);
    totalFused = totalFused.sub(playerList[msg.sender].fused);
    playerList[msg.sender].fused = 0;
  }

  function changePot(uint256 percentage) public {
    require(msg.sender == admin);
    require(percentage <= 100);
    potPercentage = percentage;
  }

  function dustForONEX(uint256 amount) public nonReentrant {
    updateStats(msg.sender);
    uint256 onexamount = amount.mul(5000000000000);
    if (playerList[msg.sender].starDust >= amount && onexBalance > onexamount) {
      playerList[msg.sender].starDust -= amount;
      ERC223(onexAddress).transfer(msg.sender, onexamount);
      onexBalance = onexBalance.sub(onexamount);
    }
  }

  function adminWithdrawONEX(uint256 amount) public {
    require(msg.sender == admin);
    ERC223(onexAddress).transfer(admin, amount);
  }

  // internal functions
  function updateStats(address player) internal {
    require(playerList[player].lastUpdate != 0);
    uint256 starDustRatio = getReferralRewards(playerList[player].referralCount);
    playerList[player].darkMatter +=
      (100 - starDustRatio) * (now - playerList[player].lastUpdate) *
      getProductionRate(player) / 100;
    playerList[player].starDust +=
      starDustRatio * (now - playerList[player].lastUpdate) *
      getProductionRate(player) / 100;

    if (playerList[msg.sender].shields + ((now - playerList[player].lastUpdate) / 100) > maxSP[playerList[msg.sender].reactor]) {
      playerList[msg.sender].shields = maxSP[playerList[msg.sender].reactor];
    } else {
      playerList[msg.sender].shields = playerList[msg.sender].shields +
        ((now - playerList[player].lastUpdate) / 100);
    }

    playerList[player].lastUpdate = now;
  }

  function getReferralRewards(uint256 refCount) internal view returns(uint) {
    for (uint256 x = 0; x < 10; x++) {
      if (referralLevels[x] > refCount) {
        return referralRewards[x - 1];
      }
    }
    return 70;
  }

  // helpers

  function toBytes(uint256 x) returns (bytes b) {
    b = new bytes(32);
    assembly { mstore(add(b, 32), x) }
  }
}
