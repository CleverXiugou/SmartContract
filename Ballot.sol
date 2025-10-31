// SPDX-License-Identifier: GPL-3.0
pragma solidity >= 0.7.0 < 0.9.0;

contract ballot {
    // 投票者
    struct Voter {
        uint weight; // 投票者的票权重
        bool voted; // 表明是否投过票
        address delegate; // 被委托人
        uint vote; // 被选举人的索引 
    }

    // 被选举人
    struct Proposal {
        bytes32 name; // 简称
        uint voteCount; // 得票数
    }
    
    // 投票主席，总管理员
    address public chairperson;

    // 声明一个状态变量，为每一个地址都存储一个Voter类型
    mapping(address => Voter) public voters;

    // 创造一个选举人的动态数组
    Proposal[] public proposals;

    // memory是临时存储，只在函数执行时生效
    constructor (bytes32[] memory proposalNames){
        // 合约发起者也就是主席
        chairperson = msg.sender;
        // 主席也有一票权重
        voters[chairperson].weight = 1;

        // 初始化所有被选举人
        for(uint i = 0; i < proposalNames.length; i++){
            proposals.push(Proposal({
                name: proposalNames[i],
                voteCount: 0
            }));
        }
    }

    // 授予投票权
    function giveRightToVote(address voter) external {
        // 仅当主席可以操作
        require(
            msg.sender == chairperson,
            "Only chairperson can give right to vote!"
        );

        // 被授予投票权的人此前没有投过票（防止投了票再重复授予投票权）
        require(
            !voters[voter].voted,
            "The voter already voted!"
        );

        // 被授予投票权的人之前没有投票权，防止重复授予投票权
        require(voters[voter].weight == 0);

        // 授予投票权
        voters[voter].weight = 1;
    }

    // 把你的投票权转授给人“to”
    function delegate(address to) external {
        // storage表明永久写入
        Voter storage sender = voters[msg.sender];

        // 想要执行这个函数的人自身一定要有投票权
        require(sender.weight != 0, "You have no right to vote!");

        // 已经投过票就不能再转授投票权给别人了
        require(!sender.voted, "You already voted.");

        // 自己不能转授给自己投票权
        require(to != msg.sender, "Self-delegration is disallowed.");

        // 如果被转让投票权的人已经把自己的投票权也转让出去，进入循环
        // 例如A想把自己投票权转给B，但是发现B已经把自己投票权转让给C
        while(voters[to].delegate != address(0)){
            // A不再转让给B，直接转让给C
            to = voters[to].delegate;
            // 如果发现转让的C等于自身A，则发现构成一个环
            require(
                to != msg.sender,
                "Found loop in delegation."
                );
        }
        // 将被转让的人写入区块链
        Voter storage delegate_ = voters[to];

        // 投票者不能把投票权转让给没有投票权的人
        require(delegate_.weight >= 1, "Delegate has no right to vote.");

        // 转让后原投票人标记为已投票状态，转让用户更新为to
        sender.voted = true;
        sender.delegate = to;

        // 若被转让人已经投完票，则直接增加票数
        if(delegate_.voted) {
            // 这里不是给被转让人增加票数
            // 直接给被转让人投过票的人增加票数
            // 例A想把票权转给B，但是B已经把票投给C，此时A的票会自动投给C
            proposals[delegate_.vote].voteCount += sender.weight;
        }else{
            delegate_.weight += sender.weight;
        }
    }


    // 投票函数
    function vote(uint proposal) external {
        Voter storage sender = voters[msg.sender];
        // 保证拥有投票权利
        require(sender.weight != 0, "Has no right to vote.");
        // 保证之前没有投过票 
        require(!sender.voted, "Already voted");
        // 更新投票状态为已投
        sender.voted = true;
        
        // 将被选举的人的地址写入到自身
        sender.vote = proposal;

        // 被选举人所得票数增加
        proposals[proposal].voteCount += sender.weight;
    }

    // 获取获胜者索引
    function winningProposal() public view returns (uint winningProposal_){
        // 初始化获胜者票数为0
        uint winningVoteCount = 0;
        // 遍历被选举人
        for(uint p = 0; p < proposals.length; p++){
            // 如果该选举人票数大于当前最大票数，则更新最大票数和相对的索引
            if(proposals[p].voteCount > winningVoteCount) {
                winningVoteCount = proposals[p].voteCount;
                winningProposal_ = p;
            }
        }
    }
    // 调用winningProposal()函数以获取获胜者的索引
    // 根据索引返回获胜者名称
    function winnerName() external view returns (bytes32 winnerName_) {
        winnerName_ = proposals[winningProposal()].name;
    }
}