// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.4;

contract BlindAuction {
    struct Bid {
        // 出价加密后的32位哈希
        bytes32 blindedBid;
        // 参与者出价后的押金
        uint deposit;
    }
    // 拍卖受益人地址
    address payable public beneficiary;
    // 投标阶段结束时间
    uint public biddingEnd;
    // 揭示阶段结束时间
    uint public revealEnd;
    // 拍卖是否结束
    bool public ended;

    // key:出价者  value:加密出价，可以有多次出价，所以用数组
    mapping(address => Bid[]) public bids;

    // 最高出价者的地址和出价
    address public highestBidder;
    uint public highestBid;

    // 记录退回的出价
    mapping(address => uint) pendingReturns;
    
    // 拍卖结束事件
    event AuctionEnded(address winner, uint highestBid);

    // 描述失败信息
    /// 在拍卖揭露之前启用
    error TooEarly(uint time);
    /// 在公示之后启用
    error TooLate(uint time);

    /// 拍卖已经结束（提示重复调用了AuctionEnd）
    error AuctionEndAlreadyCalled();

    // 检查使用函数的时间
    modifier onlyBefore(uint time){
        // 条件不满足时回滚
        if(block.timestamp >= time) revert TooLate(time);
        // 满足时继续执行原函数主体
        _;
    }

    modifier onlyAfter(uint time){
        if(block.timestamp <= time) revert TooEarly(time);
        _;
    }

    constructor(
        // 竞标时长和揭露时长
        uint biddingTime,
        uint revealTime,
        // 受益人地址
        address payable beneficiaryAddress
    ){
        // 受益人地址
        beneficiary = beneficiaryAddress;
        // 竞标结束时间
        biddingEnd = block.timestamp + biddingTime;
        // 拍卖揭示时间
        revealEnd = biddingEnd + revealTime;
    }

    // external 表明只能被外部合约或用户调用
    // payable 允许用户在调用函数时发送以太币
    // onlyBefore 只能在拍卖截止时间前执行
    // blindBid 是出价的哈希函数，有32位
    function bid(bytes32 blindBid) external payable onlyBefore(biddingEnd){
        // 将出价者的哈希出价存入刀bids中
        bids[msg.sender].push(Bid({
            // 出价哈希
            blindedBid: blindBid,
            // 出价押金，注意：押金 >= 出价
            deposit: msg.value
        }));
    }

    // 披露盲拍出价
    // 数据存储的位置：storage：区块链上。memory：临时内存上。calldata：调用数据区（不可修改）。
    function reveal(
        // 有许多待解释的出价
        uint[] calldata values,
        bool[] calldata fakes,
        bytes32[] calldata secrets
    ) external onlyAfter(biddingEnd) onlyBefore(revealEnd){
        // 用户每次出价会同时产生真实出价value，是否真出价fake和出价随机字符串secret
        // 他们的长度都应该相同
        uint length = bids[msg.sender].length;
        require(values.length == length);
        require(fakes.length == length);
        require(secrets.length == length);

        // 这是一个累加变量，记录最终要退回的押金   
        uint refund;

        // 逐条检查每一条出价
        for(uint i = 0; i < length; i++){
            // 
            Bid storage bidToCheck = bids[msg.sender][i];
            // 一次性赋值
            (uint value, bool fake, bytes32 secret) = 
            (values[i], fakes[i], secrets[i]);

            // 如果出价不能被正确揭露，不退回押金deposit
            // 具体是出价的哈希和揭露的哈希不同
            if(bidToCheck.blindedBid != keccak256(abi.encodePacked(value, fake, secret))){
                // 不执行后续逻辑了
                continue;
            }

            // 如果没问题，开始执行退还押金程序
            // 现将要退回的押金累积起来
            refund += bidToCheck.deposit;

            // 如果不是假出价且押金大于真实竞拍的价格
            if(!fake && bidToCheck.deposit >= value){
                // 若当前出价高于最高价，从押金中减去出价
                if(placeBid(msg.sender, value)) refund -= value;
            }
            // 将哈希清零
            bidToCheck.blindedBid = bytes32(0);
        }
        // 退还押金
        payable(msg.sender).transfer(refund);
    }

    // 撤回出价过高的竞标
    function withdraw() external {
        // 记录标价
        uint amount = pendingReturns[msg.sender];
        // 如果里面有钱
        if(amount > 0){
            // 现将表置零
            pendingReturns[msg.sender] = 0;
            // 向发送者退回
            payable(msg.sender).transfer(amount);
        }
    }

    // 结束拍卖，最高出价转给受益人
    function auctionEnd() external onlyAfter(revealEnd) {
        // 防止重复结束拍卖
        if(ended) revert AuctionEndAlreadyCalled();
        // 触发事件，记录谁赢得了拍卖，出价是多少。事件会写入到交易日志
        emit AuctionEnded(highestBidder, highestBid);
        // 结束拍卖
        ended = true;
        // 把最高出价转给受益人
        beneficiary.transfer(highestBid);
    }

    // 内部竞价更新函数，只能在本合约中被调用
    function placeBid(address bidder, uint value) internal returns (bool success) {
        // 如果出价不比历史最高价高，退出
        if(value <= highestBid){
            return false;
        }
        // 如果这次出价不是第一次
        if(highestBidder != address(0)){
            // 将历史最高价返还给其出价者
            pendingReturns[highestBidder] += highestBid;
        }
        // 更新当前最高价和最高出价人
        highestBid = value;
        highestBidder = bidder;
        return true;
    }

}