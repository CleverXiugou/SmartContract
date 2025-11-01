pragma solidity ^0.8.4;

contract BlindAuction {
    struct Bid {
        // 加密后的出价
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

    // key:出价者  value:加密出价
    mapping(address => Bid[]) public bids;
    address public highestBidder;
    uint public highestBid;

    // 允许取回之前的竞标
    mapping(address => uint) pendingReturns;
    
    // 拍卖结束
    event AuctionEnded(address winner, uint highestBid)

    // 描述失败信息
    /// 在拍卖揭露之前启用
    error TooEarly(uint time);
    /// 在公示之后启用
    error TooLate(uint time);
    /// 函数 auctionEnd 已经被调用
    error AuctionEndAlreadyCalled();

    // 检查使用函数的🌍
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
        uint biddingTime;
        uint revealTime;
        address payable beneficiaryAddress;
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
    function reveal(
        uint[] calldata values,
        bool[] calldata fakes,
        bytes32[] calldata secrets
    ) external onlyAfter(biddingEnd) onlyBefore(revealEnd){
        uint length = bids[msg.sender].length;
        require(values.length == length);
        require(fakes.length == length);
        require(secrets.length == length);

        // 这是一个累加变量，记录最终要退回的押金   
        uint refund;

        for(uint i = 0; i < length; i++){
            Bid storage bidToCheck = bids[msg.sender][i];
            (uint value, bool fake, bytes32 secret) = 
            (values[i], fakes[i], secrets[i]);

            // 如果出价不能被正确揭露，不退回押金deposit
            if(bidToCheck.blindedBid != keccak256(abi.encodePacked(vale, fake, secret))){
                continue;
            }

            // 如果没问题，开始执行退还押金程序
            // 现将要退回的押金累积起来
            refund += bidToCheck.deposit;

            // 如果不是假出价且押金总量大于真实竞拍的价格
            if(!fake && bidToCheck.deposit >= value){
                // 若当前出价高于最高价，从押金中减去出价
                if(placeBid(msg.send, value)) refund -= value;
            }
            // 将哈希清零
            bidToCheck.blindedBid = bytes32(0);
        }
        // 退还押金
        payable(msg.sender).transfer(refund);
    }




}