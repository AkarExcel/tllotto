// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import "@chainlink/contracts/src/v0.8/interfaces/KeeperCompatibleInterface.sol";
import "hardhat/console.sol";

// Errors
error Raffle__sendMoreToEnterRaffle();
error Raffle__calculatingRaffleWinner();
error Raffle__upKeepNotNeeded();
error Raffle__TransferFailed();

contract Raffle is VRFConsumerBaseV2{
    enum RaffleState {
        Open,
        Calculating
    }

    // Storage variable
    RaffleState public s_RaffleState;
    uint256 public immutable i_entranceFee;
    uint256 public immutable i_interval;
    uint256 public s_lastTimeStamp; 
    address public s_recentWinner;
    address payable[] public s_players;
    

    /* State variables */
    // Chainlink VRF Variables
    VRFCoordinatorV2Interface private immutable i_vrfCoordinator;
    uint64 private immutable i_subscriptionId;
    bytes32 private immutable i_gasLane;
    uint32 private immutable i_callbackGasLimit;
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;

    /* Events */
    event RaffleEnter(address indexed player);
    event RequestRaffleWinner(uint256 indexed requestId);
    event WinnerPicked(address indexed winner);

    /* Functions */
    constructor(
        address vrfCoordinatorV2,
        uint64 subscriptionId,
        bytes32 gasLane, // keyHash
        uint256 interval,
        uint256 entranceFee,
        uint32 callbackGasLimit
    ) VRFConsumerBaseV2(vrfCoordinatorV2) {
        i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinatorV2);
        i_gasLane = gasLane;
        i_interval = interval;
        i_subscriptionId = subscriptionId;
        i_entranceFee = entranceFee;
        s_RaffleState = RaffleState.Open;
        s_lastTimeStamp = block.timestamp;
        i_callbackGasLimit = callbackGasLimit;
    }

    function enterRaffle() external payable {
        if(msg.value < i_entranceFee){
            revert Raffle__sendMoreToEnterRaffle();
        }
        // Is Raffle open, or are we Calculating winner
        if(s_RaffleState != RaffleState.Open){
            revert Raffle__calculatingRaffleWinner();
        }
        //You can enter
        s_players.push(payable(msg.sender));

        emit RaffleEnter(msg.sender);
    }

    // We want to set a random winner automatically
    // we want a real random number

    // This function will return true if the lottery interval is no
    // yet reached, we have ETH, we have LINK and the Lottery is Open
    function checkUpKeep(bytes memory) public view returns(bool upKeepNeeded, bytes memory /* performData */){
        bool isOpen = RaffleState.Open == s_RaffleState;
        bool timePassed = (block.timestamp - s_lastTimeStamp) > i_interval;
        bool hasBalance = address(this).balance > 0;
        bool hasPlayers = s_players.length > 0;
        upKeepNeeded = (timePassed && isOpen && hasPlayers && hasBalance );
        return (upKeepNeeded, "0x0");
    }

    function performUpKeep(bytes calldata /*perform Upkeep*/) external {
        (bool upKeepNeeded, ) = checkUpKeep("");
        if(!upKeepNeeded){
            revert Raffle__upKeepNotNeeded();
        }
        s_RaffleState = RaffleState.Calculating;
        uint256 requestId = i_vrfCoordinator.requestRandomWords(
            i_gasLane,
            i_subscriptionId,
            REQUEST_CONFIRMATIONS,
            i_callbackGasLimit,
            NUM_WORDS
        );
        emit RequestRaffleWinner(requestId);
    }

    function fulfillRandomWords(
        uint256, /* requestId */
        uint256[] memory randomWords) internal override {
        uint256 indexOfWinner = randomWords[0] % s_players.length;
        address payable recentWinner = s_players[indexOfWinner];
        s_recentWinner = recentWinner;
        s_players = new address payable[](0);
        s_RaffleState = RaffleState.Open;
        s_lastTimeStamp = block.timestamp;
        uint256 winPool = (address(this).balance * 70) / 100;
        (bool success, ) = recentWinner.call{value: winPool}("");
        // require(success, "Transfer failed");
        if (!success) {
            revert Raffle__TransferFailed();
        }
        emit WinnerPicked(recentWinner);
    }

    
}