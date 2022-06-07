const {expect} = require('chai');
const {ethers, getChainId, deployments} = require('hardhat');

describe("LotteryGame Unit Tests", () => {
    let LotteryGame;
    let lotteryGame;
    let vrfCoordinatorV2Mock;
    let chainId;
    let deployer;
    let user2;
    let user3;
    before(async () => {
      [deployer, user2, user3] = await ethers.getSigners();
      chainId = await getChainId();
      await deployments.fixture(["main"]);
      vrfCoordinatorV2Mock = await deployments.get("VRFCoordinatorV2Mock")
      vrfCMock = await ethers.getContractAt(
        "VRFCoordinatorV2Mock",
        vrfCoordinatorV2Mock.address
      );

      LotteryGame = await deployments.get("Lottery");
      lotteryGame = await ethers.getContractAt(
        "Lottery",
        LotteryGame.address
      );
    });

    it("Should Pick A Pick A Random Winner", async () => {
      const newLottery = await ethers.getContractAt(
        "Lottery", LotteryGame.address, deployer
      );
      await newLottery.startLottery(ethers.utils.parseEther("0.1"));
      await newLottery.connect(user2).enterLottery(1, 5, {
        value: ethers.utils.parseEther("0.5"),
      });
      await newLottery.connect(user3).enterLottery(1, 5, {
        value: ethers.utils.parseEther("0.5"),
      });

      await expect(newLottery.pickWinner(1))
      .to.emit(newLottery, "RandomnessRequested")

      const requestId = await newLottery.s_requestId()

       // simulate callback from the oracle network
       await expect(
        vrfCMock.fulfillRandomWords(requestId, newLottery.address)
      ).to.emit(newLottery, "WinnerDeclared")
    });
  });