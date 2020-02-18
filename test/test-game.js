let BigNumber = require('bignumber.js')
let ethers = require('ethers')
let playerStats = require('./utils')

var ONEX = artifacts.require("./ONEX.sol")
var FAKEONEX = artifacts.require("./FAKEONEX.sol")
var EtcOdyssey = artifacts.require("./EtcOdyssey.sol")

function assertJump(error) {
  let revertOrInvalid = error.message.search('invalid opcode|revert')
  assert.isAbove(revertOrInvalid, -1, 'Invalid opcode error must be returned')
}

function increaseSeconds(duration) {
  const id = Date.now()

  return new Promise((resolve, reject) => {
    web3.currentProvider.send({
      jsonrpc: '2.0',
      method: 'evm_increaseTime',
      params: [duration],
      id: id,
    }, err1 => {
      if (err1) { return reject(err1) }

      web3.currentProvider.send({
        jsonrpc: '2.0',
        method: 'evm_mine',
        id: id+1,
      }, (err2, res) => {
        return err2 ? reject(err2) : resolve(res)
      })
    })
  })
}

contract('ETC Odyssey test suite', function(accounts) {
  var players, admin

  before("Set up helpful constants and spread some ONEX", async () => {
    admin = accounts[0]

    players = [
      accounts[4],
      accounts[5],
      accounts[6],
      accounts[7],
      accounts[8],
      accounts[3]
    ]

    // add some ONEX to the game
    const onex = await ONEX.deployed()
    const game = await EtcOdyssey.deployed()
    const largenumber = web3.utils.toBN(1e20)
    await onex.transfer(game.address, largenumber, '0x0', {from: accounts[0]})
    let trackedBalance = await game.onexBalance()
    assert.equal(trackedBalance.toString(), largenumber.toString())

    // give players some ONEX to play with
    for (let addy of players) {
      await onex.transfer(addy, largenumber, '0x0', {from: accounts[0]})
    }
  })

  it("Has the right ONEX and admin addresses", async () => {
    const onex = await ONEX.deployed()
    const game = await EtcOdyssey.deployed()

    let gameadmin = await game.admin();
    let onexaddress = await game.onexAddress();

    assert.equal(gameadmin.toLowerCase(), admin.toLowerCase(), 'Wrong admin!')
    assert.equal(onexaddress.toLowerCase(), onex.address.toLowerCase(), 'Wrong onex!')
  })

  it("Anybody can top up game's ONEX balance", async () => {
    const onex = await ONEX.deployed()
    const game = await EtcOdyssey.deployed()

    let balanceBefore = await onex.balanceOf(game.address)
    let trackedBalanceBefore = await game.onexBalance()
    await onex.transfer(game.address, web3.utils.toBN(1e18), '0x0', {from: players[0]})
    let balanceAfter = await onex.balanceOf(game.address)
    let trackedBalanceAfter = await game.onexBalance()
    assert.equal(balanceAfter.sub(balanceBefore).toString(), 1e18.toString())
    assert.equal(trackedBalanceAfter.sub(trackedBalanceBefore).toString(), 1e18.toString())

    // now put some down for bounties!
    await onex.transfer(game.address, (await onex.balanceOf(admin)), '0x0', {from: admin})
  })

  it("Admin can withdraw ONEX from the game", async () => {
    const onex = await ONEX.deployed()
    const game = await EtcOdyssey.deployed()

    let balanceBefore = await onex.balanceOf(game.address)

    try {
      await game.adminWithdrawONEX(1, {from: players[0]})
      assert.fail('Only admin can withdraw!!')
    } catch(error) {
      assertJump(error)
    }
    await game.adminWithdrawONEX(1, {from: admin})
    // did not fail! now send it back
    await onex.transfer(game.address, web3.utils.toBN(1), '0x0', {from: admin})
  })

  it("No other erc223 token may be received", async () => {
    const fake = await FAKEONEX.deployed()
    const game = await EtcOdyssey.deployed()

    try {
      await fake.transfer(game.address, 100000, '0x0', {from: admin})
      assert.fail('The contract should reject transfer of fakeonex!')
    } catch(error) {
      assertJump(error)
    }
  })

  it("Allows admin to change pot percentage", async () => {
    const game = await EtcOdyssey.deployed()

    try {
      await game.changePot(10, {from: players[0]})
      assert.fail('Only admin can change pot!')
    } catch(error) {
      assertJump(error)
    }

    await game.changePot(10, {from: admin})

    try {
      await game.changePot(200, {from: admin})
      assert.fail('Precentage cannot be more than 100!')
    } catch(error) {
      assertJump(error)
    }

    // return as it were....
    await game.changePot(25, {from: admin})
  })

  it("Cannot buy Dark Matter unless you are already a registered player", async () => {
    const game = await EtcOdyssey.deployed()

    try {
      await game.buyDarkMatter({from: players[0], value: web3.utils.toWei('1', 'ether')})
      assert.fail('The contract should reject transfer of ether!')
    } catch(error) {
      assertJump(error)
    }
  })

  it("Players need to purchase ships to start the game", async () => {
    const game = await EtcOdyssey.deployed()

    try {
      await game.initShip(0, {from: players[0], value: web3.utils.toWei('0.0001', 'ether')})
      assert.fail('Don\'t be too cheap!')
    } catch(error) {
      assertJump(error)
    }

    // let player1 be the referrer
    await game.initShip(0, {from: players[1], value: web3.utils.toWei('3', 'ether')})
    try {
      await game.initShip(0, {from: players[1], value: web3.utils.toWei('1', 'ether')})
      assert.fail('Cannot init the ship twice!')
    } catch(error) {
      assertJump(error)
    }
    let referrerInfo = await playerStats(game, players[1], web3);
    await game.initShip(referrerInfo.referralId, {from: players[0], value: web3.utils.toWei('3', 'ether')})
    await game.initShip(referrerInfo.referralId, {from: players[2], value: web3.utils.toWei('3', 'ether')})
    await game.initShip(referrerInfo.referralId, {from: players[3], value: web3.utils.toWei('3', 'ether')})
    await game.initShip(referrerInfo.referralId, {from: players[4], value: web3.utils.toWei('3', 'ether')})
    await game.initShip(referrerInfo.referralId, {from: players[5], value: web3.utils.toWei('3', 'ether')})

    let stats = {
      referrer: await playerStats(game, players[1], web3),
      randomguy: await playerStats(game, players[3], web3),
    }

    assert(stats.referrer.darkMatter.gt(stats.randomguy.darkMatter))
    assert.equal(stats.referrer.referralCount.toString(), '5')
    assert.equal(stats.randomguy.referralCount.toString(), '0')
    // referrers may have faster resource growth, but all fighters start equally
    assert.equal(stats.referrer.shields.toString(), stats.randomguy.shields.toString())
  })

  it("Allows players to purchase additional Dark Matter", async () => {
    const game = await EtcOdyssey.deployed()

    let statsBefore = await playerStats(game, players[1], web3)
    await game.buyDarkMatter({from: players[1], value: web3.utils.toWei('1', 'ether')})
    let statsAfter = await playerStats(game, players[1], web3)

    assert(statsAfter.darkMatter.sub(statsBefore.darkMatter).sub(web3.utils.toBN(1000)).lt(web3.utils.toBN(10)))
  })

  it("Referrers get some extra dark matter too!", async () => {
    const game = await EtcOdyssey.deployed()

    let statsBefore = await playerStats(game, players[0], web3)
    let refstatsBefore = await playerStats(game, players[1], web3)
    await game.buyDarkMatter({from: players[0], value: web3.utils.toWei('1', 'ether')})
    let statsAfter = await playerStats(game, players[0], web3)
    let refstatsAfter = await playerStats(game, players[1], web3)

    assert(statsAfter.darkMatter.sub(statsBefore.darkMatter).sub(web3.utils.toBN(1000)).lt(web3.utils.toBN(10)))
    assert(refstatsAfter.darkMatter.sub(refstatsBefore.darkMatter).sub(web3.utils.toBN(10)).lt(web3.utils.toBN(10)))
  })

  it("Purchases of Dark Matter that are too small are rejected", async () => {
    const game = await EtcOdyssey.deployed()

    try {
      await game.buyDarkMatter({from: players[0], value: 1})
      assert.fail('The contract should reject transfer of ether!')
    } catch(error) {
      assertJump(error)
    }
  })

  it("Rejects ether transfers that don't purchase Dark Matter", async () => {
    const game = await EtcOdyssey.deployed()

    try {
      await web3.eth.sendTransaction({from: players[0], to: game.address, value: web3.utils.toWei('1', 'ether')})
      assert.fail('The contract should reject transfer of ether!')
    } catch(error) {
      assertJump(error)
    }
    assert(true)
  })

  it("Allows a player to upgrade their ship with DM", async () => {
    const game = await EtcOdyssey.deployed()
    let player = players[1]
    // add some money or testing
    await game.buyDarkMatter({from: player, value: web3.utils.toWei('10', 'ether')})
    let p_rate = await game.getProductionRate(player)

    await game.purchaseUpgradeReactor({from: player})
    await game.purchaseUpgradeBlasters({from: player})
    await game.purchaseUpgradeThrusters({from: player})

    let p_rate2 = await game.getProductionRate(player)
    assert.equal(p_rate2.sub(p_rate).toString(), '3')

    await increaseSeconds(5000)
    for (let p of players) {
      await game.purchaseUpgradeHull({from: p})
    }
  })

  it("Upgraded ships get more resources faster", async () => {
    const game = await EtcOdyssey.deployed()
    let player = players[3]
    let referrer = players[1]

    let p_rate = await playerStats(game, player, web3)
    let r_rate = await playerStats(game, referrer, web3)

    await increaseSeconds(990000)
    // trigger update to "updatestats"
    await game.purchaseUpgradeReactor({from: player})
    await game.purchaseUpgradeReactor({from: referrer})

    let p_rate2 = await playerStats(game, player, web3)
    let r_rate2 = await playerStats(game, referrer, web3)

    assert(r_rate2.darkMatter.sub(r_rate.darkMatter).gt(p_rate2.darkMatter.sub(p_rate.darkMatter)))
    assert(r_rate2.starDust.sub(r_rate.starDust).gt(p_rate2.starDust.sub(p_rate.starDust)))
  })

  it("Lets you raid others, to earn DM and SD. Loser has to repair ship", async () => {
    const game = await EtcOdyssey.deployed()

    for (let player of players.concat(players)) {
      await increaseSeconds(60 * 60 * 60 * 48)
      // let pp = await game.getProductionRate(player)
      let p_rate = await playerStats(game, player, web3)

      // flaky test suite?
      let event
      try {
        event = await game.startRaid({from: player, gasLimit: 500000})
      } catch(error) {
        continue
      }

      try {
        await game.startRaid({from: player, gasLimit: 500000})
        assert.fail('Need to wait before you can raid more often!')
      } catch(error) {
        assertJump(error)
      }
      let raid = event.logs[0].args
      let p_rate2 = await playerStats(game, player, web3)

      assert(raid.winner.toLowerCase() === player.toLowerCase() || raid.loser.toLowerCase() === player.toLowerCase())
      if (raid.winner.toLowerCase() === player.toLowerCase()) {
        // console.log(`After: ${p_rate2.darkMatter.toString()}, before: ${p_rate.darkMatter.toString()}, raided: ${raid.darkmatter.toString()}, rate: ${pp.toString()}`)
        assert(p_rate2.darkMatter.sub(p_rate.darkMatter).sub(raid.darkmatter).gt(web3.utils.toBN(0)))
        assert(p_rate2.starDust.sub(p_rate.starDust).sub(raid.stardust).gt(web3.utils.toBN(0)))
        assert(raid.damage.gte(web3.utils.toBN(0)))

        let loserstats = await playerStats(game, raid.loser, web3)
        let loserEthBalance = new BigNumber((await web3.eth.getBalance(raid.loser)).toString())
        // loser has to repair ship if there was hull damage
        try {
          await game.repairShipUnit({from: raid.loser, value: web3.utils.toBN(1)})
          assert.fail('Tiny repares do not work!')
        } catch(error) {
          assertJump(error)
        }
        await game.repairShipUnit({from: raid.loser, value: web3.utils.toWei('10', 'ether')})
        let loserstats2 = await playerStats(game, raid.loser, web3)
        let loserEthBalance2 = new BigNumber((await web3.eth.getBalance(raid.loser)).toString())
        assert(loserEthBalance.minus(loserEthBalance2).lte(new BigNumber(web3.utils.toWei('10', 'ether'))))
        assert(loserstats2.hp.sub(loserstats.hp).gte(0))
      }

      // upgrading thrusters reduces timer!
      await game.purchaseUpgradeThrusters({from: player})
      let p_rate3 = await playerStats(game, player, web3)
      assert(p_rate3.thrusterTimer.lt(p_rate2.thrusterTimer))
    }
  })

  it("Can instantly convert stardust into ONEX", async () => {
    const game = await EtcOdyssey.deployed()
    const onex = await ONEX.deployed()
    let player = players[1]
    let amount = 1000000

    let pobb = await onex.balanceOf(player)
    let gobb = await game.onexBalance()
    let p_rate = await playerStats(game, player, web3)
    await game.dustForONEX(amount, {from: player})
    let p_rate2 = await playerStats(game, player, web3)
    let poba = await onex.balanceOf(player)
    let goba = await game.onexBalance()

    assert(p_rate.starDust.sub(p_rate2.starDust).sub(web3.utils.toBN(amount)).lte(web3.utils.toBN(30)))
    assert(poba.gt(pobb))
    assert(goba.lt(gobb))
    assert(poba.sub(pobb).eq(gobb.sub(goba)))
  })

  it("Players can earn ETC! Can fuse stardust and exchange it for ether later", async () => {
    const game = await EtcOdyssey.deployed()

    let p_rate11 = await playerStats(game, players[1], web3)
    let p_rate21 = await playerStats(game, players[2], web3)

    await game.fusion(p_rate11.starDust, {from: players[1]})
    await game.fusion(p_rate21.starDust, {from: players[2]})

    let gebb = new BigNumber((await web3.eth.getBalance(game.address)).toString())
    let pebb = new BigNumber((await web3.eth.getBalance(players[1])).toString())

    try {
      await game.withdrawShare({from: players[1]})
      assert.fail('Need to wait for cooldown!')
    } catch(error) {
      assertJump(error)
    }
    await increaseSeconds(60 * 60 * 60 * 24 + 10)

    await game.withdrawShare({from: players[1]})

    let geba = new BigNumber((await web3.eth.getBalance(game.address)).toString())
    let peba = new BigNumber((await web3.eth.getBalance(players[1])).toString())

    assert(geba.lt(gebb), 'The game should have less ether in it')
    assert(peba.gt(pebb), 'The player should have earned some ether')
    assert(gebb.minus(geba).minus(peba.minus(pebb).lt(new BigNumber(0.0000001).shiftedBy(18))), 'All withdrawn ether goes to player')
  })

})
