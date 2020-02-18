const asBN = (b, web3) => web3.utils.toBN('0x' + b)

const playerStats = async (game, playerAddress, web3) => {
  let rawStats = await game.shipStats(playerAddress)
  let rawFinancials = await game.playerFinancials(playerAddress)
  let statsNumbers = rawStats.substr(2).match(/.{1,64}/g)
  let financialsNumbers = rawFinancials.substr(2).match(/.{1,64}/g)
  return {
    thrusters: asBN(statsNumbers[0], web3),
    blasters: asBN(statsNumbers[1], web3),
    hull: asBN(statsNumbers[2], web3),
    lastUpdate: asBN(statsNumbers[3], web3),
    thrusterTimer: asBN(statsNumbers[4], web3),
    shields: asBN(statsNumbers[5], web3),
    hp: asBN(statsNumbers[6], web3),
    cooldown: asBN(statsNumbers[7], web3),
    reactor: asBN(financialsNumbers[0], web3),
    referralId: asBN(financialsNumbers[2], web3),
    referralCount: asBN(financialsNumbers[3], web3),
    fused: asBN(financialsNumbers[4], web3),
    darkMatter: asBN(financialsNumbers[5], web3),
    starDust: asBN(financialsNumbers[6], web3),
  }
}

module.exports = playerStats
