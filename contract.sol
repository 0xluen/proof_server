/**
 *Submitted for verification at Etherscan.io on 2023-08-21
*/

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

interface IERC20 {
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract Bridge {
    IERC20 public token;
    bytes32 public merkleRoot;
    address public owner;
    address public nodeWallet;
    uint256 public currentId = 1;
    uint256 public bridgedId = 1;
    uint256 public control = 1;
    uint256 public bridgeFee = 0.003 ether ; 

    bool private locked = false; // Reentry koruması için eklediğimiz kilitleme durumu

    modifier noReentry() {
        require(!locked, "Reentry attack detected");
        locked = true;
        _;
        locked = false;
    }

    struct Deposit {
        address user;
        uint256 amount;
        uint256 time;
        bool processed;
    }

    struct Withdrawal {
        address user;
        uint256 amount;
    }

    struct UserDeposit {
        uint256 lastDepositTime;
        uint256 dailyTotal;
    }

    mapping(address => UserDeposit) private userDeposits;

    uint256 public constant MAX_DAILY_DEPOSIT = 1000 * 10**18; // 1000 token, 18 ondalık basamak varsayılarak
    uint256 public constant DEPOSIT_INTERVAL = 24 hours;

    mapping(uint256 => Deposit) public deposits;
    mapping(uint256 => Withdrawal) public withdrawals;

    event Deposited(address indexed user, uint256 amount, uint256 id);
    event Withdrawn(address indexed user, uint256 amount, uint256 id);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    constructor(address _token, address _nodeWallet,bytes32 _merkleRoot) {
        token = IERC20(_token);
        owner = msg.sender;
        nodeWallet = _nodeWallet;
        merkleRoot = _merkleRoot;
    }
    
    function setMerkleRoot(bytes32 newMerkleRoot) external onlyOwner {
        merkleRoot = newMerkleRoot;
    }

    function setBridgeFee(uint256 newFee) external onlyOwner {
        bridgeFee = newFee;
    }

    function getBridgeFee() external view returns (uint256) {
        return bridgeFee;
    }

    function setControl(uint256 _control) public onlyOwner {
        control = _control;
    }

    function getDeposit(uint256 _id) public view returns (Deposit memory) {
        return deposits[_id];
    }

    function getWithdrawal(uint256 _id) public view returns (Withdrawal memory) {
        return withdrawals[_id];
    }

    function deposit(uint256 amount,bytes32[] calldata merkleProof) external payable noReentry {
        bytes32 leaf = keccak256(abi.encodePacked(msg.sender));
        require(msg.value >= bridgeFee , "Fee is too low");
        if (control != 0) {
        require(amount <= MAX_DAILY_DEPOSIT, "Exceeds daily limit");
        UserDeposit storage userDeposit = userDeposits[msg.sender];
        uint256 timeSinceLastDeposit = block.timestamp - userDeposit.lastDepositTime;
        if (timeSinceLastDeposit >= DEPOSIT_INTERVAL) {
            userDeposit.dailyTotal = 0;
        }
        require(userDeposit.dailyTotal + amount <= MAX_DAILY_DEPOSIT, "Daily limit exceeded");
        userDeposit.dailyTotal += amount;
        userDeposit.lastDepositTime = block.timestamp;
        require(verifyMerkleProof(merkleProof, merkleRoot, leaf), "Invalid proof");
        }
        require(token.transferFrom(msg.sender, address(this), amount), "Transfer failed");
        deposits[currentId] = Deposit(msg.sender, amount, block.timestamp, false);
        emit Deposited(msg.sender, amount, currentId);
        currentId++;
    }

    function processDeposit(uint256 id) external noReentry {
        require(msg.sender == nodeWallet, "Can only be triggered by node wallet");
        require(!deposits[id].processed, "Already processed");
        deposits[id].processed = true;
    }

    function withdraw(address _user, uint256 _amount) external noReentry {
        require(msg.sender == nodeWallet, "Can only be triggered by node wallet");
        token.transfer(_user, _amount);
        withdrawals[bridgedId] = Withdrawal(_user, _amount);
        bridgedId++;
    }

    function emergencyWithdraw() external onlyOwner noReentry {
        uint256 balance = token.balanceOf(address(this));
        token.transfer(owner, balance);
    }

    function emergencyWith(IERC20 _token) external onlyOwner noReentry {
        uint256 balance = _token.balanceOf(address(this));
        _token.transfer(owner, balance);
    }

     function verifyMerkleProof(bytes32[] calldata proof, bytes32 root, bytes32 leaf) internal pure returns (bool) {
        return MerkleProof.verify(proof, root, leaf);
    }

}