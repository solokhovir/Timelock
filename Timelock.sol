// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

contract Timelock {
    address public owner;
    uint public constant MIN_DELAY = 10;
    uint public constant MAX_DELAY = 100;
    uint public constant EXPIRY_DELAY = 1000;

    mapping(bytes32 => bool) queuedTxs;

    event Queued(bytes32 indexed txId, address indexed _to, uint _value, string _func, bytes data, uint _timestamp);
    event Executed(bytes32 indexed txId, address indexed _to, uint _value, string _func, bytes data, uint _timestamp);

    constructor() {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "not an owner");
        _;
    }

    function queue(address _to, uint _value, string calldata _func, bytes calldata _data, uint _timestamp) external onlyOwner returns(bytes32) {
        bytes32 txId = keccak256(
            abi.encode(
                _to, _value, _func, _data, _timestamp
            )
        );
        require(!queuedTxs[txId], "already queued!");
        require(
            _timestamp >= block.timestamp + MIN_DELAY && _timestamp <= block.timestamp + MAX_DELAY, "invalid timestamp"
        );
        queuedTxs[txId] = true;
        
        emit Queued(txId, _to, _value, _func, _data, _timestamp);
        
        return txId;
    }

    function execute(address _to, uint _value, string calldata _func, bytes calldata _data, uint _timestamp) external payable onlyOwner returns(bytes memory){
        bytes32 txId = keccak256(
            abi.encode(
                _to, _value, _func, _data, _timestamp
            )
        );
        require(queuedTxs[txId], "not queued!");
        require(block.timestamp >= _timestamp, "too early");
        require(block.timestamp <= _timestamp + EXPIRY_DELAY, "too late");

        delete queuedTxs[txId];
        bytes memory data;

        if(bytes(_func).length > 0) {
            data = abi.encodePacked(
                bytes4(keccak256(bytes(_func))), _data
            );
        } else {
            data = _data;
        }

        (bool success, bytes memory resp) = _to.call{value: _value}(data);

        require(success, "tx failed");

        emit Executed(txId, _to, _value, _func, _data, _timestamp);

        return resp;
    }

    function cancel(bytes32 _txId) external onlyOwner {
        require(queuedTxs[_txId], "not queued!");
        delete queuedTxs[_txId];
    }
}

contract Runner {
    address public lock;
    string public message;
    mapping(address => uint) public payments;

    constructor(address _lock) {
        lock = _lock;
    }

    function run(string memory newMsg) external payable {
        require(msg.sender == lock, "invalid address");

        payments[msg.sender] += msg.value;
        message = newMsg;
    }

    function newTimestamp() external view returns(uint) {
        return block.timestamp + 20;
    }

    function prepareData(string calldata _msg) external pure returns(bytes memory) {
        return abi.encode(_msg);
    }
}