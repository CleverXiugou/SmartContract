// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.4;

contract Purchase {
    // 物品价格
    uint public value;
    // 购买者和销售者的地址
    address payable public seller;
    address payable public buyer;

    // 购买的几种状态：创建，锁定，释放，失效
    // 创建：交易创建了
    // 锁定：交易不可以退款了
    // 释放：卖家可以收到货款了
    // 失效：交易已经全部完成了
    enum State {Created, Locked, Release, Inactive}

    // 合约当前状态
    State public state;

    // 自定义判断条件
    modifier condition(bool condition_){
        require(condition_);
        _;
    }

    /// 只有买方可以调用这个函数
    error OnlyBuyer();
    /// 只有卖方可以调用这个函数
    error OnlySeller();
    /// 当前状态下不能调用该函数
    error InvalidState();
    /// 输入的值必须是偶数
    error ValueNotEven();

    // 只有购买者可以使用
    modifier onlyBuyer() {
        if(msg.sender != buyer){
            revert OnlyBuyer();
        }
        _;
    }

    // 只有售卖者可以使用
    modifier onlySeller(){
        if(msg.sender != seller){
            revert OnlySeller();
        }
        _;
    }

    // 判断当前合约状态是否等于目标状态
    modifier inState(State state_){
        if(state != state_){
            revert InvalidState();
        }
        _;
    }

    // 交易终止
    event Aborted();
    // 购买确认
    event PurchaseConfirmed();
    // 货物被接收
    event ItemReceived();
    // 卖家收到货款
    event SellerRefunded();


    constructor() payable{
        // 卖家等于最早调用合约的人
        seller = payable(msg.sender);
        // 物品价格为支付金额的一半，另一半是押金
        value = msg.value / 2;
        // 要保证一开始支付的金额是偶数
        if((2 * value) != msg.value){
            revert ValueNotEven();
        }
    }
    
    // 交易尚未完成时，允许卖家单方面终止交易
    // 只有在交易刚创建时可以被终止
    function abort() 
        external 
        onlySeller 
        inState(State.Created)
    {
        // 交易终止
        emit Aborted();
        // 交易状态改为失效
        state = State.Inactive;
        // 合约的所有资金退回给卖家
        seller.transfer(address(this).balance);
    }

    // 确认购买，买家付了货款和押金才能执行
    // 买家付的金额是货款的两倍
    function confirmPurchase() 
        external 
        inState(State.Created)
        condition(msg.value == (2 * value))
        payable 
    {
        // 确认购买
        emit PurchaseConfirmed();
        // 买家等于调用这个函数的人
        buyer = payable(msg.sender);
        // 合约状态变成锁定
        state = State.Locked;
    }


    // 确认收货，只能被买家调用
    // 此时合约状态需要是锁定状态
    function confirmReceived()
        external
        onlyBuyer
        inState(State.Locked)
    {
        // 已经接收物品
        emit ItemReceived();
        // 改变合约状态为释放：解除资金的锁定状态
        state = State.Release;
        // 退回买家押金
        buyer.transfer(value);
    }

    // 卖家接收货款，只能被卖家调用，合约状态必须是释放状态
    function refundSeller()
        external
        onlySeller
        inState(State.Release)
    {
        // 触发卖家退款
        emit SellerRefunded();
        // 合约状态为失效
        state = State.Inactive;
        // 卖家收到3倍货品价格的资金：自己的押金+买家的货款
        seller.transfer(3 * value);
    }
}