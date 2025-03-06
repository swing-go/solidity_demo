//SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

// 让参与过FundMe的用户，获得相应数量的通证

// 1. 让FundMe的参与者，基于 mapping 来领取相应数量的通证
// 2. 让FundMe的参与者，transfer 通证   (ERC20的函数有transfer的功能，直接使用)
// 3. 在使用完成以后，需要burn 通证

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {FundMe} from "./fundMe.sol";

contract FundTokenERC20 is ERC20 {
    FundMe fundMe;  //声明fundMe为FundMe类型
    constructor(address fundMeAddr) ERC20("NiceShot", "NS") { // 这里的 ERC20 是调用父合约的构造函数 ，此函数还需传参
        fundMe = FundMe(fundMeAddr);    //众筹合约的初始化
    }

    function mint(uint256 amountToMint) public {
        // 找到众筹合约里该地址有多少金额，与输入金额对比
        require(fundMe.fundersToAmount(msg.sender) >= amountToMint, "You cannot mint this many tokens");
        require(fundMe.getFundSuccess(), "The fundme is not completed yet");//getFundSuccess在fundMe只是一个变量，但是这个变成了一个函数来使用，这是因为自动创建了getter函数
        ERC20._mint(msg.sender, amountToMint);    //这个是ERC20的函数，直接使用；领取相应数量的通证
        fundMe.setFunderToAmount(msg.sender, fundMe.fundersToAmount(msg.sender) - amountToMint);    //扣除金额
    }

    function claim(uint256 amountToClaim) public {
        // complete cliam
        require(balanceOf(msg.sender) >= amountToClaim, "You dont have enough ERC20 tokens");
        require(fundMe.getFundSuccess(), "The fundme is not completed yet");
        /*to add */
        // burn amountToClaim Tokens       
        ERC20._burn(msg.sender, amountToClaim);   //在使用完成以后，需要burn 通证。这个是ERC20的函数，直接使用；
    }
}