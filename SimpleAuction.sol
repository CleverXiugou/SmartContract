// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.4;

contract SimpleAuction {
    // 受益人
    address payable public beneficiary;
    // 拍卖结束时间
    uint public auctionEndTime;

    // 出价最高的人
    address public highestBidder;
    // 最高的出价
    uint public highestBid;

    // 待返还金额
    // mapping可以理解为映射字典，(keyType => valueType)
    mapping(address => uint) pendingReturns;

    // 拍卖状态，true -> 拍卖结束；false -> 拍卖正在进行
    bool ended;

    // 拍卖时会发生的两个事件，最高价增加，拍卖结束
    event HighestBidIncreased(address bidder, uint amount);
    event AuctionEnded(address winner, uint amount);

    // 描述失败的信息

    /// 竞拍已经结束
    error AuctionAlreadyEnded();
    /// 已经有更高或相等的出价
    error BidNotHighEnough(uint highestBid);
    /// 竞拍还没有结束
    error AuctionNotYetEnded();
    /// 函数auctionEn()已经被调用
    error AuctionEndAlreadyCalled();


    // 创建一个简答的拍卖,参数为拍卖时长和受益人地址
    constructor(uint biddingTime, address payable beneficiaryAddress){
        // 受益人为传入的地址
        beneficiary = beneficiaryAddress;
        // 结束时间为当前时间 + 拍卖时长
        auctionEndTime = block.timestamp + biddingTime;
    }


    // 对拍卖进行出价
    function bid() external payable {
        // 如果竞拍已经结束，回滚
        if(block.timestamp > auctionEndTime)
            revert AuctionAlreadyEnded();
        
        // 如果出价不够高，返还以太币
        if(msg.value <= highestBid)
            revert BidNotHighEnough(highestBid);
        
        // 到这一步已经出价更高了，所以更新历史最高价
        // 第一次出价时还没有最高价，此时highestBid就等于0，所以要排除第一次出价可能
        if(highestBid != 0){
            // 当出现更高出价，旧的最高价将会返还
            // 程序并没有直接返还，而是放到了pendingReturns中，让竞标者自己来取
            // 出价者并不需要每次都来取，可以累积在一起，后续一次取出
            pendingReturns[highestBidder] += highestBid;
        }

        // 更新最高出价人，最高价
        highestBidder = msg.sender;
        highestBid = msg.value;

        // 触发事件，不会记录在区块链中，只存储在日志中
        emit HighestBidIncreased(msg.sender, msg.value);
    }

    // 退款逻辑
    function withdraw() external returns(bool){
        // 读取自己的出价
        uint amount = pendingReturns[msg.sender];

        // 如果自己曾出过价
        if(amount > 0){
            // 清零自己的映射
            pendingReturns[msg.sender] = 0;

            // send()函数向msg.sender发送amount的wei
            if(!payable(msg.sender).send(amount)){
                // 如果转账失败，将钱重新记录到映射
                pendingReturns[msg.sender] = amount;
                // 表明退款未完成
                return false;
            }
        }
        // 退款成功
        return true;
    }

    // 结束拍卖
    function auctionEnd() external {
        // 如果当前时间小于截止时间，拍卖未结束
        if(block.timestamp < auctionEndTime)
            revert AuctionNotYetEnded();
        // 如果拍卖已结束
        if(ended)
            revert AuctionEndAlreadyCalled();
        
        // 拍卖结束
        ended = true;
        emit AuctionEnded(highestBidder, highestBid);

        // 将钱转给受益人
        beneficiary.transfer(highestBid);
    }
}