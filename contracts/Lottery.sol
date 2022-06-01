//SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;


import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import "@chainlink/contracts/src/v0.8/interfaces/LinkTokenInterface.sol";
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "./LotteryData.sol";

contract Lottery is VRFConsumerBaseV2, AccessControl{
    VRFCoordinatorV2Interface COORDINATOR;
    LinkTokenInterface LINKTOKEN;
    LotteryData LOTTERY_DATA;

    // Set Lottery Roles 
    bytes32 private constant LOTTERY_ADMIN = keccak256("LOTTERY_ADMIN");
    bytes32 private constant RAFFLE_OWNER = keccak256("RAFFLE_OWNER");

    using Counters for Counters.Counter;

    using SafeMath for uint256;

    Counters.Counter private lotteryId;

    mapping(uint256 => uint256) private lotteryRandomnessRequest;
    bytes32 private keyHash;
    uint64 immutable s_subscriptionId;
    uint16 immutable requestConfirmations = 3;
    uint32 immutable callbackGasLimit = 100000;
    uint256 public s_requestId;

    event RandomnessRequested(uint256,uint256);
    
    //To emit data which will contain the requestId-from chainlink vrf, lotteryId, winnder address
    event WinnerDeclared(uint256 ,uint256,address);

    //To emit data which will contain the lotteryId, address of new-player & new Price Pool
    event NewLotteryPlayer(uint256, address, uint256);

    //To emit data which will contain the id of newly created lottery
    event LotteryCreated(uint256, address);


    //custom Errors
    error invalidValue();
    error invalidFee();
    error lotteryNotActive();
    error lotteryFull();
    error alreadyEntered();
    error lotteryEnded();
    error playersNotFound();
    error onlyLotteryManagerAllowed();
    error ticketCostNotCorrect();

     constructor(
        bytes32 _keyHash,
        uint64 subscriptionId, 
        address _vrfCoordinator, 
        address _link,
        address _lotteryData
        ) VRFConsumerBaseV2(_vrfCoordinator){
        lotteryId.increment();
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(LOTTERY_ADMIN, msg.sender);
        _grantRole(RAFFLE_OWNER, msg.sender);
        COORDINATOR = VRFCoordinatorV2Interface(_vrfCoordinator);
        LINKTOKEN = LinkTokenInterface(_link);
        s_subscriptionId = subscriptionId;
        keyHash = _keyHash;
        LOTTERY_DATA = LotteryData(_lotteryData);
    }

    /*@title this functions set the roles for lottery
    */
    function setLotteryOwner(address _newLotteryOwner) public onlyRole(DEFAULT_ADMIN_ROLE) {
        _grantRole(RAFFLE_OWNER, _newLotteryOwner);
    }

    function setRaffleOwner(address _newRaffleOwner) public onlyRole(LOTTERY_ADMIN) onlyRole(DEFAULT_ADMIN_ROLE) {
        _grantRole(RAFFLE_OWNER, _newRaffleOwner);
    }

    function revokeRaffleOwner(address _revokeRaffleOwner) public onlyRole(LOTTERY_ADMIN) onlyRole(DEFAULT_ADMIN_ROLE) {
        _revokeRole(RAFFLE_OWNER, _revokeRaffleOwner);
    }

    function revokeLotteryOwner(address _revokeLotteryOwner) public onlyRole(DEFAULT_ADMIN_ROLE) {
        _revokeRole(RAFFLE_OWNER, _revokeLotteryOwner);
    }

    function getAllLotteryIds() public view returns(uint256[] memory){
        return LOTTERY_DATA.getAllLotteryIds();
    }

    function startLottery(uint256 _lotteryTicketPrice) public payable onlyRole(RAFFLE_OWNER) {
        LOTTERY_DATA.addLotteryData(lotteryId.current(), msg.sender);
        lotteryId.increment();
        LOTTERY_DATA.lotteryTicketPrice = _lotteryTicketPrice;
        emit LotteryCreated(lotteryId.current(), msg.sender);
    }

    function isPresent(address[] memory _p, address _a) public pure returns (bool){
        for (uint i=0; i < _p.length; i++) {
            if(_p[i] == _a) {
                return true;
            }
        }
        return false;
    }

    function enterLottery(uint256 _lotteryId, uint256 _count) public payable {
        (address owner,
        uint256 Id,
        uint256 ticketPrice, 
        uint256 prizePool, 
        address[] memory players, 
        address winner, 
        bool isFinished) = LOTTERY_DATA.getLottery(_lotteryId);
        if(isFinished) revert lotteryNotActive();
        if(msg.value < LOTTERY_DATA.lotteryTicketPrice * _count) revert invalidFee();
        uint256 i = 0;
        for(i = 0; i < _count; i++){
            uint256  updatedPricePool = prizePool + LOTTERY_DATA.lotteryTicketPrice;
            LOTTERY_DATA.addPlayerToLottery(_lotteryId, updatedPricePool, msg.sender);
            emit NewLotteryPlayer(_lotteryId, msg.sender, updatedPricePool);
        }
    }

    function pickWinner(uint256 _lotteryId) public onlyRole(RAFFLE_OWNER) {

        if(LOTTERY_DATA.isLotteryFinished(_lotteryId)) revert lotteryEnded();

        address[] memory p = LOTTERY_DATA.getLotteryPlayers(_lotteryId);
        if(p.length == 1) {
            if(p[0] == address(0)) revert playersNotFound();
            //require(p[0] != address(0), "no_players_found");
            LOTTERY_DATA.setWinnerForLottery(_lotteryId, 0);
            payable(p[0]).transfer(address(this).balance);
            emit WinnerDeclared(0,_lotteryId,p[0]);
        } else {
            //LINK is from VRFConsumerBase
            s_requestId = COORDINATOR.requestRandomWords(
                keyHash,
                s_subscriptionId,
                requestConfirmations,
                callbackGasLimit,
                1 // number of random numbers
            );
            lotteryRandomnessRequest[s_requestId] = _lotteryId;
            emit RandomnessRequested(s_requestId,_lotteryId);
        }
    }

    function fulfillRandomWords(uint256 requestId, uint256[] memory randomness) internal override {
        uint256 _lotteryId = lotteryRandomnessRequest[requestId];
        address[] memory allPlayers = LOTTERY_DATA.getLotteryPlayers(_lotteryId);
        uint256 winnerIndex = randomness[0].mod(allPlayers.length);
        LOTTERY_DATA.setWinnerForLottery(_lotteryId, winnerIndex);
        delete lotteryRandomnessRequest[requestId];
        payable(allPlayers[winnerIndex]).transfer(address(this).balance);
        emit WinnerDeclared(requestId,_lotteryId,allPlayers[winnerIndex]);
    }

    function getLotteryDetails(uint256 _lotteryId) public view returns(
        address,
        uint256,
        uint256,
        uint256 ,
        address[] memory,
        address ,
        bool
        ){
            return LOTTERY_DATA.getLottery(_lotteryId);
    }

}
