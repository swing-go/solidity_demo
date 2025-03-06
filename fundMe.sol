// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

// 众筹
contract FundMe {
    mapping(address => uint256) public fundersToAmount;
    
    // 获取当前的1个ETH的美元价格
    AggregatorV3Interface internal dataFeed;

    uint256 MIN_VALUE = 100 * 10 ** 18; //转款最小值

    uint256 constant TARGET = 1000 * 10 ** 18;  //目标值

    address public owner; //合约拥有者

    uint256 deploymentTimestamp;    // 锁定期的开始时间
    uint256 lockTime;               // 锁定时长

    address erc20Addr;

    bool public getFundSuccess = false;

    //构建函数 - 只有合约部署的时候才会执行一次
    constructor(uint256 _lockTime) {    //编译后，_lockTime能在编辑器的左侧手动输入
        // sepolia testnet
        dataFeed = AggregatorV3Interface(0x694AA1769357215DE4FAC081bf1f309aDC325306);   //price feed 的合约地址
        owner = msg.sender; //第一个发送的人的地址

        deploymentTimestamp = block.timestamp;  //合约部署时的区块时间
        lockTime = _lockTime;
    }

    function fund() external payable { // 1 收款
        require(convertEthToUsd(msg.value)>=MIN_VALUE, "plz send more ETH");
        require(block.timestamp < deploymentTimestamp + lockTime, "window is closed");
        fundersToAmount[msg.sender] = msg.value; //2 记录投资人
    }

    //Chainlink开发手册的函数：
    function getChainlinkDataFeedLatestAnswer() public view returns (int) {
        // prettier-ignore
        (
            /* uint80 roundID */,
            int answer,
            /*uint startedAt*/,
            /*uint timeStamp*/,
            /*uint80 answeredInRound*/
        ) = dataFeed.latestRoundData();
        return answer;
    }

    //如何设置美元为单位的限制 ==> 预言机（接通链下）==> Data Feed (喂价)
    function convertEthToUsd(uint256 ethAmount) internal view returns(uint256){
        uint256 ethPrice = uint256(getChainlinkDataFeedLatestAnswer()); //返回的精度是8位，即ETH/USD的精度=10**8
        return ethAmount * ethPrice / (10 ** 8);
    }
    // 3. 在锁定期内，达到目标值，生产商可以提款
    function getFund() external windowClosed onlyOwner{
        require(convertEthToUsd(address(this).balance) >= TARGET, "Target is not reached");
        // transfer: transfer ETH and revert if tx failed
        // payable(msg.sender).transfer(address(this).balance); // 将合约余额发送给所有者。也用在退款的场景
        
        // send: transfer ETH and return false if failed
        // bool success = payable(msg.sender).send(address(this).balance);                  //transfer 2
        // require(success, "tx failed");
        
        // call: transfer ETH with data return value of function and bool 
        // bool success;
        // (success, ) = payable(msg.sender).call{value: address(this).balance}("");        //transfer 3
        // require(success, "transfer tx failed");
        // fundersToAmount[msg.sender] = 0;
        // getFundSuccess = true; // flag

        bool success;
        (success, ) = payable(msg.sender).call{value: address(this).balance}("");
        require(success, "transfer tx failed");
        fundersToAmount[msg.sender] = 0;
        getFundSuccess = true; // flag
    }

    //转移合约拥有者
    function transferOwnership(address newOwner) public onlyOwner{
        owner = newOwner;
    }

    // 4. 在锁定期内，没有达到目标值，投资人在锁定期以后退款
    function refund() external windowClosed {
        require(convertEthToUsd(address(this).balance) < TARGET, "Target is reached");
        require(fundersToAmount[msg.sender] != 0, "there is no fund for you");
        bool success;
        (success, ) = payable(msg.sender).call{value: fundersToAmount[msg.sender]}(""); //退款
        require(success, "transfer tx failed");
        fundersToAmount[msg.sender] = 0;    //切记归零 切记归零 切记归零
    }

    modifier windowClosed() {
        //交易时的区块时间
        require(block.timestamp >= deploymentTimestamp + lockTime, "window is not closed");
        _;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "this function can only be called by owner");
        _;
    }

    // 更新
     function setFunderToAmount(address funder, uint256 amountToUpdate) external {  //只能erc20Addr这个外部的合约地址能调用
        require(msg.sender == erc20Addr, "you do not have permission to call this funtion");
        fundersToAmount[funder] = amountToUpdate;
    }

    function setErc20Addr(address _erc20Addr) public onlyOwner {    //erc20Addr这个外部的合约地址只能此合约拥有者能改动
        erc20Addr = _erc20Addr;
    }
}