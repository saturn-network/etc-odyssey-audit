pragma solidity ^0.4.20;

import "./SafeMath.sol";

contract ERC223 {
  uint public totalSupply;
  function balanceOf(address who) constant returns (uint);

  function name() constant returns (string _name);
  function symbol() constant returns (string _symbol);
  function decimals() constant returns (uint8 _decimals);
  function totalSupply() constant returns (uint256 _supply);

  function transfer(address to, uint value) returns (bool ok);
  function transfer(address to, uint value, bytes data) returns (bool ok);
  event Transfer(address indexed _from, address indexed _to, uint256 _value);
  event ERC223Transfer(address indexed _from, address indexed _to, uint256 _value, bytes _data);
}


contract OriginalETCOdyssey
{
  address public tokenAddress;
  uint public darkMatterExchangeRate = 100 szabo; // 1 ETC gets 1000 darkMatter
  uint public darkMatterExchangeRateToken = 1 finney; // 1 TOKEN gets 100 darkMatter
  uint public minimumSpendETC = 100 finney;
  uint public repairCost = 1 finney;

  uint public fuseCooldown = 24 hours;

  uint public potPercentage = 25;

  /* address public admin = 0x4B4f724B936290bDADC87439856Eaf2671eb5072; */
  // NOTE: modified this line to support testing
  address public admin;

  // moved from the bottom of the file and modified to support testing
  address public onexAddress;
  uint public onexBalance = 0;

  event Raid(address winner, uint stardust, uint darkmatter, uint damage, address loser);

  uint public totalFused;

  using SafeMath for uint256;

  mapping(uint => address) public referralList;
  mapping(address => address) public referrer;

  uint referralNonce = 50000000;
  uint[10] referralLevels = [0,5,10,25,50,100,150,200,250,500];
  uint[10] referralRewards = [40,42,44,46,50,54,58,62,66,70];

  mapping (address => PlayerStats) public playerList;

  uint[10] upgradeCost = [400, 2400, 14400, 86400, 518400, 4147200, 33177600, 265420800, 2123366400, 16986931200];

  uint[10] reactorProduction = [1, 2, 4, 8, 16, 32, 64, 128, 256, 512];
  uint[10] thrusterProduction = [1, 2, 4, 8, 16, 32, 64, 128, 256, 512];
  uint[10] blasterProduction = [1, 2, 4, 8, 16, 32, 64, 128, 256, 512];
  uint[10] hullProduction = [1, 2, 4, 8, 16, 32, 64, 128, 256, 512];

  uint[10] hullStorage = [400 /2, 2400 /2, 14400 /2, 86400 /2, 518400 /2, 4147200 /2, 33177600 /2, 265420800 /2, 2123366400 /2, 16986931200 /2];
  uint[10] thrusterTimes = [72 hours, 48 hours, 24 hours, 12 hours, 6 hours, 3 hours, 2 hours, 1 hours, 30 minutes, 15 minutes];
  uint[10] maxHP = [50, 100, 150, 200, 250, 300, 350, 400, 450, 500];
  uint[10] maxSP = [50, 100, 150, 200, 250, 300, 350, 400, 450, 500];

  // NOTE: added constructor to set admin and onex addresses
  function ETCOdyssey(
    address onextokenaddress
  ) public {
    admin = msg.sender;
    onexAddress = onextokenaddress;
  }

  struct PlayerStats{
    uint darkMatter;
    uint starDust;
    uint reactor;
    uint thrusters; //speed
    uint blasters; //attack
    uint hull;  //defence
    uint lastUpdate;
    uint referralId;
    uint referralCount;
    uint thrusterTimer;
    uint shields;
    uint hp;
    uint cooldown;
    uint fused;
  }

  function initShip(uint ref) public payable{
    require(msg.value >= minimumSpendETC);
    require(playerList[msg.sender].lastUpdate == 0);

    playerList[msg.sender].lastUpdate = now;
    uint earnedMatter = msg.value / darkMatterExchangeRate;
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

  function getProductionRate(address player) public view returns(uint productionRate){
    productionRate = 1 + reactorProduction[playerList[player].reactor] + blasterProduction[playerList[player].blasters] + thrusterProduction[playerList[player].thrusters] + hullProduction[playerList[player].hull];
    productionRate = productionRate;// * 1000000000000000000;
  }

  function updateStats(address player) internal {
    require(playerList[player].lastUpdate != 0);
    uint starDustRatio = getReferralRewards(playerList[player].referralCount);
    playerList[player].darkMatter += (100 - starDustRatio) * (now - playerList[player].lastUpdate) * getProductionRate(player) / 100;
    playerList[player].starDust += starDustRatio * (now - playerList[player].lastUpdate) * getProductionRate(player) / 100;

    if(playerList[msg.sender].shields + ((now - playerList[player].lastUpdate) / 100) > maxSP[playerList[msg.sender].reactor]){
        playerList[msg.sender].shields = maxSP[playerList[msg.sender].reactor];
    }
    else{
        playerList[msg.sender].shields = playerList[msg.sender].shields + ((now - playerList[player].lastUpdate) / 100);
    }

    playerList[player].lastUpdate = now;
  }

  function getReferralRewards(uint refCount) internal view returns(uint){
    for(uint x = 0; x < 10; x++){
      if(referralLevels[x] > refCount){
        return referralRewards[x - 1];
      }
    }
    return 70;
  }

  function buyDarkMatter() public payable{
    require(playerList[msg.sender].lastUpdate != 0);
    require(msg.value >= darkMatterExchangeRate);
    updateStats(msg.sender);
    uint earnedMatter = msg.value / darkMatterExchangeRate;
    playerList[msg.sender].darkMatter += earnedMatter;
    if(referrer[msg.sender] != address(0)){
      playerList[referrer[msg.sender]].darkMatter += earnedMatter / 100;
    }
    admin.transfer(msg.value/20);
  }

  function purchaseUpgradeReactor() public payable{
    require(playerList[msg.sender].lastUpdate != 0);
    require(playerList[msg.sender].reactor + 1 < 10);
    updateStats(msg.sender);
    require(upgradeCost[playerList[msg.sender].reactor + 1] <= playerList[msg.sender].darkMatter + playerList[msg.sender].starDust);
    if(playerList[msg.sender].darkMatter >= upgradeCost[playerList[msg.sender].reactor + 1]){
      playerList[msg.sender].darkMatter = playerList[msg.sender].darkMatter.sub(upgradeCost[playerList[msg.sender].reactor + 1]);
    }
    else{
      uint remaining = upgradeCost[playerList[msg.sender].reactor + 1];
      remaining -= playerList[msg.sender].darkMatter;
      playerList[msg.sender].darkMatter = 0;
      playerList[msg.sender].starDust -= remaining;
    }
    playerList[msg.sender].reactor += 1;
  }

  function purchaseUpgradeBlasters() public payable{
    require(playerList[msg.sender].lastUpdate != 0);
    require(playerList[msg.sender].blasters + 1 < 10);
    updateStats(msg.sender);
    require(upgradeCost[playerList[msg.sender].blasters + 1] <= playerList[msg.sender].darkMatter + playerList[msg.sender].starDust);
    if(playerList[msg.sender].darkMatter >= upgradeCost[playerList[msg.sender].blasters + 1]){
      playerList[msg.sender].darkMatter = playerList[msg.sender].darkMatter.sub(upgradeCost[playerList[msg.sender].blasters + 1]);
    }
    else{
      uint remaining = upgradeCost[playerList[msg.sender].blasters + 1];
      remaining -= playerList[msg.sender].darkMatter;
      playerList[msg.sender].darkMatter = 0;
      playerList[msg.sender].starDust -= remaining;
    }
    playerList[msg.sender].blasters += 1;
  }

  function purchaseUpgradeThrusters() public payable{
    require(playerList[msg.sender].lastUpdate != 0);
    require(playerList[msg.sender].thrusters + 1 < 10);
    updateStats(msg.sender);
    require(upgradeCost[playerList[msg.sender].thrusters + 1] <= playerList[msg.sender].darkMatter + playerList[msg.sender].starDust);
    if(playerList[msg.sender].darkMatter >= upgradeCost[playerList[msg.sender].thrusters + 1]){
      playerList[msg.sender].darkMatter = playerList[msg.sender].darkMatter.sub(upgradeCost[playerList[msg.sender].thrusters + 1]);
    }
    else{
      uint remaining = upgradeCost[playerList[msg.sender].thrusters + 1];
      remaining -= playerList[msg.sender].darkMatter;
      playerList[msg.sender].darkMatter = 0;
      playerList[msg.sender].starDust -= remaining;
    }
    playerList[msg.sender].thrusters += 1;
    if(playerList[msg.sender].thrusterTimer > now + thrusterTimes[playerList[msg.sender].thrusters]){
      playerList[msg.sender].thrusterTimer = now + thrusterTimes[playerList[msg.sender].thrusters];
    }
    else{
      playerList[msg.sender].thrusterTimer = 0;
    }
  }

  function purchaseUpgradeHull() public payable{
    require(playerList[msg.sender].lastUpdate != 0);
    require(playerList[msg.sender].hull + 1 < 10);
    updateStats(msg.sender);
    require(upgradeCost[playerList[msg.sender].hull + 1] <= playerList[msg.sender].darkMatter + playerList[msg.sender].starDust);
    if(playerList[msg.sender].darkMatter >= upgradeCost[playerList[msg.sender].hull + 1]){
      playerList[msg.sender].darkMatter = playerList[msg.sender].darkMatter.sub(upgradeCost[playerList[msg.sender].hull + 1]);
    }
    else{
      uint remaining = upgradeCost[playerList[msg.sender].hull + 1];
      remaining -= playerList[msg.sender].darkMatter;
      playerList[msg.sender].darkMatter = 0;
      playerList[msg.sender].starDust -= remaining;
    }

    playerList[msg.sender].hull += 1;
    playerList[msg.sender].hp = maxHP[playerList[msg.sender].hull];
  }

  function startRaid() public payable{
    updateStats(msg.sender);
    require(playerList[msg.sender].thrusterTimer < now);
    require(playerList[msg.sender].hp > 0);
    address opponent = referralList[50000000 + (uint(keccak256(block.timestamp)) % (referralNonce - 50000000))];
    if(opponent == msg.sender){
      Raid(opponent, 0, 0, 0, msg.sender);
      return;
    }
    updateStats(opponent);

    uint attackScore = uint(keccak256(block.timestamp)) % (120 * (playerList[msg.sender].blasters + 1));
    uint defenceScore = playerList[opponent].shields + playerList[opponent].hp;
    uint sd;
    uint dm;

    if(attackScore > defenceScore){
        if(hullStorage[playerList[opponent].hull] < playerList[opponent].starDust){
            playerList[msg.sender].starDust += (playerList[opponent].starDust - hullStorage[playerList[opponent].hull]);
            sd = (playerList[opponent].starDust - hullStorage[playerList[opponent].hull]);
            playerList[opponent].starDust = hullStorage[playerList[opponent].hull];
        }
        if(hullStorage[playerList[opponent].hull] < playerList[opponent].darkMatter){
            playerList[msg.sender].darkMatter += playerList[opponent].darkMatter - hullStorage[playerList[opponent].hull];
            dm = playerList[opponent].darkMatter - hullStorage[playerList[opponent].hull];
            playerList[opponent].darkMatter = hullStorage[playerList[opponent].hull];
        }

        playerList[msg.sender].thrusterTimer = now + thrusterTimes[playerList[msg.sender].thrusters];
        playerList[opponent].shields = 0;
        playerList[opponent].hp = 0;
        Raid(msg.sender, sd, dm, attackScore, opponent);
    }
    else{
        if(playerList[opponent].shields <= attackScore){
            playerList[opponent].shields = 0;
            uint newAtk = attackScore - playerList[opponent].shields;
            if(playerList[opponent].hp < newAtk){
              playerList[opponent].hp = 0;
            }
            else{
              playerList[opponent].hp = playerList[opponent].hp.sub(newAtk);
            }
        }
        else{
            playerList[opponent].shields -= attackScore;
        }
        playerList[msg.sender].thrusterTimer = now + thrusterTimes[playerList[msg.sender].thrusters];
        Raid(opponent, 0, 0, attackScore, msg.sender);
    }

  }

  //TODO: this amount should be chosen by user
  function repairShip() public payable{
      require(msg.value >= (maxHP[playerList[msg.sender].hull] - playerList[msg.sender].hp) * repairCost);
      playerList[msg.sender].hp = maxHP[playerList[msg.sender].hull];
      admin.transfer(msg.value/20);
  }

  function repairShipUnit() public payable{
      require(msg.value >= repairCost);
      uint repUnits = msg.value / repairCost;
      if(repUnits + playerList[msg.sender].hp > maxHP[playerList[msg.sender].hull]){
        playerList[msg.sender].hp = maxHP[playerList[msg.sender].hull];
      }
      else{
        playerList[msg.sender].hp = repUnits + playerList[msg.sender].hp;
      }
      admin.transfer(msg.value/20);
  }

  //fusion deposit function - allows users to "freeze", or "fuse", their star dust
  function fusion(uint amount) public{
      updateStats(msg.sender);
      playerList[msg.sender].starDust = playerList[msg.sender].starDust.sub(amount);
      totalFused += amount;
      playerList[msg.sender].fused += amount;
      playerList[msg.sender].cooldown = now + fuseCooldown;
  }

  //Fusion withdraw function - allows user to withdraw from the fusion pool
  function withdrawShare() public{
      require(playerList[msg.sender].fused > 0);
      msg.sender.transfer((this.balance * potPercentage / 100) * playerList[msg.sender].fused / totalFused);
      totalFused = totalFused.sub(playerList[msg.sender].fused);
      playerList[msg.sender].fused = 0;
  }


  //Set the percentage of the pot to be distributed (number between 0 and 100)
  function changePot(uint amount) public{
    require(msg.sender == admin);
    require(amount <= 100);
    potPercentage = amount;
  }


  // NOTE: moved these declarations to the top of the file
  // the auditor, and any other reader of source code, should not be surprised
  // by random constant declarations in the middle of the file
  /* address public onexAddress = 0x00B674220C17B199be03F20c8FE3F585c1a9769E;
  uint public onexBalance = 0; */

  function dustForONEX(uint amount) public{
    updateStats(msg.sender);
    if(playerList[msg.sender].starDust >= amount && onexBalance > amount * 5000000000000){
      playerList[msg.sender].starDust -= amount;
      ERC223(onexAddress).transfer(msg.sender, amount * 5000000000000);
    }
  }

  function tokenFallback(address sender, uint amount, bytes data) public{
    require(msg.sender == onexAddress);
    onexBalance += amount;
  }

  function adminWithdrawONEX(uint amount) public{
    require(msg.sender == admin);
    ERC223(onexAddress).transfer(admin, amount);
  }

}
